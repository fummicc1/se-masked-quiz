import XCTest

@testable import se_masked_quiz

@MainActor
final class QuizViewModelTests: XCTestCase {
  var sut: QuizViewModel!
  var mockRepository: QuizRepositoryMock!

  override func setUp() async throws {
    mockRepository = QuizRepositoryMock()
  }

  override func tearDown() async throws {
    sut = nil
    mockRepository = nil
  }

  @MainActor
  func test_Configure_WhenSuccessful_LoadsQuizAndScore() async throws {
    // Given
    let proposalId = "0001"
    sut = QuizViewModel(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    let quizzes = [
      Quiz(
        id: "1", proposalId: proposalId, index: 0, answer: "Swift",
        choices: ["Java", "Kotlin", "Rust"]),
      Quiz(
        id: "2", proposalId: proposalId, index: 1, answer: "async",
        choices: ["sync", "await", "concurrent"]),
    ]
    let existingResults = [
      QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
      QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
    ]
    let existingScore = ProposalScore(proposalId: proposalId, questionResults: existingResults)
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in quizzes }
      mockRepository.getScoreHandler = { _ in existingScore }
    }

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

  func test_Configure_WhenError_HandlesFailure() async throws {
    // Given
    let proposalId = "0001"
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in
        throw NSError(domain: "TestError", code: 1, userInfo: nil)
      }
    }
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

  func test_SelectAnswer_WhenCorrect_UpdatesScoreAndSaves() async throws {
    // Given
    let proposalId = "0001"
    sut = QuizViewModel(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    
    // Set up mock repository with score storage
    var savedScores: [String: ProposalScore] = [:]
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in [quiz] }
      mockRepository.getScoreHandler = { pId in savedScores[pId] }
      mockRepository.saveScoreHandler = { score in
        savedScores[score.proposalId] = score
      }
    }
    
    // Configure to load quiz
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
    let savedScore = await mockRepository.getScore(for: proposalId)
    XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, true)
    XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Swift")
  }

  func test_SelectAnswer_WhenIncorrect_UpdatesScoreAndSaves() async throws {
    // Given
    let proposalId = "0001"
    sut = QuizViewModel(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    
    // Set up mock repository with score storage
    var savedScores: [String: ProposalScore] = [:]
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in [quiz] }
      mockRepository.getScoreHandler = { pId in savedScores[pId] }
      mockRepository.saveScoreHandler = { score in
        savedScores[score.proposalId] = score
      }
    }
    
    // Configure to load quiz
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
    let savedScore = await mockRepository.getScore(for: proposalId)
    XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, false)
    XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Java")
  }

  func test_DismissQuiz_ClearsCurrentQuiz() async throws {
    // Given
    let proposalId = "0001"
    sut = QuizViewModel(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    
    // Set up mock repository with score storage
    var savedScores: [String: ProposalScore] = [:]
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in [quiz] }
      mockRepository.getScoreHandler = { pId in savedScores[pId] }
      mockRepository.saveScoreHandler = { score in
        savedScores[score.proposalId] = score
      }
    }
    
    // Configure to load quiz
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

  func test_ResetQuiz_ClearsAllStateAndScore() async throws {
    // Given
    let proposalId = "0001"
    sut = QuizViewModel(
      proposalId: proposalId,
      quizRepository: mockRepository
    )
    let quiz = Quiz(
      id: "1", proposalId: proposalId, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])
    
    // Set up mock repository with score storage
    var savedScores: [String: ProposalScore] = [:]
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { _ in [quiz] }
      mockRepository.getScoreHandler = { pId in savedScores[pId] }
      mockRepository.saveScoreHandler = { score in
        savedScores[score.proposalId] = score
      }
      mockRepository.resetScoreHandler = { pId in
        savedScores.removeValue(forKey: pId)
      }
    }
    
    // Configure to load quiz
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
  }

  func test_ResetQuiz_WhenMultipleScoresExist_OnlyResetsTargetScore() async throws {
    // Given
    let proposalId1 = "0001"
    let proposalId2 = "0002"
    sut = QuizViewModel(
      proposalId: proposalId1,
      quizRepository: mockRepository
    )

    // Set up first quiz
    let quiz1 = Quiz(
      id: "1", proposalId: proposalId1, index: 0, answer: "Swift",
      choices: ["Java", "Kotlin", "Rust"])

    // Set up second quiz
    let quiz2 = Quiz(
      id: "2", proposalId: proposalId2, index: 0, answer: "async",
      choices: ["sync", "await", "concurrent"])
    
    // Set up mock repository with score storage
    var savedScores: [String: ProposalScore] = [:]
    try await updateActor(mockRepository) { mockRepository in
      mockRepository.fetchQuizHandler = { pId in
        if pId == proposalId1 { return [quiz1] }
        else if pId == proposalId2 { return [quiz2] }
        else { return [] }
      }
      mockRepository.getScoreHandler = { pId in savedScores[pId] }
      mockRepository.saveScoreHandler = { score in
        savedScores[score.proposalId] = score
      }
      mockRepository.resetScoreHandler = { pId in
        savedScores.removeValue(forKey: pId)
      }
    }

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

    await mockRepository.saveScore(score1)
    await mockRepository.saveScore(score2)

    // When
    await sut.resetQuiz(for: proposalId1)

    // Then
    let remainingScore = await mockRepository.getScore(for: proposalId2)
    let resetScore = await mockRepository.getScore(for: proposalId1)

    XCTAssertNil(resetScore, "Score for proposalId1 should be reset")
    XCTAssertNotNil(remainingScore, "Score for proposalId2 should remain")
    XCTAssertEqual(remainingScore?.proposalId, proposalId2)
  }
}

private func updateActor<R: Actor>(
  _ actor: R, call: (isolated R) async throws -> Void
) async throws {
  try await call(actor)
}
