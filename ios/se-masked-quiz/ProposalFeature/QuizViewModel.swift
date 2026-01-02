import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
  // MARK: - Mask Quiz (R2) Properties
  @Published var currentQuiz: Quiz?
  @Published var isShowingQuiz = false
  @Published var selectedAnswer: [Int: String] = [:]
  @Published var isCorrect: [Int: Bool] = [:]
  @Published var allQuiz: [Quiz] = []
  @Published var answers: [Int: String] = [:]
  @Published var currentScore: ProposalScore?
  @Published var isShowingResetAlert = false
  @Published var isConfigured: Bool = false

  // MARK: - LLM Quiz Properties (Issue #12)
  @Published var allLLMQuiz: [LLMQuiz] = []
  @Published var currentLLMQuiz: LLMQuiz?
  @Published var llmQuizScore: LLMQuizScore?
  @Published var selectedLLMAnswer: [String: String] = [:]  // quizId -> answer
  @Published var isLLMCorrect: [String: Bool] = [:]  // quizId -> isCorrect

  // MARK: - SRS Properties (Issue #12)
  @Published var dailyReviewQueue: DailyReviewQueue?
  @Published var reviewStats: ReviewStats?
  @Published var isSRSEnabled: Bool = true

  // MARK: - LLM Generation State
  @Published var isGeneratingQuizzes: Bool = false
  @Published var quizGenerationProgress: Double = 0.0
  @Published var quizGenerationError: String?
  @Published var hasLLMQuizzes: Bool = false

  private let quizRepository: any QuizRepository
  private let srsScheduler: any SRSScheduler
  private let proposalId: String

  init(
    proposalId: String,
    quizRepository: any QuizRepository,
    srsScheduler: any SRSScheduler
  ) {
    self.quizRepository = quizRepository
    self.srsScheduler = srsScheduler
    self.proposalId = proposalId
  }

  // MARK: - LLM Quiz Generation (Issue #12)

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
      // モデルを読み込み（まだ読み込まれていない場合）
      let isLoaded = await llmService.isModelLoaded
      if !isLoaded {
        quizGenerationProgress = 0.1
        try await llmService.loadModel(id: modelId)
      }

      quizGenerationProgress = 0.3

      // LLMクイズを生成（LLMQuiz型で返される）
      let generatedQuizzes = try await llmService.generateQuizzes(
        from: content,
        proposalId: proposalId,
        difficulty: difficulty,
        count: count
      )

      quizGenerationProgress = 0.8

      // 生成されたLLMクイズを保存
      await quizRepository.saveLLMQuizzes(generatedQuizzes, for: proposalId)

      quizGenerationProgress = 1.0
      hasLLMQuizzes = true
      allLLMQuiz = generatedQuizzes

      // クイズリストを再読み込み
      await configure()

    } catch {
      quizGenerationError = error.localizedDescription
    }

    isGeneratingQuizzes = false
  }

  /// LLM生成クイズを削除
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
      // R2マスククイズを取得
      allQuiz = try await quizRepository.fetchQuiz(for: proposalId)

      // LLM生成クイズを別途取得
      allLLMQuiz = await quizRepository.getLLMQuizzes(for: proposalId)
      hasLLMQuizzes = await quizRepository.hasLLMQuizzes(for: proposalId)

      isShowingQuiz = true
      selectedAnswer = [:]
      isCorrect = [:]
      answers = Dictionary(uniqueKeysWithValues: allQuiz.map { ($0.index, $0.answer) })

      // マスククイズのスコアを読み込み
      if let existingScore = await quizRepository.getScore(for: proposalId) {
        currentScore = existingScore
        for result in existingScore.questionResults {
          selectedAnswer[result.index] = result.userAnswer
          isCorrect[result.index] = result.isCorrect
        }
      }

      // LLMクイズのスコアを読み込み
      if let existingLLMScore = await quizRepository.getLLMQuizScore(for: proposalId) {
        llmQuizScore = existingLLMScore
        for result in existingLLMScore.results {
          selectedLLMAnswer[result.quizId] = result.userAnswer
          isLLMCorrect[result.quizId] = result.isCorrect
        }
      }

      // Issue #12: SRS機能が有効な場合、復習キューと統計を読み込む
      if isSRSEnabled {
        do {
          async let queueTask = srsScheduler.generateDailyQueue(for: proposalId)
          async let statsTask = srsScheduler.getReviewStats(for: proposalId)

          let (queue, stats) = try await (queueTask, statsTask)
          dailyReviewQueue = queue
          reviewStats = stats

          // 復習キューに基づいてクイズを並び替え（復習優先）
          if !queue.reviewItems.isEmpty {
            let reviewQuizIds = Set(queue.reviewItems)
            allQuiz.sort { quiz1, quiz2 in
              let isReview1 = reviewQuizIds.contains(quiz1.id)
              let isReview2 = reviewQuizIds.contains(quiz2.id)
              if isReview1 != isReview2 {
                return isReview1  // 復習クイズを先に
              }
              return quiz1.index < quiz2.index  // 同じ優先度ならindexでソート
            }
          }
        } catch {
          print("Failed to load SRS data:", error)
          // SRSデータの読み込みに失敗しても、通常のクイズは継続
        }
      }

      isConfigured = true
    } catch {
      print("Failed to fetch quiz:", error)
    }
  }

  func showQuizSelections(index: Int) {
    guard isConfigured else { return }
    currentQuiz = allQuiz[index]
    isShowingQuiz = true
  }

  func selectAnswer(_ answer: String) {
    if let currentQuiz = currentQuiz, isCorrect[currentQuiz.index] == nil {
      selectedAnswer[currentQuiz.index] = answer
      let index = currentQuiz.index
      let correct = answer == currentQuiz.answer
      isCorrect[index] = correct
      updateScore()

      // Issue #12: SRS機能が有効な場合、復習スケジュールを更新
      if isSRSEnabled {
        Task {
          do {
            // 回答品質を計算（0-5のスケール）
            // 正解: 5（完璧な記憶）、不正解: 0（完全忘却）
            let quality = correct ? 5 : 0
            try await srsScheduler.updateScheduleAfterReview(
              quizId: currentQuiz.id,
              proposalId: currentQuiz.proposalId,
              quality: quality
            )

            // 統計情報を更新
            reviewStats = try await srsScheduler.getReviewStats(for: proposalId)
          } catch {
            print("Failed to update SRS schedule:", error)
          }
        }
      }
    }
  }

  func dismissQuiz() {
    isShowingQuiz = false
    currentQuiz = nil
  }

  private func updateScore() {
    guard let proposalId = currentQuiz?.proposalId else { return }

    let allQuizByIndex = Dictionary(uniqueKeysWithValues: allQuiz.map({ ($0.index, $0) }))

    let questionResults = zip(selectedAnswer, isCorrect)
      .compactMap({ args -> QuestionResult? in
        let _selectedAnswer = args.0
        let _isCorrect = args.1

        guard let quiz = allQuizByIndex[_selectedAnswer.key] else {
          return nil
        }
        return QuestionResult(
          index: quiz.index,
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
    Task {
      await quizRepository.saveScore(newScore)
    }
  }

  func resetQuiz(for proposalId: String) async {
    await quizRepository.resetScore(for: proposalId)
    selectedAnswer = [:]
    isCorrect = [:]
    currentScore = nil

    // Issue #12: SRS機能が有効な場合、復習スケジュールも削除
    if isSRSEnabled {
      do {
        try await srsScheduler.deleteSchedules(for: proposalId)
        dailyReviewQueue = nil
        reviewStats = nil
      } catch {
        print("Failed to delete SRS schedules:", error)
      }
    }
  }

  // MARK: - LLM Quiz Interactions

  /// LLMクイズを表示
  func showLLMQuizSelections(index: Int) {
    guard isConfigured, index < allLLMQuiz.count else { return }
    currentLLMQuiz = allLLMQuiz[index]
  }

  /// LLMクイズの回答を選択
  func selectLLMAnswer(_ answer: String) {
    guard let quiz = currentLLMQuiz, isLLMCorrect[quiz.id] == nil else { return }

    selectedLLMAnswer[quiz.id] = answer
    let correct = answer == quiz.correctAnswer
    isLLMCorrect[quiz.id] = correct
    updateLLMQuizScore()

    // SRS機能が有効な場合、復習スケジュールを更新
    if isSRSEnabled {
      Task {
        do {
          let quality = correct ? 5 : 0
          try await srsScheduler.updateScheduleAfterReview(
            quizId: quiz.id,
            proposalId: quiz.proposalId,
            quality: quality
          )
          reviewStats = try await srsScheduler.getReviewStats(for: proposalId)
        } catch {
          print("Failed to update SRS schedule for LLM quiz:", error)
        }
      }
    }
  }

  /// LLMクイズを閉じる
  func dismissLLMQuiz() {
    currentLLMQuiz = nil
  }

  /// LLMクイズスコアを更新
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
    Task {
      await quizRepository.saveLLMQuizScore(newScore)
    }
  }

  /// LLMクイズをリセット
  func resetLLMQuiz(for proposalId: String) async {
    await quizRepository.resetLLMQuizScore(for: proposalId)
    selectedLLMAnswer = [:]
    isLLMCorrect = [:]
    llmQuizScore = nil
  }
}
