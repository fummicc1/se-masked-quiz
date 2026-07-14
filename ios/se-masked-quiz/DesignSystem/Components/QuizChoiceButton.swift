//
//  QuizChoiceButton.swift
//  se-masked-quiz
//
//  QuizSelectionsView / LLMQuizView で個別実装されていた選択肢ボタンを統合したコンポーネント。
//  アイコン付きの表示方式（旧LLMQuizView方式）を正準デザインとする。
//

import SwiftUI

enum ChoiceState {
  case unanswered
  case correct
  case incorrectSelected
  case incorrectOther
}

struct QuizChoiceButton: View {
  let title: String
  let state: ChoiceState
  let action: () -> Void

  private var isAnswered: Bool {
    state != .unanswered
  }

  var body: some View {
    Button(action: action) {
      HStack {
        Text(title)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        if state == .correct {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(SemanticColor.correct)
        } else if state == .incorrectSelected {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(SemanticColor.incorrect)
        }
      }
      .padding()
      .background(backgroundColor)
      .foregroundStyle(isAnswered ? Color.primary : Color.white)
      .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
      .animation(.easeInOut(duration: 0.2), value: state)
    }
    .disabled(isAnswered)
    .accessibilityLabel(title)
    .accessibilityValue(accessibilityValue)
  }

  private var backgroundColor: Color {
    switch state {
    case .unanswered:
      return SemanticColor.inProgress
    case .correct:
      return SemanticColor.correct.opacity(0.2)
    case .incorrectSelected:
      return SemanticColor.incorrect.opacity(0.2)
    case .incorrectOther:
      return Color.secondary.opacity(0.12)
    }
  }

  private var accessibilityValue: String {
    switch state {
    case .unanswered: return ""
    case .correct: return "正解"
    case .incorrectSelected: return "不正解"
    case .incorrectOther: return ""
    }
  }
}

#Preview("未回答") {
  QuizChoiceButton(title: "選択肢A", state: .unanswered, action: {})
    .padding()
}

#Preview("正解") {
  QuizChoiceButton(title: "選択肢A", state: .correct, action: {})
    .padding()
}

#Preview("不正解（選択済み）") {
  QuizChoiceButton(title: "選択肢A", state: .incorrectSelected, action: {})
    .padding()
}

#Preview("不正解（未選択）") {
  QuizChoiceButton(title: "選択肢A", state: .incorrectOther, action: {})
    .padding()
}
