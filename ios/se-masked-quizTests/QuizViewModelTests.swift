import XCTest

@testable import se_masked_quiz

@MainActor
final class QuizViewModelTests: XCTestCase {
  var sut: QuizViewModel!
  var mockRepository: QuizRepositoryMock!
  var mockScores: [String: ProposalScore] = [:]
  var mockQuizzes: [String: [Quiz]] = [:]

  var mockLLMQuizzes: [String: [LLMQuiz]] = [:]
  var mockLLMScores: [String: LLMQuizScore] = [:]

  override func setUp() async throws {
    mockRepository = QuizRepositoryMock()
    mockScores = [:]
    mockQuizzes = [:]
    mockLLMQuizzes = [:]
    mockLLMScores = [:]

    // Setup default handlers using actor-safe methods
    await mockRepository.setGetAllScoresHandler { @MainActor [weak self] in
      return self?.mockScores ?? [:]
    }

    await mockRepository.setGetScoreHandler { @MainActor [weak self] proposalId in
      return self?.mockScores[proposalId]
    }

    await mockRepository.setSaveScoreHandler { @MainActor [weak self] score in
      self?.mockScores[score.proposalId] = score
    }

    await mockRepository.setResetScoreHandler { @MainActor [weak self] proposalId in
      self?.mockScores.removeValue(forKey: proposalId)
    }

    await mockRepository.setFetchQuizHandler { @MainActor [weak self] proposalId in
      guard let quizzes = self?.mockQuizzes[proposalId] else {
        throw QuizError.proposalNotFound
      }
      return quizzes
    }

    // LLM quiz handlers
    await mockRepository.setGetLLMQuizzesHandler { @MainActor [weak self] proposalId in
      return self?.mockLLMQuizzes[proposalId] ?? []
    }

    await mockRepository.setHasLLMQuizzesHandler { @MainActor [weak self] proposalId in
      return !(self?.mockLLMQuizzes[proposalId]?.isEmpty ?? true)
    }

    await mockRepository.setSaveLLMQuizzesHandler { @MainActor [weak self] quizzes, proposalId in
      self?.mockLLMQuizzes[proposalId] = quizzes
    }

    await mockRepository.setDeleteLLMQuizzesHandler { @MainActor [weak self] proposalId in
      self?.mockLLMQuizzes.removeValue(forKey: proposalId)
      self?.mockLLMScores.removeValue(forKey: proposalId)
    }

    await mockRepository.setSaveLLMQuizScoreHandler { @MainActor [weak self] score in
      self?.mockLLMScores[score.proposalId] = score
    }

    await mockRepository.setGetLLMQuizScoreHandler { @MainActor [weak self] proposalId in
      return self?.mockLLMScores[proposalId]
    }

    await mockRepository.setResetLLMQuizScoreHandler { @MainActor [weak self] proposalId in
      self?.mockLLMScores.removeValue(forKey: proposalId)
    }

    sut = QuizViewModel(proposalId: "test", quizRepository: mockRepository)
  }

  override func tearDown() async throws {
    mockScores = [:]
    mockQuizzes = [:]
    mockLLMQuizzes = [:]
    mockLLMScores = [:]
    sut = nil
    mockRepository = nil
  }

  private func setQuizzes(_ quizzes: [Quiz], for proposalId: String) {
    mockQuizzes[proposalId] = quizzes
  }

  private func setShouldThrowError(_ shouldThrow: Bool) async {
    if shouldThrow {
      await mockRepository.setFetchQuizHandler { _ in
        throw QuizError.proposalNotFound
      }
    }
  }

  func testConfigure_WhenSuccessful_LoadsQuizAndScore() async throws {
    // Given
    let proposalId = "0001"
    let quizzes = [
      Quiz(
        id: "1", proposalId: proposalId, index: 0, answer: "Swift",
        choices: ["Java", "Kotlin", "Rust"]),
      Quiz(
        id: "2", proposalId: proposalId, index: 1, answer: "async",
        choices: ["sync", "await", "concurrent"]),
    ]
    setQuizzes(quizzes, for: proposalId)

    let existingResults = [
      QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
      QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
    ]
    let existingScore = ProposalScore(proposalId: proposalId, questionResults: existingResults)
    mockScores[proposalId] = existingScore

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )

    // When
    await sut.configure()

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(sut.allQuiz.count, 2)
    XCTAssertEqual(sut.currentScore?.proposalId, proposalId)
    XCTAssertEqual(sut.currentScore?.correctCount, 1)
    XCTAssertEqual(sut.currentScore?.totalCount, 2)

