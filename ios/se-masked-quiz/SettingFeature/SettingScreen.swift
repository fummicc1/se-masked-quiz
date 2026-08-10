//
//  SettingScreen.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/02/02.
//

import SwiftUI

struct SettingScreen: View {
  @Environment(\.streakRepository) private var streakRepository
  @Environment(\.analytics) private var analytics

  @AppStorage(ReminderPreferences.enabledKey) private var reminderEnabled = false
  @AppStorage(ReminderPreferences.hourKey) private var reminderHour = ReminderPreferences
    .defaultHour
  @AppStorage(ReminderPreferences.minuteKey) private var reminderMinute = ReminderPreferences
    .defaultMinute
  @AppStorage(AnalyticsSettings.optOutKey) private var analyticsOptOut = false

  private var reminderTime: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(
          from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
      },
      set: { newDate in
        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
        reminderHour = comps.hour ?? ReminderPreferences.defaultHour
        reminderMinute = comps.minute ?? ReminderPreferences.defaultMinute
      }
    )
  }

  var body: some View {
    NavigationStack {
      List {
        // 学習リマインダー Section
        Section {
          Toggle(isOn: $reminderEnabled) {
            Label("毎日のリマインダー", systemImage: "bell.badge")
          }
          if reminderEnabled {
            DatePicker(
              "通知時刻",
              selection: reminderTime,
              displayedComponents: .hourAndMinute
            )
          }
        } header: {
          Text("学習リマインダー")
        } footer: {
          Text("毎日決まった時刻に「今日のクイズ」をお知らせします。続けるほどストリークが伸びます。")
        }

        // LLM Model Section (Issue #12)
        Section("LLMモデル") {
          NavigationLink {
            ModelDownloadView()
          } label: {
            HStack {
              Image(systemName: "cpu")
                .foregroundStyle(SemanticColor.accent)
              Text("モデル管理")
            }
          }
        }

        // プライバシー Section
        Section {
          Toggle(
            isOn: Binding(
              get: { !analyticsOptOut },
              set: { analyticsOptOut = !$0 }
            )
          ) {
            Label("利用状況の計測を許可", systemImage: "chart.bar")
          }
        } header: {
          Text("プライバシー")
        } footer: {
          Text("アプリの改善のため、匿名の利用状況のみを開発者のサーバーに送信します。個人を特定する情報は含まれず、第三者に提供することもありません。")
        }

        // License Section
        Section("ライセンス") {
          NavigationLink {
            LicenseScreen()
          } label: {
            Text("ライセンス情報")
          }
        }

        // App Info Section
        Section("アプリ情報") {
          HStack {
            Text("バージョン")
            Spacer()
            Text(
              Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? ""
            )
            .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("設定")
    }
    .onChange(of: reminderEnabled) { _, enabled in
      applyReminderEnabled(enabled)
    }
    .onChange(of: reminderHour) { _, _ in
      rescheduleReminderIfEnabled()
    }
    .onChange(of: reminderMinute) { _, _ in
      rescheduleReminderIfEnabled()
    }
  }

  // MARK: - Reminder Scheduling

  private func applyReminderEnabled(_ enabled: Bool) {
    let service = NotificationService()
    if enabled {
      Task { @MainActor in
        let granted = await service.requestAuthorization()
        analytics.track(.notificationPermission(granted: granted))
        if granted {
          let streak = await streakRepository.getStreak()
          await service.scheduleDailyReminder(
            hour: reminderHour, minute: reminderMinute, currentStreak: streak.currentStreak)
          analytics.track(.reminderTimeSet(hour: reminderHour, minute: reminderMinute))
        } else {
          // 許可されなかった場合は UI を実態に合わせて戻す
          reminderEnabled = false
        }
      }
    } else {
      service.cancelDailyReminder()
    }
  }

  private func rescheduleReminderIfEnabled() {
    guard reminderEnabled else { return }
    let service = NotificationService()
    Task { @MainActor in
      let streak = await streakRepository.getStreak()
      await service.scheduleDailyReminder(
        hour: reminderHour, minute: reminderMinute, currentStreak: streak.currentStreak)
      analytics.track(.reminderTimeSet(hour: reminderHour, minute: reminderMinute))
    }
  }
}

#Preview {
  SettingScreen()
}
