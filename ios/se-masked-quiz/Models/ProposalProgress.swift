import Foundation

/// 提案のクイズ進捗情報を表すモデル
struct ProposalProgress: Equatable {
  let proposalId: String
  let answeredCount: Int  // 回答数
  let totalCount: Int  // 全問題数
  let correctCount: Int  // 正解数

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
}

/// 進捗状態を表す列挙型
enum ProgressStatus {
  case notStarted  // 未開始
  case inProgress  // 進行中
  case completed  // 完了
}
