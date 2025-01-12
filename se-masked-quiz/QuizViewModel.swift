import SwiftUI

@MainActor
final class QuizViewModel: ObservableObject {
  @Published var currentQuiz: Quiz?
  @Published var isShowingQuiz = false
  @Published var selectedAnswer: [Int: String] = [:]
  @Published var isCorrect: [Int: Bool] = [:]
  @Published var allQuiz: [Quiz] = []
  @Published var answers: [Int: String] = [:]
  @Published var currentScore: ProposalScore?

  private let quizRepository: any QuizRepository

  init(quizRepository: any QuizRepository) {
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
        // Load existing score
        if let existingScore = await quizRepository.getScore(for: proposalId) {
          currentScore = existingScore
          // Restore previous answers and results
          for result in existingScore.questionResults {
            selectedAnswer[result.index] = result.userAnswer
            isCorrect[result.index] = result.isCorrect
          }
        }
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
      updateScore()
    }
  }

  func dismissQuiz() {
    isShowingQuiz = false
    currentQuiz = nil
  }

  private func updateScore() {
    guard let proposalId = currentQuiz?.proposalId else { return }

    let questionResults = allQuiz.map { quiz in
      QuestionResult(
        index: quiz.index,
        isCorrect: isCorrect[quiz.index] ?? false,
        answer: quiz.answer,
        userAnswer: selectedAnswer[quiz.index] ?? ""
      )
    }

    let newScore = ProposalScore(
      proposalId: proposalId,
      questionResults: questionResults
    )

    currentScore = newScore
    Task {
      await quizRepository.saveScore(newScore)
    }
  }
}

extension QuizViewModel: @preconcurrency EnvironmentKey {
  static let defaultValue: QuizViewModel = QuizViewModel(
    quizRepository: QuizRepositoryImpl.defaultValue)
}

extension EnvironmentValues {
  var quizViewModel: QuizViewModel {
    get { self[QuizViewModel.self] }
    set { self[QuizViewModel.self] = newValue }
  }
}
