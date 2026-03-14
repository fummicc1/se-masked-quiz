import SwiftUI

/// 通知設定画面
struct ReviewNotificationSettingsView: View {
  @Environment(\.reviewNotificationService) private var notificationService
  @State private var isEnabled = false
  @State private var notificationTime = Calendar.current.date(
    from: DateComponents(hour: 9, minute: 0)
  ) ?? Date()
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    Form {
      Section {
        Toggle("日次復習通知", isOn: $isEnabled)
          .onChange(of: isEnabled) { oldValue, newValue in
            Task {
              await handleToggleChange(newValue)
            }
          }

        if isEnabled {
          DatePicker(
            "通知時刻",
            selection: $notificationTime,
            displayedComponents: .hourAndMinute
          )
          .onChange(of: notificationTime) { oldValue, newValue in
            Task {
              await scheduleNotification()
            }
          }
        }
      } header: {
        Text("復習リマインダー")
      } footer: {
        Text("毎日指定した時刻に、期限切れの復習がある場合に通知します。")
      }

      if let error = error {
        Section {
          Text(error.localizedDescription)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }
    }
    .navigationTitle("通知設定")
    .task {
      await loadSettings()
    }
    .disabled(isLoading)
  }

  private func loadSettings() async {
    isLoading = true
    let status = await notificationService.getAuthorizationStatus()
    isEnabled = status == .authorized
    isLoading = false
  }

  private func handleToggleChange(_ newValue: Bool) async {
    isLoading = true
    error = nil

    if newValue {
      do {
        let granted = try await notificationService.requestAuthorization()
        if granted {
          await scheduleNotification()
        } else {
          isEnabled = false
          error = NotificationError.notAuthorized
        }
      } catch {
        isEnabled = false
        self.error = error
      }
    } else {
      await notificationService.cancelAllNotifications()
    }

    isLoading = false
  }

  private func scheduleNotification() async {
    guard isEnabled else { return }

    isLoading = true
    error = nil

    do {
      let components = Calendar.current.dateComponents(
        [.hour, .minute],
        from: notificationTime
      )
      try await notificationService.scheduleDailyReviewNotification(at: components)
    } catch {
      self.error = error
    }

    isLoading = false
  }
}

#Preview {
  NavigationStack {
    ReviewNotificationSettingsView()
  }
}
