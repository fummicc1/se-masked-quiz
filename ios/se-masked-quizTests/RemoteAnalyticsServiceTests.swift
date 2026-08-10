import Foundation
import Testing

@testable import se_masked_quiz

@Suite("RemoteAnalyticsService Tests")
struct RemoteAnalyticsServiceTests {

  private func makeDefaults() -> (UserDefaults, String) {
    let suiteName = "analytics-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
  }

  // MARK: - Request builder

  @Test("POSTリクエストのURL・メソッド・ヘッダが正しい")
  func requestBasics() throws {
    let builder = AnalyticsEventRequestBuilder(baseURL: "https://example.com/")
    let request = try builder.makeRequest(
      event: .statsScreenViewed,
      anonId: "550E8400-E29B-41D4-A716-446655440000",
      appVersion: "1.7.0")

    #expect(request.url?.absoluteString == "https://example.com/api/analytics-events")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
  }

  @Test("bodyにname/anonId/appVersion/paramsが入り、クライアント時刻を含まない")
  func requestBody() throws {
    let builder = AnalyticsEventRequestBuilder(baseURL: "https://example.com")
    let request = try builder.makeRequest(
      event: .quizStarted(proposalId: "0401"),
      anonId: "550E8400-E29B-41D4-A716-446655440000",
      appVersion: "1.7.0")

    let body = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: Any]
    let json = try #require(body)
    #expect(json["name"] as? String == "quiz_started")
    #expect(json["anonId"] as? String == "550E8400-E29B-41D4-A716-446655440000")
    #expect(json["appVersion"] as? String == "1.7.0")
    #expect(json["params"] as? [String: String] == ["proposalId": "0401"])
    #expect(Set(json.keys) == ["name", "anonId", "appVersion", "params"])
  }

  // MARK: - Event names (struct化のリグレッション防止)

  @Test("全イベントのname文字列がサーバのホワイトリストと一致する")
  func eventNames() {
    #expect(AnalyticsEvent.appOpen.name == "app_open")
    #expect(AnalyticsEvent.quizStarted(proposalId: "0001").name == "quiz_started")
    #expect(AnalyticsEvent.quizAnswered(isCorrect: true).name == "quiz_answered")
    #expect(AnalyticsEvent.dailyChallengeCompleted(streak: 3).name == "daily_challenge_completed")
    #expect(AnalyticsEvent.streakIncremented(days: 5).name == "streak_incremented")
    #expect(AnalyticsEvent.notificationPermission(granted: false).name == "notification_permission")
    #expect(AnalyticsEvent.notificationOpened.name == "notification_opened")
    #expect(AnalyticsEvent.reminderTimeSet(hour: 9, minute: 30).name == "reminder_time_set")
    #expect(AnalyticsEvent.statsScreenViewed.name == "stats_screen_viewed")
  }

  @Test("イベントのparametersが従来のキーと値を保つ")
  func eventParameters() {
    #expect(AnalyticsEvent.appOpen.parameters.isEmpty)
    #expect(AnalyticsEvent.quizAnswered(isCorrect: true).parameters == ["isCorrect": "true"])
    #expect(
      AnalyticsEvent.reminderTimeSet(hour: 9, minute: 30).parameters
        == ["hour": "9", "minute": "30"])
  }

  // MARK: - track

  @Test("trackで送信クロージャが1回呼ばれる")
  func trackSends() {
    let (defaults, _) = makeDefaults()
    let sent = SendSpy()
    let service = RemoteAnalyticsService(
      builder: AnalyticsEventRequestBuilder(baseURL: "https://example.com"),
      defaults: defaults,
      appVersion: "1.7.0",
      send: { sent.record($0) })

    service.track(.appOpen)

    #expect(sent.requests.count == 1)
    #expect(sent.requests.first?.url?.path() == "/api/analytics-events")
  }

  @Test("オプトアウト時は送信されず匿名IDも生成されない")
  func optOutSkipsSendAndIDCreation() {
    let (defaults, _) = makeDefaults()
    defaults.set(true, forKey: AnalyticsSettings.optOutKey)
    let sent = SendSpy()
    let service = RemoteAnalyticsService(
      builder: AnalyticsEventRequestBuilder(baseURL: "https://example.com"),
      defaults: defaults,
      appVersion: "1.7.0",
      send: { sent.record($0) })

    service.track(.appOpen)

    #expect(sent.requests.isEmpty)
    #expect(defaults.string(forKey: AnonymousInstallID.key) == nil)
  }

  // MARK: - Anonymous install ID

  @Test("匿名IDは安定していてUUID形式で永続化される")
  func anonymousIDStability() {
    let (defaults, _) = makeDefaults()
    let first = AnonymousInstallID.value(in: defaults)
    let second = AnonymousInstallID.value(in: defaults)

    #expect(first == second)
    #expect(defaults.string(forKey: AnonymousInstallID.key) == first)
    #expect(UUID(uuidString: first) != nil)
  }
}

/// track の send クロージャから同期的に記録する簡易スパイ
private final class SendSpy: @unchecked Sendable {
  private(set) var requests: [URLRequest] = []

  func record(_ request: URLRequest) {
    requests.append(request)
  }
}
