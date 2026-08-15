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
          footer(for: quiz)
            .padding(AppSpacing.xs)
        }
      }
    }
    .padding(AppSpacing.lg)
    .sensoryFeedback(trigger: viewModel.currentQuiz.map { viewModel.isCorrect[$0.index] }) {
      _, newValue in
      guard let isCorrect = newValue ?? nil else { return nil }
      return isCorrect ? .success : .error
    }
    .sensoryFeedback(.selection, trigger: viewModel.pendingScrollMaskIndex)
  }

  @ViewBuilder
  private func footer(for quiz: Quiz) -> some View {
    if viewModel.isCorrect[quiz.index] == nil {
      Button("閉じる", action: viewModel.dismissQuiz)
    } else if viewModel.nextUnansweredMaskIndex != nil {
      VStack(spacing: AppSpacing.sm) {
        Button("次の問題へ", action: viewModel.goToNextUnansweredQuiz)
          .buttonStyle(.glassProminent)
        Button("閉じる", action: viewModel.dismissQuiz)
      }
    } else {
      VStack(spacing: AppSpacing.sm) {
        Text("全問解答済み")
          .font(AppFont.headline)
          .foregroundStyle(SemanticColor.correct)
        Button("閉じる", action: viewModel.dismissQuiz)
      }
    }
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
