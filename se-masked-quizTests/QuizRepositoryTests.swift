import XCTest

@testable import se_masked_quiz

final class QuizRepositoryTests: XCTestCase {
  var sut: QuizRepositoryImpl!
  var userDefaults: UserDefaults!

  override func setUp() {
    userDefaults = UserDefaults(suiteName: #function)
    userDefaults.removePersistentDomain(forName: #function)

    sut = QuizRepositoryImpl(
      cloudflareR2Endpoint: "test-endpoint",
      r2AccessKey: "test-key",
      r2SecretKey: "test-secret",
      userDefaults: userDefaults
    )
  }

  override func tearDown() {
    userDefaults.removePersistentDomain(forName: #function)
    userDefaults = nil
    sut = nil
  }

  func testSaveAndGetScore() async throws {
    // Given
    let questionResults = [
      QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
      QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
    ]
    let score = ProposalScore(proposalId: "0001", questionResults: questionResults)

    // When
    await sut.saveScore(score)
    let retrievedScore = await sut.getScore(for: "0001")

    // Then
    XCTAssertEqual(retrievedScore?.proposalId, score.proposalId)
    XCTAssertEqual(retrievedScore?.questionResults.count, 2)
    XCTAssertEqual(retrievedScore?.correctCount, 1)
    XCTAssertEqual(retrievedScore?.totalCount, 2)
    XCTAssertEqual(retrievedScore?.questionResults[0].answer, "Swift")
    XCTAssertEqual(retrievedScore?.questionResults[1].answer, "async")
  }

  func testGetAllScores() async throws {
    // Given
    let scores = [
      ProposalScore(
        proposalId: "0001",
        questionResults: [
          QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
          QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
        ]
      ),
      ProposalScore(
        proposalId: "0002",
        questionResults: [
          QuestionResult(index: 0, isCorrect: true, answer: "protocol", userAnswer: "protocol"),
          QuestionResult(index: 1, isCorrect: true, answer: "actor", userAnswer: "actor"),
          QuestionResult(index: 2, isCorrect: false, answer: "await", userAnswer: "async"),
        ]
      ),
    ]

    // When
    for score in scores {
      await sut.saveScore(score)
    }
    let retrievedScores = await sut.getAllScores()

    // Then
    XCTAssertEqual(retrievedScores.count, 2)
    XCTAssertEqual(retrievedScores["0001"]?.correctCount, 1)
    XCTAssertEqual(retrievedScores["0002"]?.correctCount, 2)
    XCTAssertEqual(retrievedScores["0001"]?.questionResults.count, 2)
    XCTAssertEqual(retrievedScores["0002"]?.questionResults.count, 3)
  }

  func testGetScore_WhenNotExists_ReturnsNil() async throws {
    // When
    let score = await sut.getScore(for: "non-existent")

    // Then
    XCTAssertNil(score)
  }

  func testSaveScore_WhenUpdatingExisting_OverwritesPrevious() async throws {
    // Given
    let initialScore = ProposalScore(
      proposalId: "0001",
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
        QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
      ]
    )

    let updatedScore = ProposalScore(
      proposalId: "0001",
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
        QuestionResult(index: 1, isCorrect: true, answer: "async", userAnswer: "async"),
      ]
    )

    // When
    await sut.saveScore(initialScore)
    await sut.saveScore(updatedScore)

    // Then
    let retrievedScore = await sut.getScore(for: "0001")
    XCTAssertEqual(retrievedScore?.correctCount, 2)
    XCTAssertEqual(retrievedScore?.questionResults[1].isCorrect, true)
    XCTAssertEqual(retrievedScore?.questionResults[1].userAnswer, "async")
  }

  func testResetScore_RemovesScoreForProposal() async throws {
    // Given
    let questionResults = [
      QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
      QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync"),
    ]
    let score = ProposalScore(proposalId: "0001", questionResults: questionResults)
    await sut.saveScore(score)

    // Verify initial state
    let initialScore = await sut.getScore(for: "0001")
    XCTAssertNotNil(initialScore)

    // When
    await sut.resetScore(for: "0001")

    // Then
    let resetScore = await sut.getScore(for: "0001")
    XCTAssertNil(resetScore)
  }

  func testResetScore_WhenMultipleScoresExist_OnlyRemovesTargetScore() async throws {
    // Given
    let score1 = ProposalScore(
      proposalId: "0001",
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift")
      ]
    )

    let score2 = ProposalScore(
      proposalId: "0002",
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "async", userAnswer: "async")
      ]
    )

    // Save both scores
    await sut.saveScore(score1)
    await sut.saveScore(score2)

    // Verify initial state
    let initialScores = await sut.getAllScores()
    XCTAssertEqual(initialScores.count, 2)

    // When
    await sut.resetScore(for: "0001")

    // Then
    let finalScores = await sut.getAllScores()
    XCTAssertEqual(finalScores.count, 1)
    XCTAssertNil(finalScores["0001"])
    XCTAssertNotNil(finalScores["0002"])
    XCTAssertEqual(finalScores["0002"]?.questionResults.first?.answer, "async")
  }

  func testResetScore_WhenScoreDoesNotExist_DoesNothing() async throws {
    // Given
    let score = ProposalScore(
      proposalId: "0001",
      questionResults: [
        QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift")
      ]
    )
    await sut.saveScore(score)

    // When
    await sut.resetScore(for: "non-existent")

    // Then
    let scores = await sut.getAllScores()
    XCTAssertEqual(scores.count, 1)
    XCTAssertNotNil(scores["0001"])
  }
}
