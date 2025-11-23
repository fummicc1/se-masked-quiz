import SwiftUI

/// クイズ進捗を表示する再利用可能なビュー
struct QuizProgressView: View {
  let progress: ProposalProgress

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // プログレスインジケータと進捗率
      HStack(spacing: 8) {
        ProgressView(value: progress.progressRate)
          .tint(progressColor)

        Text("\(Int(progress.progressPercentage))%")
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }

      // 詳細情報（回答数、正解率）
      HStack(spacing: 12) {
        Text("\(progress.answeredCount)/\(progress.totalCount)問")
          .font(.caption2)
          .foregroundStyle(.secondary)

        if progress.answeredCount > 0 {
          Text("正解率: \(Int(progress.accuracyPercentage))%")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  /// 進捗状態に応じた色
  private var progressColor: Color {
    switch progress.status {
    case .notStarted:
      return .gray
    case .inProgress:
      return .blue
    case .completed:
      return .green
    }
  }
}

// MARK: - Previews

#Preview("未開始") {
  QuizProgressView(
    progress: ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 0,
      totalCount: 10,
      correctCount: 0
    )
  )
  .padding()
}

#Preview("進行中") {
  QuizProgressView(
    progress: ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )
  )
  .padding()
}

#Preview("完了") {
  QuizProgressView(
    progress: ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 10,
      totalCount: 10,
      correctCount: 8
    )
  )
  .padding()
}
