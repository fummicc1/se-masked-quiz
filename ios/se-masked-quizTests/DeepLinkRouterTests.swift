import Foundation
import Testing

@testable import se_masked_quiz

@Suite("DeepLinkRouter Tests")
@MainActor
struct DeepLinkRouterTests {

  // MARK: - handle(url:)

  @Test("正常なURLでtrackとproposalIdが設定される（SE接頭辞は除去される）")
  func handleURLWithSEPrefix() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://challenge?track=swiftEvolution&proposalId=SE-0401")!
    sut.handle(url: url)
    #expect(sut.selectedTrack == .swiftEvolution)
    #expect(
      sut.pendingChallenge == DeepLinkRouter.PendingChallenge(
        track: .swiftEvolution, proposalId: "0401"))
  }

  @Test("ST接頭辞も除去される")
  func handleURLWithSTPrefix() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://challenge?track=swiftTesting&proposalId=ST-0012")!
    sut.handle(url: url)
    #expect(sut.selectedTrack == .swiftTesting)
    #expect(
      sut.pendingChallenge == DeepLinkRouter.PendingChallenge(
        track: .swiftTesting, proposalId: "0012"))
  }

  @Test("接頭辞の無いbare proposalIdはそのまま使われる")
  func handleURLWithoutPrefix() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://challenge?track=swiftEvolution&proposalId=0401")!
    sut.handle(url: url)
    #expect(sut.pendingChallenge?.proposalId == "0401")
  }

  @Test("不正なtrackはpendingChallengeを更新しない")
  func handleURLWithInvalidTrack() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://challenge?track=unknown&proposalId=0401")!
    sut.handle(url: url)
    #expect(sut.pendingChallenge == nil)
  }

  @Test("proposalIdパラメータの欠落はpendingChallengeを更新しない")
  func handleURLWithoutProposalId() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://challenge?track=swiftEvolution")!
    sut.handle(url: url)
    #expect(sut.pendingChallenge == nil)
  }

  @Test("不正なホストは無視される")
  func handleURLWithWrongHost() {
    let sut = DeepLinkRouter()
    let url = URL(string: "semaskedquiz://other?track=swiftEvolution&proposalId=0401")!
    sut.handle(url: url)
    #expect(sut.pendingChallenge == nil)
  }

  @Test("不正なスキームは無視される")
  func handleURLWithWrongScheme() {
    let sut = DeepLinkRouter()
    let url = URL(string: "https://challenge?track=swiftEvolution&proposalId=0401")!
    sut.handle(url: url)
    #expect(sut.pendingChallenge == nil)
  }

  // MARK: - handle(userInfo:)

  @Test("正常なuserInfoでtrackとproposalIdが設定される")
  func handleUserInfoValid() {
    let sut = DeepLinkRouter()
    sut.handle(userInfo: [
      DeepLinkRouter.UserInfoKey.track: "swiftEvolution",
      DeepLinkRouter.UserInfoKey.proposalId: "SE-0401",
    ])
    #expect(sut.selectedTrack == .swiftEvolution)
    #expect(
      sut.pendingChallenge == DeepLinkRouter.PendingChallenge(
        track: .swiftEvolution, proposalId: "0401"))
  }

  @Test("不正なtrackのuserInfoはpendingChallengeを更新しない")
  func handleUserInfoInvalidTrack() {
    let sut = DeepLinkRouter()
    sut.handle(userInfo: [
      DeepLinkRouter.UserInfoKey.track: "unknown",
      DeepLinkRouter.UserInfoKey.proposalId: "0401",
    ])
    #expect(sut.pendingChallenge == nil)
  }

  @Test("proposalId欠落のuserInfoはpendingChallengeを更新しない")
  func handleUserInfoMissingProposalId() {
    let sut = DeepLinkRouter()
    sut.handle(userInfo: [
      DeepLinkRouter.UserInfoKey.track: "swiftEvolution"
    ])
    #expect(sut.pendingChallenge == nil)
  }
}
