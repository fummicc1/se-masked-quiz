//
//  GlassCardModifier.swift
//  se-masked-quiz
//

import SwiftUI

extension View {
  func glassCard(cornerRadius: CGFloat = AppRadius.large, tint: Color? = nil) -> some View {
    modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
  }
}

private struct GlassCardModifier: ViewModifier {
  let cornerRadius: CGFloat
  let tint: Color?

  func body(content: Content) -> some View {
    content
      .glassEffect(
        tint.map { Glass.regular.tint($0) } ?? .regular,
        in: .rect(cornerRadius: cornerRadius)
      )
  }
}

#Preview {
  VStack(spacing: 16) {
    Text("Tint無し")
      .padding()
      .glassCard()
    Text("Tint有り")
      .padding()
      .glassCard(tint: AppColor.brand)
  }
  .padding()
}
