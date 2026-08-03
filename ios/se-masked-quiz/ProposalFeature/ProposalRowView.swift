//
//  ProposalRowView.swift
//  se-masked-quiz
//
//  提案一覧・お気に入り一覧で共用する行。
//  ID/ステータスをバッジで示し、タイトル+コンパクト進捗の3行以内に収めて情報密度を上げる。
//  authors/reviewManagerは提案本文側に記載があるため行には出さない。
//

import SwiftUI

struct ProposalRowView: View {
  let proposal: SwiftEvolution
  var progress: ProposalProgress?

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      HStack(spacing: AppSpacing.sm) {
        AppBadge(text: proposal.displayId, style: .subtle(.accentColor))
        if let status = parsedStatus {
          AppBadge(text: status.label, style: .subtle(status.color))
        }
      }
      MarkdownText(proposal.title)
        .font(AppFont.headline)
        .lineLimit(2)
      if let progress {
        QuizProgressView(progress: progress, compact: true)
      }
    }
  }

  /// status未設定やパース結果が空ラベルの場合はバッジを出さない
  private var parsedStatus: ProposalStatus? {
    guard proposal.status != nil else { return nil }
    let parsed = ProposalStatus.parse(proposal.status)
    return parsed.label.isEmpty ? nil : parsed
  }
}

// MARK: - Previews

private func previewProposal(status: String?, progress: Bool = false) -> SwiftEvolution {
  SwiftEvolution(
    id: "1",
    proposalId: "0401",
    title: "Remove Actor Isolation Inference caused by Property Wrappers",
    reviewManager: nil,
    status: status,
    authors: "[Author](https://example.com)",
    content: ""
  )
}

#Preview("Implemented + 進捗あり") {
  List {
    ProposalRowView(
      proposal: previewProposal(status: "**Implemented (Swift 5.9)**"),
      progress: ProposalProgress(
        proposalId: "0401", answeredCount: 5, totalCount: 10, correctCount: 4)
    )
  }
}

#Preview("各ステータス") {
  List {
    ProposalRowView(proposal: previewProposal(status: "**Implemented (Swift 5.9)**"))
    ProposalRowView(proposal: previewProposal(status: "**Accepted**"))
    ProposalRowView(proposal: previewProposal(status: "**Active review (March 1...11, 2024)**"))
    ProposalRowView(proposal: previewProposal(status: "**Rejected**"))
    ProposalRowView(proposal: previewProposal(status: "**Returned for revision**"))
    ProposalRowView(proposal: previewProposal(status: "**Withdrawn**"))
    ProposalRowView(proposal: previewProposal(status: nil))
  }
}
