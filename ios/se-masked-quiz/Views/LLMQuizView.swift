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
            .font(AppFont.headline)
            .foregroundStyle(
              score.correctCount == score.totalCount ? SemanticColor.correct : Color.primary)
            Spacer()
            Text("\(Int(score.percentage))%")
              .font(AppFont.title)
              .foregroundStyle(scoreColor(for: score.percentage))
          }
          .padding()
          .glassCard()
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

  private func scoreColor(for percentage: Double) -> Color {
    if percentage >= 80 { return SemanticColor.correct }
    if percentage >= 50 { return SemanticColor.warning }
    return SemanticColor.incorrect
  }

  @ViewBuilder
  private func quizCard(quiz: LLMQuiz, index: Int) -> some View {
    let isAnswered = viewModel.isLLMCorrect[quiz.id] != nil

    VStack(alignment: .leading, spacing: 12) {
      // 質問ヘッダー
      HStack(alignment: .top) {
        AppBadge(text: "Q\(index + 1)", style: .solid(questionBadgeColor(quiz: quiz, isAnswered: isAnswered)))
        Text(quiz.question)
          .font(AppFont.body)
          .fixedSize(horizontal: false, vertical: true)
      }

      // 選択肢
      ForEach(quiz.allChoices, id: \.self) { choice in
        QuizChoiceButton(
          title: choice,
          state: choiceState(for: choice, quiz: quiz, isAnswered: isAnswered)
        ) {
          viewModel.showLLMQuizSelections(index: index)
          viewModel.selectLLMAnswer(choice)
        }
      }

      // 回答後: 解説
      if isAnswered {
        VStack(alignment: .leading, spacing: 8) {
          Divider()
          Label("解説", systemImage: "lightbulb.fill")
            .font(AppFont.subheadline.weight(.semibold))
            .foregroundStyle(SemanticColor.warning)
          Text(quiz.explanation)
            .font(AppFont.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          HStack {
            Label(quiz.conceptTested, systemImage: "tag.fill")
              .font(AppFont.caption)
              .foregroundStyle(.secondary)
            Spacer()
            AppBadge(text: quiz.difficulty.rawValue, style: .subtle(difficultyColor(quiz.difficulty)))
          }
        }
      }
    }
    .padding()
    .glassCard(cornerRadius: AppRadius.extraLarge)
  }

  private func difficultyColor(_ difficulty: QuizDifficulty) -> Color {
    switch difficulty {
    case .beginner: return SemanticColor.correct
    case .intermediate: return SemanticColor.warning
    case .advanced: return SemanticColor.incorrect
    }
  }

  private func questionBadgeColor(quiz: LLMQuiz, isAnswered: Bool) -> Color {
    guard isAnswered else { return .accentColor }
    return viewModel.isLLMCorrect[quiz.id] == true ? SemanticColor.correct : SemanticColor.incorrect
  }

  private func choiceState(for choice: String, quiz: LLMQuiz, isAnswered: Bool) -> ChoiceState {
    guard isAnswered else { return .unanswered }
    if choice == quiz.correctAnswer {
      return .correct
    }
    if choice == viewModel.selectedLLMAnswer[quiz.id] {
      return .incorrectSelected
    }
    return .incorrectOther
  }
}
