//
//  se_masked_quizApp.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

@main
struct se_masked_quizApp: App {
  @Environment(\.scenePhase) private var scenePhase

  private let analytics: any AnalyticsService = ConsoleAnalyticsService()
  private let streakRepository: any StreakRepository = StreakRepositoryImpl()
  private let notificationService = NotificationService()

  var body: some Scene {
    WindowGroup {
      ProposalListScreen()
        .environment(\.analytics, analytics)
        .environment(\.streakRepository, streakRepository)
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active else { return }
      handleBecameActive()
    }
  }

  /// 起動・前面復帰時：起動計測と、リマインダー本文の最新ストリークへの更新
  private func handleBecameActive() {
    analytics.track(.appOpen)

    guard ReminderPreferences.isEnabled else { return }
    Task {
      let streak = await streakRepository.getStreak()
      await notificationService.scheduleDailyReminder(
        hour: ReminderPreferences.hour,
        minute: ReminderPreferences.minute,
        currentStreak: streak.currentStreak
      )
    }
  }
}
