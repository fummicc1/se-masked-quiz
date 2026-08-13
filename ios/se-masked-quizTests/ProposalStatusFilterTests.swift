import Foundation
import Testing
@testable import se_masked_quiz

@Suite("ProposalStatusFilter")
struct ProposalStatusFilterTests {

  @Test("全caseがメニュー表示用ラベルを持つ")
  func allCasesHaveLabels() {
    for filter in ProposalStatusFilter.allCases {
      #expect(!filter.label.isEmpty, "\(filter) のラベルが空")
    }
  }

  @Test(
    "単一containsのcaseは status[contains] クエリを1つ生成する",
    arguments: [
      (ProposalStatusFilter.partiallyImplemented, "partially"),
      (.accepted, "accepted"),
      (.activeReview, "active review"),
      (.previewing, "previewing"),
      (.returned, "returned"),
      (.rejected, "rejected"),
    ])
  func singleContainsQuery(filter: ProposalStatusFilter, keyword: String) {
    let items = filter.queryItems(startingAndIndex: 0)
    #expect(items == [URLQueryItem(name: "where[and][0][status][contains]", value: keyword)])
  }

  @Test("all はクエリを生成しない")
  func allProducesNoQuery() {
    #expect(ProposalStatusFilter.all.queryItems(startingAndIndex: 0).isEmpty)
  }

  @Test("startingAndIndex が条件のインデックスに反映される")
  func startingAndIndexIsApplied() {
    let items = ProposalStatusFilter.implemented.queryItems(startingAndIndex: 1)
    #expect(
      items == [
        URLQueryItem(name: "where[and][1][status][contains]", value: "implemented"),
        URLQueryItem(name: "where[and][2][status][not_like]", value: "partially"),
      ])
  }

  @Test(
    "キーワードは ProposalStatus.parse の判定と整合する",
    arguments: [
      ("**Implemented (Swift 5.9)**", ProposalStatusFilter.implemented),
      ("**Partially implemented (Swift 6.0)**", .partiallyImplemented),
      ("**Accepted**", .accepted),
      ("**Active review (March 1...11, 2024)**", .activeReview),
      ("**Previewing**", .previewing),
      ("**Returned for revision**", .returned),
      ("**Rejected**", .rejected),
      ("**Withdrawn**", .withdrawn),
      ("**Expired**", .withdrawn),
    ])
  func keywordsMatchParseResult(raw: String, filter: ProposalStatusFilter) {
    let parsed = ProposalStatus.parse(raw)
    let matched = ProposalStatusFilterTests.matches(raw: raw, filter: filter)
    #expect(matched, "\(filter) のクエリ条件が \(raw) にマッチしない")
    #expect(
      ProposalStatusFilterTests.expectedFilter(for: parsed) == filter,
      "parse結果 \(parsed) とフィルタ \(filter) が対応しない")
  }

  /// サーバーの contains/not_like (case-insensitive LIKE) を模して照合する
  private static func matches(raw: String, filter: ProposalStatusFilter) -> Bool {
    let lowered = raw.lowercased()
    let items = filter.queryItems(startingAndIndex: 0)
    for item in items where item.name.contains("[or]") {
      if lowered.contains(item.value ?? "") { return true }
    }
    let andItems = items.filter { !$0.name.contains("[or]") }
    guard !andItems.isEmpty else { return false }
    return andItems.allSatisfy { item in
      let keyword = (item.value ?? "").lowercased()
      return item.name.hasSuffix("[not_like]")
        ? !lowered.contains(keyword)
        : lowered.contains(keyword)
    }
  }

  private static func expectedFilter(for status: ProposalStatus) -> ProposalStatusFilter? {
    let mapping: [(ProposalStatus, ProposalStatusFilter)] = [
      (.partiallyImplemented, .partiallyImplemented),
      (.accepted, .accepted),
      (.activeReview, .activeReview),
      (.previewing, .previewing),
      (.returned, .returned),
      (.rejected, .rejected),
      (.withdrawn, .withdrawn),
    ]
    if case .implemented = status { return .implemented }
    return mapping.first { $0.0 == status }?.1
  }
}
