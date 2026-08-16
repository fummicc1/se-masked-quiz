import SwiftUI

struct QuizSelectionsView: View {
  @ObservedObject var viewModel: QuizViewModel

  var body: some View {
    if let quiz = viewModel.currentQuiz {
      ScrollView {
        VStack(spacing: AppSpacing.md) {
          header(for: quiz)

          ForEach(quiz.allChoices, id: \.self) { choice in
            QuizChoiceButton(
              title: choice,
              state: choiceState(for: choice, quiz: quiz)
            ) {
              viewModel.selectAnswer(choice)
            }
          }

          primaryAction(for: quiz)
        }
        .padding(AppSpacing.lg)
      }
      .scrollBounceBehavior(.basedOnSize)
      .animation(.snappy, value: viewModel.isCorrect[quiz.index])
      .sensoryFeedback(trigger: viewModel.isCorrect[quiz.index]) { _, newValue in
        guard let isCorrect = newValue else { return nil }
        return isCorrect ? .success : .error
      }
      .sensoryFeedback(.selection, trigger: viewModel.pendingScrollMaskIndex)
    }
  }

  private var answeredCount: Int { viewModel.isCorrect.count }
  private var totalCount: Int { viewModel.allQuiz.count }
  private var isAllAnswered: Bool { totalCount > 0 && answeredCount >= totalCount }

  private func header(for quiz: Quiz) -> some View {
    HStack(spacing: AppSpacing.sm) {
      Group {
        if isAllAnswered {
          Text("全問解答済み")
            .foregroundStyle(SemanticColor.correct)
        } else {
          Text("\(answeredCount)/\(totalCount)問")
            .foregroundStyle(.secondary)
        }
      }
      .font(AppFont.subheadline)
      .monospacedDigit()

      Spacer()

      resultLabel(for: quiz)

      Button(action: viewModel.dismissQuiz) {
        Image(systemName: "xmark.circle.fill")
          .font(AppFont.title)
          .foregroundStyle(.secondary)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("クイズを閉じる")
    }
  }

  /// 未解答時も opacity で場所を確保する。表示・非表示で高さが変わると
  /// 直前に押したボタンの位置がずれるため
  private func resultLabel(for quiz: Quiz) -> some View {
    let isCorrect = viewModel.isCorrect[quiz.index]
    return Label(
      isCorrect == true ? "正解" : "不正解",
      systemImage: isCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill"
    )
    .font(AppFont.headline)
    .foregroundStyle(isCorrect == true ? SemanticColor.correct : SemanticColor.incorrect)
    .opacity(isCorrect == nil ? 0 : 1)
    .accessibilityLabel(isCorrect == true ? "正解" : "不正解、答えは \(quiz.answer)")
    .accessibilityHidden(isCorrect == nil)
  }

  private func primaryAction(for quiz: Quiz) -> some View {
    let isAnswered = viewModel.isCorrect[quiz.index] != nil
    let hasNext = viewModel.nextUnansweredMaskIndex != nil
    return Button {
      if hasNext {
        viewModel.goToNextUnansweredQuiz()
      } else {
        viewModel.dismissQuiz()
      }
    } label: {
      Text(hasNext ? "次の問題へ" : "閉じる")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.glassProminent)
    .controlSize(.large)
    .opacity(isAnswered ? 1 : 0)
    .disabled(!isAnswered)
    .accessibilityHidden(!isAnswered)
    .accessibilityHint(hasNext ? "次の未解答の空欄まで本文をスクロールします" : "")
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
