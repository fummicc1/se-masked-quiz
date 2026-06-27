//
//  AnalyticsService.swift
//  se-masked-quiz
//
//  リテンション施策の効果測定に使う軽量・プライバシー配慮型の計測レイヤー。
//  Phase 1 は os.Logger に出力する実装。将来 TelemetryDeck 等の SDK を導入する際は
//  `AnalyticsService` を実装した別 struct を作り、合成点（App / EnvironmentKey）で差し替えるだけでよい。
//

import Foundation
import OSLog
import SwiftUI

// MARK: - Events

/// 計測イベント（最小セット）。ここから D1/D7/D30・デイリー完了率・
/// ストリーク分布・通知許諾率・通知経由起動率を算出する。
enum AnalyticsEvent: Sendable {
  case appOpen
  case quizStarted(proposalId: String)
  case quizAnswered(isCorrect: Bool)
  case dailyChallengeCompleted(streak: Int)
  case streakIncremented(days: Int)
  case notificationPermission(granted: Bool)
  case notificationOpened
  case reminderTimeSet(hour: Int, minute: Int)

  var name: String {
    switch self {
    case .appOpen: return "app_open"
    case .quizStarted: return "quiz_started"
    case .quizAnswered: return "quiz_answered"
    case .dailyChallengeCompleted: return "daily_challenge_completed"
    case .streakIncremented: return "streak_incremented"
    case .notificationPermission: return "notification_permission"
    case .notificationOpened: return "notification_opened"
    case .reminderTimeSet: return "reminder_time_set"
    }
  }

  /// 個人を特定しない最小限のパラメータのみを持たせる
  var parameters: [String: String] {
    switch self {
    case .appOpen, .notificationOpened:
      return [:]
    case .quizStarted(let proposalId):
      return ["proposalId": proposalId]
    case .quizAnswered(let isCorrect):
      return ["isCorrect": String(isCorrect)]
    case .dailyChallengeCompleted(let streak):
      return ["streak": String(streak)]
    case .streakIncremented(let days):
      return ["days": String(days)]
    case .notificationPermission(let granted):
      return ["granted": String(granted)]
    case .reminderTimeSet(let hour, let minute):
      return ["hour": String(hour), "minute": String(minute)]
    }
  }
}

// MARK: - Opt-out

/// 計測のオプトアウト設定（設定画面と共有）
enum AnalyticsSettings {
  static let optOutKey = "analytics_opt_out"

  static var isOptedOut: Bool {
    UserDefaults.standard.bool(forKey: optOutKey)
  }
}

// MARK: - Service Protocol

protocol AnalyticsService: Sendable {
  func track(_ event: AnalyticsEvent)
}

// MARK: - Console Implementation (Phase 1)

/// os.Logger に出力するだけの実装。端末外へは一切送信しないためプライバシー上安全。
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
