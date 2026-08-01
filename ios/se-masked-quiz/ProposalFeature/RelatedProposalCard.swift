//
//  RelatedProposalCard.swift
//  se-masked-quiz
//
//  クイズ画面上部の「先に読むと理解しやすい提案」を示すミニカード。
//  極小チップだと視認性・タップ性が低かったため、ID+タイトル2行のカード型にする。
//  スクロールコンテンツ内のためLiquid Glassは使わず不透明系の塗りにする。
//

import SwiftUI

struct RelatedProposalCard: View {
  let proposal: SwiftEvolution

  /// Dynamic Typeに追従してカード幅も広げ、タイトル2行の可読性を保つ
  @ScaledMetric(relativeTo: .caption) private var cardWidth: CGFloat = 180

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
      Text(proposal.displayId)
        .font(AppFont.caption.bold())
        .foregroundStyle(SemanticColor.accent)
      MarkdownText(proposal.title)
        .font(AppFont.caption)
        .foregroundStyle(.primary)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
    .padding(AppSpacing.sm)
    .frame(width: cardWidth, alignment: .topLeading)
    .frame(minHeight: 44)
    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: AppRadius.medium))
    .contentShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  ScrollView(.horizontal) {
    HStack(spacing: AppSpacing.sm) {
      RelatedProposalCard(
        proposal: SwiftEvolution(
          id: "1",
          proposalId: "0296",
          title: "Async/await",
          reviewManager: nil,
          status: "**Implemented (Swift 5.5)**",
          authors: "",
          content: ""
        )
      )
      RelatedProposalCard(
        proposal: SwiftEvolution(
          id: "2",
          proposalId: "0306",
          title: "Actors with a very long title that wraps to two lines",
          reviewManager: nil,
          status: "**Implemented (Swift 5.5)**",
          authors: "",
          content: ""
        )
      )
    }
    .padding()
  }
}
