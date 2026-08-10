//
//  AnalyticsService.swift
//  se-masked-quiz
//
//  リテンション施策の効果測定に使う軽量・プライバシー配慮型の計測レイヤー。
//  ConsoleAnalyticsService（os.Logger 出力）と RemoteAnalyticsService（自前サーバへの匿名送信）を
//  MultiplexAnalyticsService で合成して使う。差し替えは合成点（App / EnvironmentKey）の1箇所で済む。
//

import Foundation
import OSLog
import SwiftUI

// MARK: - Events

/// 計測イベント（最小セット）。ここから WAU・D1/D7/D30・デイリー完了率・
/// ストリーク分布・通知許諾率・通知経由起動率・学習記録タブ閲覧率を算出する。
struct AnalyticsEvent: Sendable, Equatable {
  let name: String
  /// 個人を特定しない最小限のパラメータのみを持たせる
  let parameters: [String: String]

  static let appOpen = AnalyticsEvent(name: "app_open", parameters: [:])
  static let notificationOpened = AnalyticsEvent(name: "notification_opened", parameters: [:])
  static let statsScreenViewed = AnalyticsEvent(name: "stats_screen_viewed", parameters: [:])

  static func quizStarted(proposalId: String) -> AnalyticsEvent {
    AnalyticsEvent(name: "quiz_started", parameters: ["proposalId": proposalId])
  }

  static func quizAnswered(isCorrect: Bool) -> AnalyticsEvent {
    AnalyticsEvent(name: "quiz_answered", parameters: ["isCorrect": String(isCorrect)])
  }

  static func dailyChallengeCompleted(streak: Int) -> AnalyticsEvent {
    AnalyticsEvent(name: "daily_challenge_completed", parameters: ["streak": String(streak)])
  }

  static func streakIncremented(days: Int) -> AnalyticsEvent {
    AnalyticsEvent(name: "streak_incremented", parameters: ["days": String(days)])
  }

  static func notificationPermission(granted: Bool) -> AnalyticsEvent {
    AnalyticsEvent(name: "notification_permission", parameters: ["granted": String(granted)])
  }

  static func reminderTimeSet(hour: Int, minute: Int) -> AnalyticsEvent {
    AnalyticsEvent(
      name: "reminder_time_set", parameters: ["hour": String(hour), "minute": String(minute)])
  }
}

// MARK: - Opt-out

/// 計測のオプトアウト設定（設定画面と共有）
enum AnalyticsSettings {
  static let optOutKey = "analytics_opt_out"

  static var isOptedOut: Bool {
    isOptedOut(in: .standard)
  }

  static func isOptedOut(in defaults: UserDefaults) -> Bool {
    defaults.bool(forKey: optOutKey)
  }
}

// MARK: - Service Protocol

/// @mockable
protocol AnalyticsService: Sendable {
  func track(_ event: AnalyticsEvent)
}

// MARK: - Console Implementation

/// os.Logger に出力するだけの実装。端末外へは一切送信しない。
struct ConsoleAnalyticsService: AnalyticsService {
  private let logger = Logger(subsystem: "dev.fummicc1.se-masked-quiz", category: "analytics")

  func track(_ event: AnalyticsEvent) {
    guard !AnalyticsSettings.isOptedOut else { return }

    let params = event.parameters
    if params.isEmpty {
      logger.log("📊 \(event.name, privacy: .public)")
    } else {
      let joined =
        params
        .map { "\($0.key)=\($0.value)" }
        .sorted()
        .joined(separator: " ")
      logger.log("📊 \(event.name, privacy: .public) \(joined, privacy: .public)")
    }
  }
}

// MARK: - Multiplex

/// 複数の AnalyticsService へ同一イベントを配信する合成実装。
struct MultiplexAnalyticsService: AnalyticsService {
  let services: [any AnalyticsService]

  func track(_ event: AnalyticsEvent) {
    for service in services {
      service.track(event)
    }
  }
}

// MARK: - Environment

extension ConsoleAnalyticsService: EnvironmentKey {
  static var defaultValue: any AnalyticsService {
    ConsoleAnalyticsService()
  }
}

extension EnvironmentValues {
  var analytics: any AnalyticsService {
    get { self[ConsoleAnalyticsService.self] }
    set { self[ConsoleAnalyticsService.self] = newValue }
  }
}
