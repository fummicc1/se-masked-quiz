//
//  ReviewNotificationService.swift
//  se-masked-quiz
//
//  Created for Issue #12: SRS Daily Review Notifications
//

import Foundation
import UserNotifications

// MARK: - ReviewNotificationService Protocol

/// 復習通知サービス
protocol ReviewNotificationService: Actor {
  /// 通知権限を要求
  /// - Returns: 許可されたかどうか
  func requestAuthorization() async throws -> Bool

  /// 日次復習通知をスケジュール
  /// - Parameter time: 通知時刻（デフォルト: 朝9時）
  func scheduleDailyReviewNotification(at time: DateComponents) async throws

  /// すべての通知をキャンセル
  func cancelAllNotifications() async

  /// 現在の通知設定を取得
  /// - Returns: 通知が許可されているかどうか
  func getAuthorizationStatus() async -> UNAuthorizationStatus
}

// MARK: - ReviewNotificationService Implementation

actor ReviewNotificationServiceImpl: ReviewNotificationService {
  private let srsScheduler: any SRSScheduler
  private let notificationCenter: UNUserNotificationCenter

  private static let dailyReviewIdentifier = "daily_review_notification"

  // MARK: - Initialization

  init(
    srsScheduler: any SRSScheduler,
    notificationCenter: UNUserNotificationCenter = .current()
  ) {
    self.srsScheduler = srsScheduler
    self.notificationCenter = notificationCenter
  }

  // MARK: - Public Methods

  func requestAuthorization() async throws -> Bool {
    let options: UNAuthorizationOptions = [.alert, .badge, .sound]

    return try await notificationCenter.requestAuthorization(options: options)
  }

  func scheduleDailyReviewNotification(at time: DateComponents = DateComponents(hour: 9, minute: 0)) async throws {
    // 既存の通知をキャンセル
    await cancelAllNotifications()

    // 通知権限を確認
    let status = await getAuthorizationStatus()
    guard status == .authorized else {
      throw NotificationError.notAuthorized
    }

    // 期限切れの復習数を取得
    let dueReviews = try await srsScheduler.getDueReviews(for: Date())

    // 期限切れがない場合は通知をスケジュールしない
    guard !dueReviews.isEmpty else {
      return
    }

    // 通知コンテンツを作成
    let content = UNMutableNotificationContent()
    content.title = "復習の時間です"
    content.body = "\(dueReviews.count)問の復習が期限になっています。今日も学習を続けましょう！"
    content.sound = .default
    content.badge = NSNumber(value: dueReviews.count)

    // カテゴリとアクションを設定
    content.categoryIdentifier = "REVIEW_REMINDER"

    // 通知トリガーを作成（毎日指定時刻）
    var triggerDate = time
    triggerDate.calendar = Calendar.current

    let trigger = UNCalendarNotificationTrigger(
      dateMatching: triggerDate,
      repeats: true
    )

    // 通知リクエストを作成
    let request = UNNotificationRequest(
      identifier: Self.dailyReviewIdentifier,
      content: content,
      trigger: trigger
    )

    // 通知をスケジュール
    try await notificationCenter.add(request)
  }

  func cancelAllNotifications() async {
    notificationCenter.removeAllPendingNotificationRequests()
    notificationCenter.removeAllDeliveredNotifications()
  }

  func getAuthorizationStatus() async -> UNAuthorizationStatus {
    let settings = await notificationCenter.notificationSettings()
    return settings.authorizationStatus
  }

  // MARK: - Helper Methods

  /// 通知カテゴリとアクションを登録
  func registerNotificationCategories() {
    let reviewAction = UNNotificationAction(
      identifier: "REVIEW_ACTION",
      title: "今すぐ復習",
      options: .foreground
    )

    let snoozeAction = UNNotificationAction(
      identifier: "SNOOZE_ACTION",
      title: "後で",
      options: []
    )

    let category = UNNotificationCategory(
      identifier: "REVIEW_REMINDER",
      actions: [reviewAction, snoozeAction],
      intentIdentifiers: [],
      options: []
    )

    notificationCenter.setNotificationCategories([category])
  }
}

// MARK: - Errors

enum NotificationError: Error, LocalizedError {
  case notAuthorized
  case schedulingFailed(Error)

  var errorDescription: String? {
    switch self {
    case .notAuthorized:
      return "通知の許可が必要です。設定アプリで通知を有効にしてください。"
    case .schedulingFailed(let error):
      return "通知のスケジュールに失敗しました: \(error.localizedDescription)"
    }
  }
}

// MARK: - Environment

import SwiftUI

extension ReviewNotificationServiceImpl {
  static var defaultValue: any ReviewNotificationService {
    ReviewNotificationServiceImpl(
      srsScheduler: SRSSchedulerImpl.defaultValue
    )
  }
}

private struct ReviewNotificationServiceKey: EnvironmentKey {
  static var defaultValue: any ReviewNotificationService {
    ReviewNotificationServiceImpl.defaultValue
  }
}

extension EnvironmentValues {
  var reviewNotificationService: any ReviewNotificationService {
    get { self[ReviewNotificationServiceKey.self] }
    set { self[ReviewNotificationServiceKey.self] = newValue }
  }
}
