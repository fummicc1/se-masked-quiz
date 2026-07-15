//
//  StatTile.swift
//  se-masked-quiz
//
//  StreakStatsScreen内で個別実装されていた統計タイルを独立View化したもの。
//

import SwiftUI

struct StatTile: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: icon)
        .font(AppFont.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(AppFont.title)
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.large))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(title): \(value)")
  }
}

#Preview {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
    StatTile(title: "現在のストリーク", value: "5日", icon: "flame.fill", color: SemanticColor.streak.light)
    StatTile(title: "正答率", value: "82%", icon: "checkmark.seal.fill", color: SemanticColor.correct)
  }
  .padding()
}
