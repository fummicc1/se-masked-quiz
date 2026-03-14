//
//  LLMQuizView.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM Quiz Display UI
//

import SwiftUI

struct LLMQuizView: View {
  @ObservedObject var viewModel: QuizViewModel
  let onRegenerate: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        // スコアヘッダー
        if let score = viewModel.llmQuizScore, score.totalCount > 0 {
          HStack {
            Label(
              "\(score.correctCount)/\(score.totalCount) 正解",
              systemImage: "checkmark.circle.fill"
            )
            .font(.headline)
            .foregroundColor(score.correctCount == score.totalCount ? .green : .primary)
            Spacer()
            Text("\(Int(score.percentage))%")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(score.percentage >= 80 ? .green : score.percentage >= 50 ? .orange : .red)
          }
          .padding()
          .background(.regularMaterial)
          .cornerRadius(12)
          .padding(.horizontal)
        }

        LazyVStack(spacing: 16) {
          ForEach(Array(viewModel.allLLMQuiz.enumerated()), id: \.element.id) { index, quiz in
            quizCard(quiz: quiz, index: index)
          }
        }
        .padding()
      }
      .navigationTitle("LLMクイズ")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") { onDismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
          Button {
            onRegenerate()
          } label: {
            Label("再生成", systemImage: "arrow.trianglehead.2.clockwise")
          }
        }
      }
    }
  }

  @ViewBuilder
  private func quizCard(quiz: LLMQuiz, index: Int) -> some View {
    let isAnswered = viewModel.isLLMCorrect[quiz.id] != nil

    VStack(alignment: .leading, spacing: 12) {
      // 質問ヘッダー
      HStack(alignment: .top) {
        Text("Q\(index + 1)")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(isAnswered ? (viewModel.isLLMCorrect[quiz.id] == true ? Color.green : Color.red) : Color.accentColor)
          .cornerRadius(6)

        Text(quiz.question)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }

      // 選択肢
      ForEach(quiz.allChoices, id: \.self) { choice in
        Button {
          viewModel.showLLMQuizSelections(index: index)
          viewModel.selectLLMAnswer(choice)
        } label: {
          HStack {
            Text(choice)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading)
            if isAnswered {
              if choice == quiz.correctAnswer {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
              } else if choice == viewModel.selectedLLMAnswer[quiz.id] && choice != quiz.correctAnswer {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.red)
              }
            }
          }
          .padding()
          .background(choiceBackgroundColor(for: choice, quiz: quiz))
          .foregroundColor(isAnswered ? .primary : .white)
          .cornerRadius(10)
        }
        .disabled(isAnswered)
      }

      // 回答後: 解説
      if isAnswered {
        VStack(alignment: .leading, spacing: 8) {
          Divider()
          Label("解説", systemImage: "lightbulb.fill")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.orange)
          Text(quiz.explanation)
            .font(.callout)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          HStack {
            Label(quiz.conceptTested, systemImage: "tag.fill")
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
            Text(quiz.difficulty.rawValue)
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(difficultyColor(quiz.difficulty).opacity(0.2))
              .foregroundColor(difficultyColor(quiz.difficulty))
              .cornerRadius(4)
          }
        }
      }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(16)
  }

  private func difficultyColor(_ difficulty: QuizDifficulty) -> Color {
    switch difficulty {
    case .beginner: return .green
    case .intermediate: return .orange
    case .advanced: return .red
    }
  }

  private func choiceBackgroundColor(for choice: String, quiz: LLMQuiz) -> Color {
    guard let selectedAnswer = viewModel.selectedLLMAnswer[quiz.id] else {
      return .blue
    }

    if choice == quiz.correctAnswer {
      return .green.opacity(0.2)
    }

    if choice == selectedAnswer && selectedAnswer != quiz.correctAnswer {
      return .red.opacity(0.2)
    }

    return Color(.tertiarySystemBackground)
  }
}
