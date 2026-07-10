//
//  QuizAccuracyAggregator.swift
//  se-masked-quiz
//
//  SE/ST 両トラックのスコアを横断して正答率を集計する純粋ロジック。
//  サーバ不要・オフライン可・テスト容易（DailyChallengeService と同じ設計思想）。
//

import Foundation

struct QuizAccuracyAggregator: Sendable {
  struct Result: Sendable, Equatable {
    let totalAnswered: Int
    let totalCorrect: Int

    /// 未回答なら nil、それ以外は 0〜100 の正答率
    var accuracyPercentage: Double? {
      guard totalAnswered > 0 else { return nil }
      return Double(totalCorrect) / Double(totalAnswered) * 100
    }
  }

  /// 複数トラックの `getAllScores()` 結果を横断集計する
  func aggregate(scoresByTrack: [[String: ProposalScore]]) -> Result {
    var totalAnswered = 0
    var totalCorrect = 0
    for scores in scoresByTrack {
      for score in scores.values {
        totalAnswered += score.totalCount
        totalCorrect += score.correctCount
      }
    }
    return Result(totalAnswered: totalAnswered, totalCorrect: totalCorrect)
  }
}
