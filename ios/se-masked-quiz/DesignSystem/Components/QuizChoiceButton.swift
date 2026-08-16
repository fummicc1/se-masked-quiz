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
        // 正誤確定時にアイコンを挿入するとタイトルが再フローするため、枠は常に確保する
        Image(systemName: iconName)
          .foregroundStyle(iconColor)
          .opacity(showsIcon ? 1 : 0)
          .contentTransition(.symbolEffect(.replace))
      }
      .padding()
      .background(backgroundColor)
      .foregroundStyle(isAnswered ? Color.primary : Color.white)
      .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
      .animation(.easeInOut(duration: 0.2), value: state)
    }
    // disabled にすると結果表示まで減光され、どれが正解か分かりにくくなる
    .allowsHitTesting(!isAnswered)
    .accessibilityLabel(title)
    .accessibilityValue(accessibilityValue)
    .accessibilityRemoveTraits(isAnswered ? .isButton : [])
  }

  private var showsIcon: Bool {
    state == .correct || state == .incorrectSelected
  }

  private var iconName: String {
    switch state {
    case .correct: return "checkmark.circle.fill"
    case .incorrectSelected: return "xmark.circle.fill"
    case .unanswered, .incorrectOther: return "circle"
    }
  }

  private var iconColor: Color {
    state == .correct ? SemanticColor.correct : SemanticColor.incorrect
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
