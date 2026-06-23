//
//  StreakRepository.swift
//  se-masked-quiz
//
//  連続学習日数（ストリーク）の記録・判定を担うリポジトリ。
//  習慣ループの「投資」要素を担い、ローカル（UserDefaults）で完結する。
//

import Foundation
import SwiftUI

// MARK: - Models

/// 連続学習日数（ストリーク）の状態
struct StreakRecord: Codable, Equatable, Sendable {
  var currentStreak: Int
  var longestStreak: Int
  /// 最後に学習した日（その日の startOfDay）
  var lastActiveDay: Date?
  var totalActiveDays: Int

  static let empty = StreakRecord(
    currentStreak: 0, longestStreak: 0, lastActiveDay: nil, totalActiveDays: 0)

  /// 指定日に学習済みか
  func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
    guard let last = lastActiveDay else { return false }
    return calendar.isDate(last, inSameDayAs: date)
  }

  /// ストリークが途切れ間近か（昨日まで継続中だが、今日はまだ未学習）
  func isAtRisk(on date: Date, calendar: Calendar = .current) -> Bool {
    guard currentStreak > 0, let last = lastActiveDay else { return false }
    let today = calendar.startOfDay(for: date)
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return false }
    return calendar.isDate(last, inSameDayAs: yesterday)
  }
}

/// `recordActivity(on:)` の結果
struct StreakUpdateResult: Sendable {
  let record: StreakRecord
  /// 前日からの連続でストリークが伸びた
  let didIncrement: Bool
  /// 今日はじめての学習だった（同日2回目以降は false）
  let isFirstActivityToday: Bool
}

// MARK: - Repository Protocol

/// @mockable
protocol StreakRepository: Actor, Sendable {
  /// 指定日の学習を記録し、更新後の状態を返す
  func recordActivity(on date: Date) async -> StreakUpdateResult

  /// 現在のストリーク状態を取得
  func getStreak() async -> StreakRecord

  /// ストリークをリセット（デバッグ・テスト用）
  func reset() async
}

// MARK: - Repository Implementation

actor StreakRepositoryImpl: StreakRepository {
  private let userDefaults: UserDefaults
  private let calendar: Calendar

  private static let streakKey = "streak_record"

  init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
    self.userDefaults = userDefaults
    self.calendar = calendar
  }

  func recordActivity(on date: Date) async -> StreakUpdateResult {
    var record = loadRecord()
    let today = calendar.startOfDay(for: date)

    // すでに今日記録済みなら状態を変えない（同日の複数回回答に耐える）
    if let last = record.lastActiveDay, calendar.isDate(last, inSameDayAs: today) {
      return StreakUpdateResult(record: record, didIncrement: false, isFirstActivityToday: false)
    }

    var didIncrement = false
    if let last = record.lastActiveDay {
      let lastDay = calendar.startOfDay(for: last)
      let dayGap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
      if dayGap == 1 {
        record.currentStreak += 1
        didIncrement = true
      } else {
        // 1日以上空いた → ストリークは途切れて今日から再スタート
        record.currentStreak = 1
      }
    } else {
      record.currentStreak = 1
    }

    record.lastActiveDay = today
    record.totalActiveDays += 1
    record.longestStreak = max(record.longestStreak, record.currentStreak)
    saveRecord(record)

    return StreakUpdateResult(record: record, didIncrement: didIncrement, isFirstActivityToday: true)
  }

  func getStreak() async -> StreakRecord {
    loadRecord()
  }

  func reset() async {
    userDefaults.removeObject(forKey: Self.streakKey)
  }

  // MARK: - Private Helpers

  private func loadRecord() -> StreakRecord {
    guard let data = userDefaults.data(forKey: Self.streakKey),
      let record = try? JSONDecoder().decode(StreakRecord.self, from: data)
    else {
      return .empty
    }
    return record
  }

  private func saveRecord(_ record: StreakRecord) {
    if let encoded = try? JSONEncoder().encode(record) {
      userDefaults.set(encoded, forKey: Self.streakKey)
    }
  }
}

// MARK: - Environment

extension StreakRepositoryImpl: EnvironmentKey {
  static var defaultValue: any StreakRepository {
    StreakRepositoryImpl()
  }
}

extension EnvironmentValues {
  var streakRepository: any StreakRepository {
    get { self[StreakRepositoryImpl.self] }
    set { self[StreakRepositoryImpl.self] = newValue }
  }
}
