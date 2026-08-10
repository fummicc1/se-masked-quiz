//
//  RemoteAnalyticsService.swift
//  se-masked-quiz
//
//  自前サーバ（Payload + D1）へ匿名の計測イベントを送信する実装。
//  実験用途のため fire-and-forget（リトライ・バッチングなし、欠損許容）。
//  時刻はサーバ側の createdAt を使うのでクライアント時刻は送らない。
//

import Foundation

// MARK: - Anonymous install ID

/// WAU 集計用の匿名インストールID。初回送信時に遅延生成するため、
/// オプトアウト中のユーザーの端末には ID 自体が保存されない。
enum AnonymousInstallID {
  static let key = "analytics_anon_id"

  static func value(in defaults: UserDefaults = .standard) -> String {
    if let stored = defaults.string(forKey: key) {
      return stored
    }
    let generated = UUID().uuidString
    defaults.set(generated, forKey: key)
    return generated
  }
}

// MARK: - Request builder

/// 計測イベントを Payload REST（`POST /api/analytics-events`）の URLRequest へ変換する。
/// 匿名エンドポイントのため Authorization ヘッダは付けない。
struct AnalyticsEventRequestBuilder: Sendable {
  var baseURL: String = Env.serverBaseURL

  private struct Body: Encodable {
    let name: String
    let anonId: String
    let appVersion: String
    let params: [String: String]
  }

  func makeRequest(event: AnalyticsEvent, anonId: String, appVersion: String) throws -> URLRequest {
    let components = try PayloadHTTP.components(baseURL: baseURL, path: "/api/analytics-events")
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      Body(name: event.name, anonId: anonId, appVersion: appVersion, params: event.parameters))
    return request
  }
}

// MARK: - Remote service

struct RemoteAnalyticsService: AnalyticsService {
  var builder = AnalyticsEventRequestBuilder()
  var defaults: UserDefaults = .standard
  var appVersion: String = Self.currentAppVersion()
  /// テストでは同期スパイに差し替える。既定は URLSession への fire-and-forget。
  var send: @Sendable (URLRequest) -> Void = { request in
    Task {
      _ = try? await URLSession.shared.data(for: request)
    }
  }

  func track(_ event: AnalyticsEvent) {
    guard !AnalyticsSettings.isOptedOut(in: defaults) else { return }
    let anonId = AnonymousInstallID.value(in: defaults)
    guard
      let request = try? builder.makeRequest(event: event, anonId: anonId, appVersion: appVersion)
    else { return }
    send(request)
  }

  private static func currentAppVersion() -> String {
    guard
      let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String
    else { return "" }
    return version
  }
}
