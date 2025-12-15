import Foundation

/// 提案のクイズ進捗情報を表すモデル
struct ProposalProgress: Equatable {
  let proposalId: String
  let answeredCount: Int  // 回答数
  let totalCount: Int  // 全問題数
  let correctCount: Int  // 正解数

  /// SRS（間隔反復学習）統計情報
  /// Issue #12で追加: SRS機能が有効な場合のみ設定される
  let reviewStats: ReviewStats?

  // MARK: - Initialization

  init(
    proposalId: String,
    answeredCount: Int,
    totalCount: Int,
    correctCount: Int,
    reviewStats: ReviewStats? = nil
  ) {
    self.proposalId = proposalId
    self.answeredCount = answeredCount
    self.totalCount = totalCount
    self.correctCount = correctCount
    self.reviewStats = reviewStats
  }

  // MARK: - Computed Properties

  /// 進捗率（0.0〜1.0）
  var progressRate: Double {
    guard totalCount > 0 else { return 0.0 }
    return Double(answeredCount) / Double(totalCount)
  }

  /// 進捗率（パーセンテージ）
  var progressPercentage: Double {
    progressRate * 100
  }

  /// 正解率（パーセンテージ）
  var accuracyPercentage: Double {
    guard answeredCount > 0 else { return 0.0 }
    return Double(correctCount) / Double(answeredCount) * 100
  }

  /// 進捗状態
  var status: ProgressStatus {
    if answeredCount == 0 {
      return .notStarted
    } else if answeredCount == totalCount {
      return .completed
    } else {
      return .inProgress
    }
  }

  /// SRS習熟度スコア（0-100）
  /// reviewStatsが存在する場合のみ有効
  var masteryScore: Double? {
    reviewStats?.masteryScore
  }

  /// 期限切れ復習の有無
  var hasOverdueReviews: Bool {
    guard let stats = reviewStats else { return false }
    return stats.overdueCount > 0
  }

  /// 今日期限の復習の有無
  var hasDueTodayReviews: Bool {
    guard let stats = reviewStats else { return false }
    return stats.dueTodayCount > 0
  }
}

/// 進捗状態を表す列挙型
enum ProgressStatus {
  case notStarted  // 未開始
  case inProgress  // 進行中
  case completed  // 完了
}
