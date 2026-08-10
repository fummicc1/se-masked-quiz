//
//  se_masked_quizApp.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI
import UserNotifications

@main
struct se_masked_quizApp: App {
  @Environment(\.scenePhase) private var scenePhase

  private let analytics: any AnalyticsService = MultiplexAnalyticsService(
    services: [ConsoleAnalyticsService(), RemoteAnalyticsService()])
  private let streakRepository: any StreakRepository = StreakRepositoryImpl()
  private let quizRepository: any QuizRepository = QuizRepositoryImpl()
  private let notificationService = NotificationService()
  private let router: DeepLinkRouter
  private let notificationDelegate: AppNotificationDelegate

  init() {
    let router = DeepLinkRouter()
    self.router = router
    self.notificationDelegate = AppNotificationDelegate(router: router, analytics: analytics)
    UNUserNotificationCenter.current().delegate = notificationDelegate
  }

  var body: some Scene {
    WindowGroup {
      TabView(selection: Bindable(router).selectedTab) {
        ProposalListScreen(track: .swiftEvolution)
          .tabItem {
            Label("Swift Evolution", systemImage: "swift")
          }
          .tag(AppTab.track(.swiftEvolution))
        ProposalListScreen(track: .swiftTesting)
          .tabItem {
            Label("Swift Testing", systemImage: "checkmark.seal")
          }
          .tag(AppTab.track(.swiftTesting))
        NavigationStack {
          StreakStatsScreen()
        }
        .tabItem {
          Label("学習記録", systemImage: "chart.bar.fill")
        }
        .tag(AppTab.stats)
      }
      .environment(\.analytics, analytics)
      .environment(\.streakRepository, streakRepository)
      .environment(router)
      .onOpenURL { url in
        router.handle(url: url)
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active else { return }
      handleBecameActive()
    }
  }

  /// 起動・前面復帰時：起動計測と、リマインダー本文の最新ストリーク・DeepLink情報への更新
  private func handleBecameActive() {
    analytics.track(.appOpen)

    guard ReminderPreferences.isEnabled else { return }
    Task {
      let streak = await streakRepository.getStreak()
      let proposalId = await todaysSEProposalId()
      await notificationService.scheduleDailyReminder(
        hour: ReminderPreferences.hour,
        minute: ReminderPreferences.minute,
        currentStreak: streak.currentStreak,
        track: proposalId != nil ? .swiftEvolution : nil,
        proposalId: proposalId
      )
    }
  }

  /// 通知タップで直接デイリーチャレンジへ遷移できるよう、今日のSE提案IDを算出する。
  /// 取得できない場合はnilを返し、呼び出し元でDeepLink情報なしのフォールバック予約にする。
  private func todaysSEProposalId() async -> String? {
    guard let counts = try? await quizRepository.getAllQuizCounts() else { return nil }
    return DailyChallengeService().todaysProposalId(from: Array(counts.keys), date: Date())
  }
}
