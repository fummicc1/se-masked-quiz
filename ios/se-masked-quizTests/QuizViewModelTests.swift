import XCTest

@testable import se_masked_quiz

@MainActor
final class QuizViewModelTests: XCTestCase {
  var sut: QuizViewModel!
  var mockRepository: QuizRepositoryMock!
  var mockScores: [String: ProposalScore] = [:]
  var mockQuizzes: [String: [Quiz]] = [:]

  override func setUp() async throws {
    mockRepository = QuizRepositoryMock()
    mockScores = [:]
    mockQuizzes = [:]

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

    sut = QuizViewModel(proposalId: "test", quizRepository: mockRepository)
  }

  override func tearDown() async throws {
    mockScores = [:]
    mockQuizzes = [:]
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
}
