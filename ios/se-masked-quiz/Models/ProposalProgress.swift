import Foundation

struct ProposalProgress: Equatable {
  let proposalId: String
  let answeredCount: Int
  let totalCount: Int
  let correctCount: Int

  // MARK: - Computed Properties

  /// 進捗率（0.0〜1.0）
  var progressRate: Double {
    guard totalCount > 0 else { return 0.0 }
    return Double(answeredCount) / Double(totalCount)
  }

  var progressPercentage: Double {
    progressRate * 100
  }

  var accuracyPercentage: Double {
    guard answeredCount > 0 else { return 0.0 }
    return Double(correctCount) / Double(answeredCount) * 100
  }

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

enum ProgressStatus {
  case notStarted
  case inProgress
  case completed
}
