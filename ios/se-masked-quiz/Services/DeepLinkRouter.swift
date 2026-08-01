//
//  DeepLinkRouter.swift
//  se-masked-quiz
//
//  Custom URL Scheme（semaskedquiz://challenge?...）と通知タップの userInfo、
//  両方の入口を共通ロジックで捌き、該当タブ選択とチャレンジ画面への遷移を仲介する。
//

import Foundation
import Observation

@MainActor
@Observable
final class DeepLinkRouter {
  /// `UNMutableNotificationContent.userInfo` に載せるキー。
  /// NotificationService（送信側）と本クラス（受信側）の双方から参照される。
  enum UserInfoKey {
    static let track = "track"
    static let proposalId = "proposalId"
  }

  struct PendingChallenge: Equatable {
    let track: ProposalTrack
    let proposalId: String
  }

  /// DeepLink/通知に応じて切り替えるタブ
  var selectedTab: AppTab = .track(.swiftEvolution)
  /// 各 `ProposalListScreen` が自分の track と一致した時に消費する保留中のチャレンジ
  var pendingChallenge: PendingChallenge?

  /// `semaskedquiz://challenge?track=swiftEvolution&proposalId=SE-0401` 形式のURLを処理する
  func handle(url: URL) {
    guard url.scheme == "semaskedquiz", url.host == "challenge",
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let trackRaw = items.first(where: { $0.name == "track" })?.value,
      let track = ProposalTrack(rawValue: trackRaw),
      let rawId = items.first(where: { $0.name == "proposalId" })?.value
    else { return }
    applyChallenge(track: track, proposalId: rawId)
  }

  /// 通知タップ時の `UNNotificationResponse.notification.request.content.userInfo` を処理する
  func handle(userInfo: [AnyHashable: Any]) {
    guard let trackRaw = userInfo[UserInfoKey.track] as? String,
      let track = ProposalTrack(rawValue: trackRaw),
      let rawId = userInfo[UserInfoKey.proposalId] as? String
    else { return }
    applyChallenge(track: track, proposalId: rawId)
  }

  private func applyChallenge(track: ProposalTrack, proposalId: String) {
    selectedTab = .track(track)
    pendingChallenge = PendingChallenge(track: track, proposalId: Self.normalize(proposalId))
  }

  /// "SE-0401" / "ST-0012" のような表示用接頭辞を除去し、bare形式のproposalIdに正規化する
  static func normalize(_ rawId: String) -> String {
    for track in ProposalTrack.allCases {
      let prefix = "\(track.displayPrefix)-"
      if rawId.hasPrefix(prefix) {
        return String(rawId.dropFirst(prefix.count))
      }
    }
    return rawId
  }
}
