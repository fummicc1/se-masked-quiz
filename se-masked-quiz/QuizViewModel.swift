import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
    @Published var currentQuiz: Quiz?
    @Published var isShowingQuiz = false
    @Published var selectedAnswer: String?
    @Published var isCorrect: Bool?
    
    private let quizRepository: QuizRepository
    
    init(quizRepository: QuizRepository) {
        self.quizRepository = quizRepository
    }
    
    func startQuiz(for proposalId: String) {
        Task {
            do {
                currentQuiz = try await quizRepository.fetchQuiz(for: proposalId)
                isShowingQuiz = true
                selectedAnswer = nil
                isCorrect = nil
            } catch {
                print("Failed to fetch quiz:", error)
            }
        }
    }
    
    func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        if let currentQuiz = currentQuiz {
            isCorrect = answer == currentQuiz.answer
        }
    }
    
    func dismissQuiz() {
        isShowingQuiz = false
        currentQuiz = nil
        selectedAnswer = nil
        isCorrect = nil
    }
} 