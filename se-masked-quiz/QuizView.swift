import SwiftUI

struct QuizView: View {
    @ObservedObject var viewModel: QuizViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let quiz = viewModel.currentQuiz {
                Text(
                    "マスクされた単語: \(Array(repeating: "◻︎", count: quiz.answer.count).joined(separator: ""))"
                )
                .font(.headline)
                
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
                    .disabled(viewModel.selectedAnswer != nil)
                }
                
                if let isCorrect = viewModel.isCorrect {
                    Text(isCorrect ? "正解！" : "不正解...")
                        .font(.title)
                        .foregroundColor(isCorrect ? .green : .red)
                    
                    Button("閉じる", action: viewModel.dismissQuiz)
                }
            }
        }
        .padding()
    }
    
    private func backgroundColor(for choice: String) -> Color {
        guard let selectedAnswer = viewModel.selectedAnswer else {
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
    QuizView(viewModel: QuizViewModel(quizRepository: QuizRepository.defaultValue))
} 
