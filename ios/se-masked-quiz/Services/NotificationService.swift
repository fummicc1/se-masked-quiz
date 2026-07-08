//
//  NotificationService.swift
//  se-masked-quiz
//
//  習慣ループの「トリガー」を担うローカル通知（学習リマインダー）の管理。
//  サーバ・APNs 不要。毎日指定時刻に繰り返す UNCalendarNotificationTrigger を使う。
//

import Foundation
import UserNotifications

// MARK: - Preferences

/// 学習リマインダーの設定（UserDefaults キーと既定値）
enum ReminderPreferences {
  static let enabledKey = "reminder_enabled"
  static let hourKey = "reminder_hour"
  static let minuteKey = "reminder_minute"

  static let defaultHour = 20
  static let defaultMinute = 0

  static var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: enabledKey)
  }

  static var hour: Int {
    UserDefaults.standard.object(forKey: hourKey) == nil
      ? defaultHour : UserDefaults.standard.integer(forKey: hourKey)
  }

  static var minute: Int {
    UserDefaults.standard.object(forKey: minuteKey) == nil
      ? defaultMinute : UserDefaults.standard.integer(forKey: minuteKey)
  }
}

// MARK: - Service

struct NotificationService: Sendable {
  static let dailyReminderIdentifier = "daily_study_reminder"

  /// 通知の許諾を要求し、許可されたかを返す
  func requestAuthorization() async -> Bool {
    do {
      return try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      return false
    }
  }

  /// 現在の許諾状態
  func authorizationStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  /// 毎日指定時刻のリマインダーを登録（既存があれば置き換え）。
  /// 本文には現在のストリーク日数を埋め込み、継続意欲（loss aversion）を刺激する。
  /// `track`/`proposalId` を渡すと、通知タップで該当のデイリーチャレンジへ直接遷移できる
  /// DeepLink情報を `userInfo` に埋め込む（取得できなければ従来どおり付与しない）。
  func scheduleDailyReminder(
    hour: Int,
    minute: Int,
    currentStreak: Int,
    track: ProposalTrack? = nil,
    proposalId: String? = nil
  ) async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])

    let content = UNMutableNotificationContent()
    content.title = "今日のクイズに挑戦しよう 🧩"
    if currentStreak > 0 {
      content.body = "ストリーク \(currentStreak)日継続中。今日も解いて記録を伸ばそう！"
    } else {
      content.body = "1日1問でも続ければ力になります。今日のチャレンジを始めましょう。"
    }
    content.sound = .default
    if let track, let proposalId {
      content.userInfo = [
        DeepLinkRouter.UserInfoKey.track: track.rawValue,
        DeepLinkRouter.UserInfoKey.proposalId: proposalId,
      ]
    }

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

    let request = UNNotificationRequest(
      identifier: Self.dailyReminderIdentifier,
      content: content,
      trigger: trigger
    )
    try? await center.add(request)
  }

  /// リマインダーを解除
  func cancelDailyReminder() {
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [Self.dailyReminderIdentifier])
  }
}
