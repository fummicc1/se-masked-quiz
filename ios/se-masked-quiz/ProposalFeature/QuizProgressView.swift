import SwiftUI

/// クイズ進捗を表示する再利用可能なビュー
struct QuizProgressView: View {
  let progress: ProposalProgress
  /// 一覧行など高さを抑えたい場所向けに、バー+進捗率+回答数を1行へ集約する
  var compact: Bool = false

  var body: some View {
    if compact {
      HStack(spacing: AppSpacing.sm) {
        ProgressView(value: progress.progressRate)
          .tint(progressColor)

        Text("\(Int(progress.progressPercentage))%")
          .font(AppFont.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()

        Text("\(progress.answeredCount)/\(progress.totalCount)問")
          .font(AppFont.caption2)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    } else {
      detail
    }
  }

  private var detail: some View {
    VStack(alignment: .leading, spacing: 4) {
      // プログレスインジケータと進捗率
      HStack(spacing: 8) {
        ProgressView(value: progress.progressRate)
          .tint(progressColor)

        Text("\(Int(progress.progressPercentage))%")
          .font(AppFont.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }

      // 詳細情報（回答数、正解率）
      HStack(spacing: 12) {
        Text("\(progress.answeredCount)/\(progress.totalCount)問")
          .font(AppFont.caption2)
          .foregroundStyle(.secondary)

        if progress.answeredCount > 0 {
          Text("正解率: \(Int(progress.accuracyPercentage))%")
            .font(AppFont.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  /// 進捗状態に応じた色
  private var progressColor: Color {
    switch progress.status {
    case .notStarted:
      return SemanticColor.neutral
    case .inProgress:
      return SemanticColor.inProgress
    case .completed:
      return SemanticColor.correct
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
