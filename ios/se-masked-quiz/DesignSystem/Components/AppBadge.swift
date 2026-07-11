//
//  AppBadge.swift
//  se-masked-quiz
//
//  Q番号バッジ・難易度バッジ・関連提案カプセルで個別実装されていたピル型UIを統合したコンポーネント。
//

import SwiftUI

enum AppBadgeStyle {
  /// 塗りつぶし背景+白文字（Q番号バッジ等の強調表示向け）
  case solid(Color)
  /// 半透明背景+同色文字（難易度・関連提案等の控えめな表示向け）
  case subtle(Color)
}

struct AppBadge<Content: View>: View {
  let style: AppBadgeStyle
  let content: Content

  init(style: AppBadgeStyle, @ViewBuilder content: () -> Content) {
    self.style = style
    self.content = content()
  }

  var body: some View {
    content
      .padding(.horizontal, AppSpacing.sm)
      .padding(.vertical, 4)
      .foregroundStyle(foregroundColor)
      .background(backgroundColor, in: Capsule())
      .accessibilityElement(children: .combine)
  }

  private var foregroundColor: Color {
    switch style {
    case .solid: return .white
    case .subtle(let color): return color
    }
  }

  private var backgroundColor: Color {
    switch style {
    case .solid(let color): return color
    case .subtle(let color): return color.opacity(0.2)
    }
  }
}

extension AppBadge where Content == Text {
  init(text: String, style: AppBadgeStyle) {
    self.init(style: style) {
      Text(text)
        .font(AppFont.caption)
        .fontWeight(.bold)
    }
  }
}

#Preview("Q番号バッジ") {
  AppBadge(text: "Q1", style: .solid(SemanticColor.correct))
}

#Preview("難易度バッジ") {
  AppBadge(text: "intermediate", style: .subtle(SemanticColor.warning))
}

#Preview("関連提案カプセル") {
  AppBadge(style: .subtle(.secondary)) {
    HStack(spacing: 4) {
      Text("#0401").bold()
      Text("Some Proposal Title").lineLimit(1)
    }
    .font(.caption2)
  }
}
