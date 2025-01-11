import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
    @Published var currentQuiz: Quiz?
    @Published var isShowingQuiz = false
    @Published var selectedAnswer: [Int: String] = [:]
    @Published var isCorrect: [Int: Bool] = [:]
    @Published var allQuiz: [Quiz] = []
    @Published var answers: [Int: String] = [:]

    private let quizRepository: QuizRepository
    
    init(quizRepository: QuizRepository) {
        self.quizRepository = quizRepository
    }
    
    func startQuiz(for proposalId: String) {
        Task {
            do {
                allQuiz = try await quizRepository.fetchQuiz(for: proposalId)
                isShowingQuiz = true
                selectedAnswer = [:]
                isCorrect = [:]
                answers = Dictionary(uniqueKeysWithValues: allQuiz.map { ($0.index, $0.answer) })
            } catch {
                print("Failed to fetch quiz:", error)
            }
        }
    }
    
    func showQuizSelections(index: Int) {
        currentQuiz = allQuiz[index]
        isShowingQuiz = true
    }
    
    func selectAnswer(_ answer: String) {
        if let currentQuiz = currentQuiz, isCorrect[currentQuiz.index] == nil {
            selectedAnswer[currentQuiz.index] = answer
            let index = currentQuiz.index
            isCorrect[index] = answer == currentQuiz.answer
        }
    }
    
    func dismissQuiz() {
        isShowingQuiz = false
        currentQuiz = nil
    }
} 

extension QuizViewModel: @preconcurrency EnvironmentKey {
    static let defaultValue: QuizViewModel = QuizViewModel(quizRepository: QuizRepository.defaultValue)
}

extension EnvironmentValues {
    var quizViewModel: QuizViewModel {
        get { self[QuizViewModel.self] }
        set { self[QuizViewModel.self] = newValue }
    }
}
