import SwiftUI

struct QuizSelectionsView: View {
  @ObservedObject var viewModel: QuizViewModel

  var body: some View {
    VStack(spacing: 12) {
      if let quiz = viewModel.currentQuiz {
        ForEach(quiz.allChoices, id: \.self) { choice in
          QuizChoiceButton(
            title: choice,
            state: choiceState(for: choice, quiz: quiz)
          ) {
            viewModel.selectAnswer(choice)
          }
        }

        VStack {
          VStack {
            if let isCorrect = viewModel.isCorrect[quiz.index] {
              Text(isCorrect ? "正解！" : "不正解...")
                .font(AppFont.title)
                .foregroundStyle(isCorrect ? SemanticColor.correct : SemanticColor.incorrect)
            }
          }
          .frame(height: 32)
          Button("閉じる", action: viewModel.dismissQuiz)
            .padding(AppSpacing.xs)
        }
      }
    }
    .padding()
  }

  private func choiceState(for choice: String, quiz: Quiz) -> ChoiceState {
    guard let selectedAnswer = viewModel.selectedAnswer[quiz.index] else {
      return .unanswered
    }
    if choice == quiz.answer {
      return .correct
    }
    if choice == selectedAnswer {
      return .incorrectSelected
    }
    return .incorrectOther
  }
}

#Preview {
  QuizSelectionsView(
    viewModel: .init(
      proposalId: "",
      quizRepository: QuizRepositoryImpl()
    )
  )
}
