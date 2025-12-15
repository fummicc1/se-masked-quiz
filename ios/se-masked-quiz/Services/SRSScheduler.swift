//
//  SRSScheduler.swift
//  se-masked-quiz
//
//  Created for Issue #12: SRS (Spaced Repetition System)
//  Implements SM-2 algorithm for spaced repetition scheduling
//

import Foundation

// MARK: - SRSScheduler Protocol

/// 間隔反復学習（SRS）のスケジュール管理サービス
protocol SRSScheduler: Actor {
  /// 復習後にスケジュールを更新
  /// - Parameters:
  ///   - quizId: クイズID
  ///   - proposalId: 提案ID
  ///   - quality: 回答品質（0-5: 0=完全忘却、3=正解、5=完璧な記憶）
  func updateScheduleAfterReview(quizId: String, proposalId: String, quality: Int) async throws

  /// 指定日時に期限の復習項目を取得
  /// - Parameter date: 基準日時（デフォルト: 現在時刻）
  /// - Returns: 期限切れのクイズIDリスト
  func getDueReviews(for date: Date) async throws -> [String]

  /// 日次復習キューを生成（80%復習 + 20%新規）
  /// - Parameter proposalId: 提案ID（nilの場合は全提案）
  /// - Returns: 復習キュー
  func generateDailyQueue(for proposalId: String?) async throws -> DailyReviewQueue

  /// 特定のクイズのスケジュールを取得
  /// - Parameter quizId: クイズID
  /// - Returns: スケジュール（存在しない場合はnil）
  func getSchedule(for quizId: String) async throws -> ReviewSchedule?

  /// 提案の復習統計を取得
  /// - Parameter proposalId: 提案ID
  /// - Returns: 復習統計
  func getReviewStats(for proposalId: String) async throws -> ReviewStats

  /// すべてのスケジュールを取得
  /// - Returns: クイズID -> スケジュールのマップ
  func getAllSchedules() async throws -> [String: ReviewSchedule]

  /// 特定提案のスケジュールを削除（リセット機能用）
  /// - Parameter proposalId: 提案ID
  func deleteSchedules(for proposalId: String) async throws
}

// MARK: - SRSScheduler Implementation