    // Verify restored answers
    XCTAssertEqual(sut.selectedAnswer[0], "Swift")
    XCTAssertEqual(sut.selectedAnswer[1], "sync")
    XCTAssertEqual(sut.isCorrect[0], true)
    XCTAssertEqual(sut.isCorrect[1], false)
  }

  func testConfigure_WhenError_HandlesFailure() async throws {
    // Given
    let proposalId = "0001"
    await setShouldThrowError(true)

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )

    // When
    await sut.configure()

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(sut.allQuiz.isEmpty)
    XCTAssertNil(sut.currentScore)
  }

  func testSelectAnswer_WhenCorrect_UpdatesScoreAndSaves() async throws {
    // Given
    let proposalId = "0001"
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    setQuizzes([quiz], for: proposalId)

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    await sut.configure()

    // Wait for quiz to load
    try await Task.sleep(nanoseconds: 100_000_000)

    // When
    sut.showQuizSelections(index: 0)
    sut.selectAnswer("Swift")

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(sut.currentScore?.correctCount, 1)
    XCTAssertEqual(sut.currentScore?.totalCount, 1)
    XCTAssertEqual(sut.currentScore?.percentage, 100)

    // Verify score was saved with correct question result
    let savedScore = mockScores[proposalId]
    XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, true)
    XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Swift")
  }

  func testSelectAnswer_WhenIncorrect_UpdatesScoreAndSaves() async throws {
    // Given
    let proposalId = "0001"
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    setQuizzes([quiz], for: proposalId)

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    await sut.configure()

    // Wait for quiz to load
    try await Task.sleep(nanoseconds: 100_000_000)

    // When
    sut.showQuizSelections(index: 0)
    sut.selectAnswer("Java")

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertEqual(sut.currentScore?.correctCount, 0)
    XCTAssertEqual(sut.currentScore?.totalCount, 1)
    XCTAssertEqual(sut.currentScore?.percentage, 0)

    // Verify score was saved with incorrect question result
    let savedScore = mockScores[proposalId]
    XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, false)
    XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Java")
  }

  func testDismissQuiz_ClearsCurrentQuiz() async throws {
    // Given
    let proposalId = "0001"
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    setQuizzes([quiz], for: proposalId)

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    await sut.configure()

    // Wait for quiz to load
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showQuizSelections(index: 0)
    XCTAssertNotNil(sut.currentQuiz)

    // When
    sut.dismissQuiz()

    // Then
    XCTAssertNil(sut.currentQuiz)
    XCTAssertFalse(sut.isShowingQuiz)
  }

  func testResetQuiz_ClearsAllStateAndScore() async throws {
    // Given
    let proposalId = "0001"
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    setQuizzes([quiz], for: proposalId)

    sut = .init(
      proposalId: proposalId,
      quizRepository: mockRepository
    )

    // Set initial state
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showQuizSelections(index: 0)
    sut.selectAnswer("Swift")

    // Verify initial state
    XCTAssertNotNil(sut.currentScore)
    XCTAssertFalse(sut.selectedAnswer.isEmpty)
    XCTAssertFalse(sut.isCorrect.isEmpty)

    // When
    await Task.yield()
    await sut.resetQuiz(for: proposalId)

    // Then
    XCTAssertNil(sut.currentScore)
    XCTAssertTrue(sut.selectedAnswer.isEmpty)
    XCTAssertTrue(sut.isCorrect.isEmpty)

    // Verify score was removed from repository
    let savedScore = mockScores[proposalId]
    XCTAssertNil(savedScore)
  }

  func testResetQuiz_WhenMultipleScoresExist_OnlyResetsTargetScore() async throws {
    // Given
    let proposalId1 = "0001"
    let proposalId2 = "0002"

    // Set up first quiz
    let quiz1 = Quiz(
      id: "1", proposalId: proposalId1, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    setQuizzes([quiz1], for: proposalId1)

    // Set up second quiz
    let quiz2 = Quiz(
      id: "2", proposalId: proposalId2, index: 0, answer: "async",
      choices: ["sync", "await", "concurrent"])
    setQuizzes([quiz2], for: proposalId2)

    // Save scores for both quizzes
    let score1 = ProposalScore(
      proposalId: proposalId1,
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift")
      ]
    )
    let score2 = ProposalScore(
      proposalId: proposalId2,
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "async", userAnswer: "async")
      ]
    )

    mockScores[proposalId1] = score1
    mockScores[proposalId2] = score2

    // When
    await sut.resetQuiz(for: proposalId1)

    // Then
    let remainingScore = mockScores[proposalId2]
    let resetScore = mockScores[proposalId1]

    XCTAssertNil(resetScore, "Score for proposalId1 should be reset")
    XCTAssertNotNil(remainingScore, "Score for proposalId2 should remain")
    XCTAssertEqual(remainingScore?.proposalId, proposalId2)
  }

  // MARK: - LLM Quiz Tests

  private func makeLLMQuiz(
    id: String = UUID().uuidString,
    proposalId: String = "test",
    question: String = "What is Swift?",
    correctAnswer: String = "A programming language",
    wrongAnswers: [String] = ["A database", "An OS", "A browser"]
  ) -> LLMQuiz {
    LLMQuiz(
      id: id,
      proposalId: proposalId,
      question: question,
      correctAnswer: correctAnswer,
      wrongAnswers: wrongAnswers,
      explanation: "Test explanation",
      conceptTested: "Basics",
      difficulty: .beginner
    )
  }

  func testConfigure_LoadsLLMQuizzes() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId)
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)

    // When
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then
    XCTAssertEqual(sut.allLLMQuiz.count, 1)
    XCTAssertTrue(sut.hasLLMQuizzes)
  }

  func testConfigure_RestoresLLMQuizScore() async throws {
    // Given
    let proposalId = "0001"
    let quizId = "llm-q1"
    let llmQuiz = makeLLMQuiz(id: quizId, proposalId: proposalId)
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    let existingScore = LLMQuizScore(
      proposalId: proposalId,
      results: [
        LLMQuizResult(
          quizId: quizId, isCorrect: true,
          correctAnswer: "A programming language", userAnswer: "A programming language"
        )
      ]
    )
    mockLLMScores[proposalId] = existingScore

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)

    // When
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then
    XCTAssertEqual(sut.selectedLLMAnswer[quizId], "A programming language")
    XCTAssertEqual(sut.isLLMCorrect[quizId], true)
    XCTAssertEqual(sut.llmQuizScore?.correctCount, 1)
  }

  func testShowLLMQuizSelections_SetsCurrentLLMQuiz() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId)
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    // When
    sut.showLLMQuizSelections(index: 0)

    // Then
    XCTAssertNotNil(sut.currentLLMQuiz)
    XCTAssertEqual(sut.currentLLMQuiz?.id, llmQuiz.id)
  }

  func testShowLLMQuizSelections_OutOfBounds_DoesNotCrash() async throws {
    // Given
    let proposalId = "0001"
    mockLLMQuizzes[proposalId] = []
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    // When
    sut.showLLMQuizSelections(index: 5)

    // Then
    XCTAssertNil(sut.currentLLMQuiz)
  }

  func testSelectLLMAnswer_CorrectAnswer_UpdatesState() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId, correctAnswer: "Swift")
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)

    // When
    sut.selectLLMAnswer("Swift")

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(sut.isLLMCorrect[llmQuiz.id], true)
    XCTAssertEqual(sut.selectedLLMAnswer[llmQuiz.id], "Swift")
    XCTAssertEqual(sut.llmQuizScore?.correctCount, 1)
  }

  func testSelectLLMAnswer_WrongAnswer_UpdatesState() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId, correctAnswer: "Swift")
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)

    // When
    sut.selectLLMAnswer("Java")

    // Then
    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertEqual(sut.isLLMCorrect[llmQuiz.id], false)
    XCTAssertEqual(sut.selectedLLMAnswer[llmQuiz.id], "Java")
    XCTAssertEqual(sut.llmQuizScore?.correctCount, 0)
  }

  func testSelectLLMAnswer_AlreadyAnswered_DoesNotOverwrite() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId, correctAnswer: "Swift")
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)
    sut.selectLLMAnswer("Java")

    // When - try to answer again
    sut.selectLLMAnswer("Swift")

    // Then - original answer preserved
    XCTAssertEqual(sut.selectedLLMAnswer[llmQuiz.id], "Java")
    XCTAssertEqual(sut.isLLMCorrect[llmQuiz.id], false)
  }

  func testSelectLLMAnswer_SavesScoreToRepository() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId, correctAnswer: "Swift")
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)

    // When
    sut.selectLLMAnswer("Swift")

    // Then - wait for fire-and-forget save task
    try await Task.sleep(nanoseconds: 200_000_000)
    let savedScore = mockLLMScores[proposalId]
    XCTAssertNotNil(savedScore)
    XCTAssertEqual(savedScore?.results.first?.isCorrect, true)
    XCTAssertEqual(savedScore?.results.first?.userAnswer, "Swift")
  }

  func testDismissLLMQuiz_ClearsCurrentQuiz() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId)
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)
    XCTAssertNotNil(sut.currentLLMQuiz)

    // When
    sut.dismissLLMQuiz()

    // Then
    XCTAssertNil(sut.currentLLMQuiz)
  }

  func testResetLLMQuiz_ClearsAllLLMState() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId, correctAnswer: "Swift")
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    sut.showLLMQuizSelections(index: 0)
    sut.selectLLMAnswer("Swift")
    try await Task.sleep(nanoseconds: 100_000_000)

    // When
    await sut.resetLLMQuiz(for: proposalId)

    // Then
    XCTAssertTrue(sut.selectedLLMAnswer.isEmpty)
    XCTAssertTrue(sut.isLLMCorrect.isEmpty)
    XCTAssertNil(sut.llmQuizScore)
    XCTAssertNil(mockLLMScores[proposalId])
  }

  func testDeleteLLMQuizzes_ClearsAllLLMData() async throws {
    // Given
    let proposalId = "0001"
    let llmQuiz = makeLLMQuiz(proposalId: proposalId)
    mockLLMQuizzes[proposalId] = [llmQuiz]
    setQuizzes([], for: proposalId)

    sut = .init(proposalId: proposalId, quizRepository: mockRepository)
    await sut.configure()
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertTrue(sut.hasLLMQuizzes)

    // When
    await sut.deleteLLMQuizzes()
    try await Task.sleep(nanoseconds: 100_000_000)

    // Then
    XCTAssertFalse(sut.hasLLMQuizzes)
    XCTAssertTrue(sut.allLLMQuiz.isEmpty)
    XCTAssertNil(sut.llmQuizScore)
    XCTAssertNil(mockLLMQuizzes[proposalId])
  }
}
