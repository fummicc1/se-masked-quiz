import SwiftUI

struct QuizSelectionsView: View {
  @EnvironmentObject var viewModel: QuizViewModel

  var body: some View {
    VStack(spacing: 12) {
      if let quiz = viewModel.currentQuiz {
        ForEach(quiz.allChoices, id: \.self) { choice in
          Button(action: {
            viewModel.selectAnswer(choice)
          }) {
            Text(choice)
              .frame(maxWidth: .infinity)
              .padding()
              .background(backgroundColor(for: choice))
              .foregroundColor(.white)
              .cornerRadius(10)
          }
          .disabled(viewModel.selectedAnswer[quiz.index] != nil)
        }

        VStack {
          VStack {
            if let isCorrect = viewModel.isCorrect[quiz.index] {
              Text(isCorrect ? "正解！" : "不正解...")
                .font(.title)
                .foregroundColor(isCorrect ? .green : .red)
            }
          }
          .frame(height: 32)
          Button("閉じる", action: viewModel.dismissQuiz)
            .padding(4)
        }
      }
    }
    .padding()
  }

  private func backgroundColor(for choice: String) -> Color {
    guard let currentQuiz = viewModel.currentQuiz else {
      return .clear
    }
    guard let selectedAnswer = viewModel.selectedAnswer[currentQuiz.index] else {
      return .blue
    }

    if choice == viewModel.currentQuiz?.answer {
      return .green
    }

    if choice == selectedAnswer && selectedAnswer != viewModel.currentQuiz?.answer {
      return .red
    }

    return .gray
  }
}

#Preview {
  QuizSelectionsView()
    .environmentObject(QuizViewModel(quizRepository: QuizRepositoryImpl.defaultValue))
}
