//
//  ReviewSchedule.swift
//  se-masked-quiz
//
//  Created for Issue #12: SRS (Spaced Repetition System)
//

import Foundation

/// 間隔反復学習（SRS）のスケジュール情報
/// SM-2アルゴリズムに基づいた復習管理
struct ReviewSchedule: Codable, Identifiable, Equatable {
  /// 一意識別子
  var id: String { quizId }

  /// クイズID（Quiz.id）
  let quizId: String

  /// 提案ID（Quiz.proposalId）
  let proposalId: String

  /// 次回復習日時
  var nextReviewDate: Date

  /// 現在の復習間隔（秒）
  var interval: TimeInterval

  /// 難易度係数（デフォルト2.5、範囲: 1.3〜）
  var easeFactor: Double

  /// 連続正解回数
  var consecutiveCorrect: Int

  /// 総復習回数
  var reviewCount: Int

  /// 最終復習日時
  var lastReviewDate: Date?

  /// 作成日時
  let createdAt: Date

  /// 更新日時
  var updatedAt: Date

  // MARK: - Initialization

  init(
    quizId: String,
    proposalId: String,
    nextReviewDate: Date = Date().addingTimeInterval(86400), // デフォルト1日後
    interval: TimeInterval = 86400, // 1日
    easeFactor: Double = 2.5,
    consecutiveCorrect: Int = 0,
    reviewCount: Int = 0,
    lastReviewDate: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.quizId = quizId
    self.proposalId = proposalId
    self.nextReviewDate = nextReviewDate
    self.interval = interval
    self.easeFactor = easeFactor
    self.consecutiveCorrect = consecutiveCorrect
    self.reviewCount = reviewCount
    self.lastReviewDate = lastReviewDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  // MARK: - SM-2 Algorithm

  /// SM-2アルゴリズムに基づいて復習スケジュールを更新
  /// - Parameter quality: 回答品質（0-5: 0=完全忘却、3=正解、5=完璧な記憶）
  /// - Returns: 更新されたスケジュール
  func updatedAfterReview(quality: Int) -> ReviewSchedule {
    guard (0...5).contains(quality) else {
      return self // 無効な品質値の場合は変更なし
    }

    var updated = self
    updated.lastReviewDate = Date()
    updated.reviewCount += 1
    updated.updatedAt = Date()

    // quality >= 3 の場合は正解とみなす
    if quality >= 3 {
      // 間隔の更新
      if updated.consecutiveCorrect == 0 {
        updated.interval = 86400 // 1日（24時間）
      } else if updated.consecutiveCorrect == 1 {
        updated.interval = 259200 // 3日（72時間）
      } else {
        updated.interval *= updated.easeFactor
      }
      updated.consecutiveCorrect += 1
    } else {
      // 不正解の場合はリセット
      updated.consecutiveCorrect = 0
      updated.interval = 86400 // 1日にリセット
    }

    // 難易度係数の更新（SM-2アルゴリズム）
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    let delta = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
    updated.easeFactor = max(1.3, updated.easeFactor + delta)

    // 次回復習日時の計算
    updated.nextReviewDate = Date().addingTimeInterval(updated.interval)

    return updated
  }

  // MARK: - Computed Properties

  /// 復習が期限切れかどうか
  var isOverdue: Bool {
    nextReviewDate < Date()
  }

  /// 今日が復習日かどうか
  var isDueToday: Bool {
    Calendar.current.isDateInToday(nextReviewDate)
  }

  /// 習熟度レベル（連続正解回数に基づく）
  var masteryLevel: MasteryLevel {
    switch consecutiveCorrect {
    case 0:
      return .learning
    case 1...2:
      return .reviewing
    case 3...5:
      return .familiar
    default:
      return .mastered
    }
  }
}

// MARK: - Supporting Types

/// 習熟度レベル
enum MasteryLevel: String, Codable {
  case learning = "学習中"
  case reviewing = "復習中"
  case familiar = "習得済み"
  case mastered = "完全習得"

  var color: String {
    switch self {
    case .learning:
      return "red"
    case .reviewing:
      return "orange"
    case .familiar:
      return "blue"
    case .mastered:
      return "green"
    }
  }
}

/// 日次復習キュー
struct DailyReviewQueue: Codable, Equatable {
  /// 復習対象のクイズID（期限切れ + 今日期限）
  let reviewItems: [String]

  /// 新規学習のクイズID
  let newItems: [String]

  /// 合計数
  var totalCount: Int {
    reviewItems.count + newItems.count
  }

  /// 復習/新規の比率
  var reviewRatio: Double {
    guard totalCount > 0 else { return 0 }
    return Double(reviewItems.count) / Double(totalCount)
  }

  init(reviewItems: [String] = [], newItems: [String] = []) {
    self.reviewItems = reviewItems
    self.newItems = newItems
  }
}

/// 復習統計情報
struct ReviewStats: Codable, Equatable {
  /// 提案ID
  let proposalId: String

  /// 総復習回数
  let totalReviews: Int

  /// 期限切れクイズ数
  let overdueCount: Int

  /// 今日期限のクイズ数
  let dueTodayCount: Int

  /// 平均難易度係数
  let averageEaseFactor: Double

  /// 習熟度レベル別カウント
  let masteryLevelCounts: [MasteryLevel: Int]

  /// 次回復習日（最も近い日付）
  let nextReviewDate: Date?

  /// 総合習熟度スコア（0-100）
  var masteryScore: Double {
    guard totalReviews > 0 else { return 0 }

    let learningCount = masteryLevelCounts[.learning] ?? 0
    let reviewingCount = masteryLevelCounts[.reviewing] ?? 0
    let familiarCount = masteryLevelCounts[.familiar] ?? 0
    let masteredCount = masteryLevelCounts[.mastered] ?? 0

    let total = learningCount + reviewingCount + familiarCount + masteredCount
    guard total > 0 else { return 0 }

    let weightedSum = Double(learningCount) * 0
      + Double(reviewingCount) * 33
      + Double(familiarCount) * 66
      + Double(masteredCount) * 100

    return weightedSum / Double(total)
  }
}
