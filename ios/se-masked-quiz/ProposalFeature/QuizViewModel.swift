import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
  // MARK: - Mask Quiz Properties
  @Published var currentQuiz: Quiz?
  @Published var isShowingQuiz = false
  @Published var selectedAnswer: [Int: String] = [:]
  @Published var isCorrect: [Int: Bool] = [:]
  @Published var allQuiz: [Quiz] = []
  @Published var answers: [Int: String] = [:]
  @Published var currentScore: ProposalScore?
  @Published var isShowingResetAlert = false
  @Published var isConfigured: Bool = false
  @Published var pendingScrollMaskIndex: Int?

  // MARK: - LLM Quiz Properties
  @Published var allLLMQuiz: [LLMQuiz] = []
  @Published var currentLLMQuiz: LLMQuiz?
  @Published var llmQuizScore: LLMQuizScore?
  @Published var selectedLLMAnswer: [String: String] = [:]  // quizId -> answer
  @Published var isLLMCorrect: [String: Bool] = [:]  // quizId -> isCorrect

  // MARK: - LLM Generation State
  @Published var isGeneratingQuizzes: Bool = false
  @Published var quizGenerationProgress: Double = 0.0
  @Published var quizGenerationError: String?
  @Published var hasLLMQuizzes: Bool = false

  // MARK: - Speech Properties
  @Published private(set) var speakingTarget: SpeechTarget?
  @Published private(set) var focusedParagraphSegments: [ProposalSegment] = []

  private let quizRepository: any QuizRepository
  private let streakRepository: any StreakRepository
  private let analytics: any AnalyticsService
  private let speechService: any SpeechService
  private let proposalId: String
  private var speechTask: Task<Void, Never>?

  private static let speechLanguageCode = "en-US"

  init(
    proposalId: String,
    quizRepository: any QuizRepository,
    streakRepository: any StreakRepository = StreakRepositoryImpl(),
    analytics: any AnalyticsService = ConsoleAnalyticsService(),
    speechService: (any SpeechService)? = nil
  ) {
    self.quizRepository = quizRepository
    self.streakRepository = streakRepository
    self.analytics = analytics
    self.speechService = speechService ?? AVSpeechService()
    self.proposalId = proposalId
  }

  // MARK: - LLM Quiz Generation

  /// LLMを使ってクイズを生成
  /// - Parameters:
  ///   - content: Swift Evolution提案のコンテンツ
  ///   - difficulty: クイズ難易度
  ///   - count: 生成するクイズ数
  ///   - llmService: LLMサービス
  ///   - modelId: Hugging FaceモデルID
  func generateQuizzesWithLLM(
    content: String,
    difficulty: QuizDifficulty,
    count: Int,
    llmService: any LLMService,
    modelId: String
  ) async {
    isGeneratingQuizzes = true
    quizGenerationProgress = 0.0
    quizGenerationError = nil

    do {
      let isLoaded = await llmService.isModelLoaded
      if !isLoaded {
        quizGenerationProgress = 0.1
        try await llmService.loadModel(id: modelId)
      }

      quizGenerationProgress = 0.3

      let generatedQuizzes = try await llmService.generateQuizzes(
        from: content,
        proposalId: proposalId,
        difficulty: difficulty,
        count: count
      )

      quizGenerationProgress = 0.8

      await quizRepository.saveLLMQuizzes(generatedQuizzes, for: proposalId)

      quizGenerationProgress = 1.0
      hasLLMQuizzes = true
      allLLMQuiz = generatedQuizzes

      await configure()

    } catch {
      quizGenerationError = error.localizedDescription
    }

    isGeneratingQuizzes = false
  }

  func deleteLLMQuizzes() async {
    await quizRepository.deleteLLMQuizzes(for: proposalId)
    hasLLMQuizzes = false
    allLLMQuiz = []
    llmQuizScore = nil
    selectedLLMAnswer = [:]
    isLLMCorrect = [:]
    await configure()
  }

  func configure() async {
    do {
      allQuiz = try await quizRepository.fetchQuiz(for: proposalId)

      allLLMQuiz = await quizRepository.getLLMQuizzes(for: proposalId)
      hasLLMQuizzes = await quizRepository.hasLLMQuizzes(for: proposalId)

      isShowingQuiz = true
      selectedAnswer = [:]
      isCorrect = [:]
      answers = Dictionary(uniqueKeysWithValues: allQuiz.map { ($0.maskIndex, $0.answer) })

      if let existingScore = await quizRepository.getScore(for: proposalId) {
        currentScore = existingScore
        for result in existingScore.questionResults {
          selectedAnswer[result.index] = result.userAnswer
          isCorrect[result.index] = result.isCorrect
        }
      }

      if let existingLLMScore = await quizRepository.getLLMQuizScore(for: proposalId) {
        llmQuizScore = existingLLMScore
        for result in existingLLMScore.results {
          selectedLLMAnswer[result.quizId] = result.userAnswer
          isLLMCorrect[result.quizId] = result.isCorrect
        }
      }

      isConfigured = true
      analytics.track(.quizStarted(proposalId: proposalId))
    } catch {
      print("Failed to fetch quiz:", error)
    }
  }

  func showQuizSelections(maskIndex: Int) {
    guard isConfigured, let quiz = allQuiz.first(where: { $0.maskIndex == maskIndex }) else { return }
    if !continuesSpeaking(movingTo: maskIndex) {
      stopSpeaking()
    }
    pendingScrollMaskIndex = nil
    currentQuiz = quiz
    isShowingQuiz = true
  }

  var nextUnansweredMaskIndex: Int? {
    QuizNavigator.nextUnansweredMaskIndex(
      after: currentQuiz?.maskIndex, in: allQuiz, answered: isCorrect)
  }

  func goToNextUnansweredQuiz() {
    guard let next = nextUnansweredMaskIndex,
      let quiz = allQuiz.first(where: { $0.maskIndex == next })
    else { return }
    if !continuesSpeaking(movingTo: next) {
      stopSpeaking()
    }
    currentQuiz = quiz
    pendingScrollMaskIndex = next
    isShowingQuiz = true
  }

  func selectAnswer(_ answer: String) {
    if let currentQuiz = currentQuiz, isCorrect[currentQuiz.maskIndex] == nil {
      selectedAnswer[currentQuiz.maskIndex] = answer
      let index = currentQuiz.maskIndex
      let correct = answer == currentQuiz.answer
      isCorrect[index] = correct
      updateScore()
      recordActivityAndTrack(isCorrect: correct)
    }
  }

  func dismissQuiz() {
    stopSpeaking()
    isShowingQuiz = false
    currentQuiz = nil
  }

  // MARK: - Speech

  /// 未解答の答えを明かさないため、解答済みの問題だけが発音を提供する
  var canSpeakTerm: Bool {
    guard let currentQuiz else { return false }
    return isCorrect[currentQuiz.maskIndex] != nil
  }

  var canSpeakParagraph: Bool {
    !focusedParagraphSegments.isEmpty
  }

  func updateFocusedParagraph(_ segments: [ProposalSegment]) {
    focusedParagraphSegments = segments
  }

  func toggleParagraphSpeech() {
    if speakingTarget == .paragraph {
      stopSpeaking()
      return
    }
    startSpeaking(
      .paragraph,
      text: SpeechTextBuilder.utterance(
        from: focusedParagraphSegments,
        answers: answers,
        answeredIndices: Set(isCorrect.keys)
      )
    )
  }

  func toggleTermSpeech() {
    guard canSpeakTerm, let currentQuiz else { return }
    if speakingTarget == .term {
      stopSpeaking()
      return
    }
    startSpeaking(.term, text: currentQuiz.answer)
  }

  /// 同じ段落内の移動では読み上げを切らない。空欄が変わっても読んでいる文章は同じため
  private func continuesSpeaking(movingTo maskIndex: Int) -> Bool {
    speakingTarget == .paragraph && focusedParagraphSegments.contains(.mask(index: maskIndex))
  }

  func stopSpeaking() {
    speechTask?.cancel()
    speechTask = nil
    speechService.stop()
    speakingTarget = nil
  }

  private func startSpeaking(_ target: SpeechTarget, text: String) {
    guard !text.isEmpty else { return }
    speechTask?.cancel()
    speechService.stop()
    speakingTarget = target
    speechTask = Task { [weak self] in
      guard let self else { return }
      await speechService.speak(text, languageCode: Self.speechLanguageCode)
      guard !Task.isCancelled else { return }
      speakingTarget = nil
    }
  }

  private func updateScore() {
    guard let proposalId = currentQuiz?.proposalId else { return }

    let allQuizByIndex = Dictionary(uniqueKeysWithValues: allQuiz.map({ ($0.maskIndex, $0) }))

    let questionResults = zip(selectedAnswer, isCorrect)
      .compactMap({ args -> QuestionResult? in
        let _selectedAnswer = args.0
        let _isCorrect = args.1

        guard let quiz = allQuizByIndex[_selectedAnswer.key] else {
          return nil
        }
        return QuestionResult(
          index: quiz.maskIndex,
          isCorrect: _isCorrect.value,
          answer: quiz.answer,
          userAnswer: _selectedAnswer.value
        )
      })

    let newScore = ProposalScore(
      proposalId: proposalId,
      questionResults: questionResults
    )

    currentScore = newScore
    Task { [quizRepository] in
      await quizRepository.saveScore(newScore)
    }
  }

  func resetQuiz(for proposalId: String) async {
    await quizRepository.resetScore(for: proposalId)
    selectedAnswer = [:]
    isCorrect = [:]
    currentScore = nil
  }

  // MARK: - LLM Quiz Interactions

  func showLLMQuizSelections(index: Int) {
    guard isConfigured, index < allLLMQuiz.count else { return }
    currentLLMQuiz = allLLMQuiz[index]
  }

  func selectLLMAnswer(_ answer: String) {
    guard let quiz = currentLLMQuiz, isLLMCorrect[quiz.id] == nil else { return }

    selectedLLMAnswer[quiz.id] = answer
    let correct = answer == quiz.correctAnswer
    isLLMCorrect[quiz.id] = correct
    updateLLMQuizScore()
    recordActivityAndTrack(isCorrect: correct)
  }

  // MARK: - Streak & Analytics

  /// 回答のたびにストリークを記録し、計測イベントを送る（習慣ループの「行動→投資」）
  private func recordActivityAndTrack(isCorrect: Bool) {
    analytics.track(.quizAnswered(isCorrect: isCorrect))
    Task { [streakRepository, analytics] in
      let result = await streakRepository.recordActivity(on: Date())
      if result.isFirstActivityToday {
        analytics.track(.streakIncremented(days: result.record.currentStreak))
      }
    }
  }

  func dismissLLMQuiz() {
    currentLLMQuiz = nil
  }

  private func updateLLMQuizScore() {
    let results = allLLMQuiz.compactMap { quiz -> LLMQuizResult? in
      guard let userAnswer = selectedLLMAnswer[quiz.id],
        let correct = isLLMCorrect[quiz.id]
      else { return nil }

      return LLMQuizResult(
        quizId: quiz.id,
        isCorrect: correct,
        correctAnswer: quiz.correctAnswer,
        userAnswer: userAnswer
      )
    }

    let newScore = LLMQuizScore(
      proposalId: proposalId,
      results: results
    )

    llmQuizScore = newScore
    Task { [quizRepository] in
      await quizRepository.saveLLMQuizScore(newScore)
    }
  }

  func resetLLMQuiz(for proposalId: String) async {
    await quizRepository.resetLLMQuizScore(for: proposalId)
    selectedLLMAnswer = [:]
    isLLMCorrect = [:]
    llmQuizScore = nil
  }

}
