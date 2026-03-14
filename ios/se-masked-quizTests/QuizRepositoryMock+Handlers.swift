import Foundation
@testable import se_masked_quiz

// Extension to safely set handlers for QuizRepositoryMock (actor-isolated)
extension QuizRepositoryMock {
  /// Sets all default handlers for the mock repository
  func setDefaultHandlers(
    scores: @escaping @Sendable () -> [String: ProposalScore],
    quizzes: @escaping @Sendable (String) throws -> [Quiz]
  ) {
    getAllScoresHandler = { scores() }

    getScoreHandler = { proposalId in
      scores()[proposalId]
    }

    saveScoreHandler = { score in
      // Handler will be set in test to modify the test's mockScores
    }

    resetScoreHandler = { proposalId in
      // Handler will be set in test to modify the test's mockScores
    }

    fetchQuizHandler = { proposalId in
      try quizzes(proposalId)
    }
  }

  /// Sets handler for getAllScores
  func setGetAllScoresHandler(_ handler: @escaping @Sendable () async -> [String: ProposalScore]) {
    getAllScoresHandler = handler
  }

  /// Sets handler for getScore
  func setGetScoreHandler(_ handler: @escaping @Sendable (String) async -> ProposalScore?) {
    getScoreHandler = handler
  }

  /// Sets handler for saveScore
  func setSaveScoreHandler(_ handler: @escaping @Sendable (ProposalScore) async -> Void) {
    saveScoreHandler = handler
  }

  /// Sets handler for resetScore
  func setResetScoreHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    resetScoreHandler = handler
  }

  /// Sets handler for fetchQuiz
  func setFetchQuizHandler(_ handler: @escaping @Sendable (String) async throws -> [Quiz]) {
    fetchQuizHandler = handler
  }

  // MARK: - LLM Quiz Handlers

  /// Sets handler for getLLMQuizzes
  func setGetLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> [LLMQuiz]) {
    getLLMQuizzesHandler = handler
  }

  /// Sets handler for hasLLMQuizzes
  func setHasLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> Bool) {
    hasLLMQuizzesHandler = handler
  }

  /// Sets handler for saveLLMQuizzes
  func setSaveLLMQuizzesHandler(_ handler: @escaping @Sendable ([LLMQuiz], String) async -> Void) {
    saveLLMQuizzesHandler = handler
  }

  /// Sets handler for deleteLLMQuizzes
  func setDeleteLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    deleteLLMQuizzesHandler = handler
  }

  /// Sets handler for saveLLMQuizScore
  func setSaveLLMQuizScoreHandler(_ handler: @escaping @Sendable (LLMQuizScore) async -> Void) {
    saveLLMQuizScoreHandler = handler
  }

  /// Sets handler for getLLMQuizScore
  func setGetLLMQuizScoreHandler(_ handler: @escaping @Sendable (String) async -> LLMQuizScore?) {
    getLLMQuizScoreHandler = handler
  }

  /// Sets handler for resetLLMQuizScore
  func setResetLLMQuizScoreHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    resetLLMQuizScoreHandler = handler
  }
}
