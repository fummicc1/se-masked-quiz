import Foundation
@testable import se_masked_quiz

actor MockQuizRepository: QuizRepository {
    var savedScores: [String: ProposalScore] = [:]
    var quizzes: [String: [Quiz]] = [:]
    var shouldThrowError = false
    
    static var defaultValue: any QuizRepository {
        MockQuizRepository()
    }
    
    func saveScore(_ score: ProposalScore) async {
        savedScores[score.proposalId] = score
    }
    
    func getAllScores() async -> [String: ProposalScore] {
        savedScores
    }
    
    func getScore(for proposalId: String) async -> ProposalScore? {
        savedScores[proposalId]
    }
    
    func fetchQuiz(for proposalId: String) async throws -> [Quiz] {
        if shouldThrowError {
            throw QuizError.proposalNotFound
        }
        return quizzes[proposalId] ?? []
    }

    func resetScore(for proposalId: String) async {
        savedScores[proposalId] = nil
    }

    // Test Helper Methods
    func setQuizzes(_ quizzes: [Quiz], for proposalId: String) {
        self.quizzes[proposalId] = quizzes
    }
    
    func clearAll() {
        savedScores = [:]
        quizzes = [:]
        shouldThrowError = false
    }
}
