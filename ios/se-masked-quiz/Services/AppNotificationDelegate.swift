//
//  AppNotificationDelegate.swift
//  se-masked-quiz
//
//  通知タップを DeepLinkRouter に橋渡しする UNUserNotificationCenterDelegate 実装。
//  フォアグラウンド中も通知バナーを表示し、タップ時のみ遷移処理を行う。
//

import Foundation
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  private let router: DeepLinkRouter
  private let analytics: any AnalyticsService

  init(router: DeepLinkRouter, analytics: any AnalyticsService) {
    self.router = router
    self.analytics = analytics
  }

  /// フォアグラウンド中に通知が届いた場合も、バックグラウンド同様にバナー・サウンドを表示する
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound, .badge]
  }

  /// 通知タップ時に呼ばれる。userInfo を DeepLinkRouter に渡し、開封を計測する。
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo
    await MainActor.run {
      router.handle(userInfo: userInfo)
      analytics.track(.notificationOpened)
    }
  }
}
