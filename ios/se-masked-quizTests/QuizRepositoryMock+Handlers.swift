import Foundation
@testable import se_masked_quiz

// Extension to safely set handlers for QuizRepositoryMock (actor-isolated)
extension QuizRepositoryMock {
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

  func setGetAllScoresHandler(_ handler: @escaping @Sendable () async -> [String: ProposalScore]) {
    getAllScoresHandler = handler
  }

  func setGetScoreHandler(_ handler: @escaping @Sendable (String) async -> ProposalScore?) {
    getScoreHandler = handler
  }

  func setSaveScoreHandler(_ handler: @escaping @Sendable (ProposalScore) async -> Void) {
    saveScoreHandler = handler
  }

  func setResetScoreHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    resetScoreHandler = handler
  }

  func setFetchQuizHandler(_ handler: @escaping @Sendable (String) async throws -> [Quiz]) {
    fetchQuizHandler = handler
  }

  // MARK: - LLM Quiz Handlers

  func setGetLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> [LLMQuiz]) {
    getLLMQuizzesHandler = handler
  }

  func setHasLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> Bool) {
    hasLLMQuizzesHandler = handler
  }

  func setSaveLLMQuizzesHandler(_ handler: @escaping @Sendable ([LLMQuiz], String) async -> Void) {
    saveLLMQuizzesHandler = handler
  }

  func setDeleteLLMQuizzesHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    deleteLLMQuizzesHandler = handler
  }

  func setSaveLLMQuizScoreHandler(_ handler: @escaping @Sendable (LLMQuizScore) async -> Void) {
    saveLLMQuizScoreHandler = handler
  }

  func setGetLLMQuizScoreHandler(_ handler: @escaping @Sendable (String) async -> LLMQuizScore?) {
    getLLMQuizScoreHandler = handler
  }

  func setResetLLMQuizScoreHandler(_ handler: @escaping @Sendable (String) async -> Void) {
    resetLLMQuizScoreHandler = handler
  }
}
