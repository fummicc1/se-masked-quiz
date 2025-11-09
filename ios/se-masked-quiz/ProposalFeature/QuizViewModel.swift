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
  @Published var isShowingResetAlert = false
  @Published var isConfigured: Bool = false

  private let quizRepository: any QuizRepository
  private let proposalId: String

  init(proposalId: String, quizRepository: any QuizRepository) {
    self.quizRepository = quizRepository
    self.proposalId = proposalId
  }

  func configure() async {
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
      isConfigured = true
    } catch {
      print("Failed to fetch quiz:", error)
    }
  }

  func showQuizSelections(index: Int) {
    guard isConfigured else { return }
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
    
    let allQuizByIndex = Dictionary(uniqueKeysWithValues: allQuiz.map({ ($0.index, $0) }))

    let questionResults = zip(selectedAnswer, isCorrect)
      .compactMap({ args -> QuestionResult? in
        let _selectedAnswer = args.0
        let _isCorrect = args.1
        
        guard let quiz = allQuizByIndex[_selectedAnswer.key] else {
          return nil
        }
        return QuestionResult(
          index: quiz.index,
          isCorrect: _isCorrect.value,
          answer: quiz.answer,
          userAnswer: _selectedAnswer.value
        )
      })

    let newScore = ProposalScore(
      proposalId: proposalId,
      questionResults: questionResults
    )

    currentScore = newScore
    Task {
      await quizRepository.saveScore(newScore)
    }
  }

  func resetQuiz(for proposalId: String) async {
    await quizRepository.resetScore(for: proposalId)
    selectedAnswer = [:]
    isCorrect = [:]
    currentScore = nil
  }
}