actor SRSSchedulerImpl: SRSScheduler {
  private let userDefaults: UserDefaults
  private static let schedulesKey = "srs_schedules"

  // MARK: - Initialization

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  // MARK: - Public Methods

  func updateScheduleAfterReview(quizId: String, proposalId: String, quality: Int) async throws {
    guard (0...5).contains(quality) else {
      throw SRSError.invalidQuality(quality)
    }

    var schedules = try await getAllSchedules()

    // 既存のスケジュールを取得、なければ新規作成
    let currentSchedule = schedules[quizId] ?? ReviewSchedule(
      quizId: quizId,
      proposalId: proposalId
    )

    // SM-2アルゴリズムで更新
    let updatedSchedule = currentSchedule.updatedAfterReview(quality: quality)
    schedules[quizId] = updatedSchedule

    // 保存
    try await saveSchedules(schedules)
  }

  func getDueReviews(for date: Date = Date()) async throws -> [String] {
    let schedules = try await getAllSchedules()
    return schedules.values
      .filter { $0.nextReviewDate <= date }
      .map { $0.quizId }
  }

  func generateDailyQueue(for proposalId: String? = nil) async throws -> DailyReviewQueue {
    let schedules = try await getAllSchedules()

    // 提案でフィルタリング（指定された場合）
    let filteredSchedules = if let proposalId = proposalId {
      schedules.values.filter { $0.proposalId == proposalId }
    } else {
      Array(schedules.values)
    }

    let now = Date()

    // 期限切れと今日期限の復習項目
    let overdueItems = filteredSchedules
      .filter { $0.nextReviewDate < now }
      .sorted { $0.nextReviewDate < $1.nextReviewDate } // 古い順
      .map { $0.quizId }

    let dueTodayItems = filteredSchedules
      .filter { Calendar.current.isDateInToday($0.nextReviewDate) && $0.nextReviewDate >= now }
      .sorted { $0.nextReviewDate < $1.nextReviewDate }
      .map { $0.quizId }

    let reviewItems = overdueItems + dueTodayItems

    // 新規項目の数を計算（80:20の比率を目指す）
    // reviewItems が N 個なら、新規は N/4 個（80:20の比率）
    let newItemsCount = max(1, reviewItems.count / 4)

    // 新規項目はスケジュールに存在しないクイズから選択
    // ここでは空の配列を返し、実際の新規クイズの選択は
    // QuizViewModelで行う（全クイズからスケジュールに存在しないものを選択）
    let newItems: [String] = []

    return DailyReviewQueue(
      reviewItems: reviewItems,
      newItems: Array(newItems.prefix(newItemsCount))
    )
  }

  func getSchedule(for quizId: String) async throws -> ReviewSchedule? {
    let schedules = try await getAllSchedules()
    return schedules[quizId]
  }

  func getReviewStats(for proposalId: String) async throws -> ReviewStats {
    let schedules = try await getAllSchedules()
    let proposalSchedules = schedules.values.filter { $0.proposalId == proposalId }

    guard !proposalSchedules.isEmpty else {
      return ReviewStats(
        proposalId: proposalId,
        totalReviews: 0,
        overdueCount: 0,
        dueTodayCount: 0,
        averageEaseFactor: 2.5,
        masteryLevelCounts: [:],
        nextReviewDate: nil
      )
    }

    let now = Date()
    let overdueCount = proposalSchedules.filter { $0.nextReviewDate < now }.count
    let dueTodayCount = proposalSchedules.filter {
      Calendar.current.isDateInToday($0.nextReviewDate) && $0.nextReviewDate >= now
    }.count

    let totalReviews = proposalSchedules.reduce(0) { $0 + $1.reviewCount }

    let averageEaseFactor = proposalSchedules.reduce(0.0) { $0 + $1.easeFactor }
      / Double(proposalSchedules.count)

    // 習熟度レベル別カウント
    var masteryLevelCounts: [MasteryLevel: Int] = [:]
    for schedule in proposalSchedules {
      let level = schedule.masteryLevel
      masteryLevelCounts[level, default: 0] += 1
    }

    // 次回復習日（最も近い未来の日付）
    let futureReviews = proposalSchedules
      .map { $0.nextReviewDate }
      .filter { $0 >= now }
      .sorted()
    let nextReviewDate = futureReviews.first

    return ReviewStats(
      proposalId: proposalId,
      totalReviews: totalReviews,
      overdueCount: overdueCount,
      dueTodayCount: dueTodayCount,
      averageEaseFactor: averageEaseFactor,
      masteryLevelCounts: masteryLevelCounts,
      nextReviewDate: nextReviewDate
    )
  }

  func getAllSchedules() async throws -> [String: ReviewSchedule] {
    guard let data = userDefaults.data(forKey: Self.schedulesKey) else {
      return [:]
    }

    do {
      let schedules = try JSONDecoder().decode([String: ReviewSchedule].self, from: data)
      return schedules
    } catch {
      throw SRSError.decodingError(error)
    }
  }

  func deleteSchedules(for proposalId: String) async throws {
    var schedules = try await getAllSchedules()
    schedules = schedules.filter { $0.value.proposalId != proposalId }
    try await saveSchedules(schedules)
  }

  // MARK: - Private Methods

  private func saveSchedules(_ schedules: [String: ReviewSchedule]) async throws {
    do {
      let data = try JSONEncoder().encode(schedules)
      userDefaults.set(data, forKey: Self.schedulesKey)
    } catch {
      throw SRSError.encodingError(error)
    }
  }
}

// MARK: - Errors

enum SRSError: Error, LocalizedError {
  case invalidQuality(Int)
  case scheduleNotFound(quizId: String)
  case encodingError(Error)
  case decodingError(Error)

  var errorDescription: String? {
    switch self {
    case .invalidQuality(let quality):
      return "Invalid quality value: \(quality). Must be between 0 and 5."
    case .scheduleNotFound(let quizId):
      return "Schedule not found for quiz ID: \(quizId)"
    case .encodingError(let error):
      return "Failed to encode schedules: \(error.localizedDescription)"
    case .decodingError(let error):
      return "Failed to decode schedules: \(error.localizedDescription)"
    }
  }
}

// MARK: - Environment

import SwiftUI

extension SRSSchedulerImpl {
  static var defaultValue: any SRSScheduler {
    SRSSchedulerImpl()
  }
}

private struct SRSSchedulerKey: EnvironmentKey {
  static var defaultValue: any SRSScheduler {
    SRSSchedulerImpl.defaultValue
  }
}

extension EnvironmentValues {
  var srsScheduler: any SRSScheduler {
    get { self[SRSSchedulerKey.self] }
    set { self[SRSSchedulerKey.self] = newValue }
  }
}
