import Foundation
import Testing
@testable import se_masked_quiz

@Suite("提案のステータス絞り込み")
struct ProposalStatusFilterTests {

  @Test("絞り込みメニューのすべての項目に表示名がある")
  func allCasesHaveLabels() {
    for filter in ProposalStatusFilter.allCases {
      #expect(!filter.label.isEmpty, "\(filter) の表示名が空です")
    }
  }

  @Test(
    "ステータスを選ぶと、その語を含む提案だけを要求する",
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

  @Test("「すべて」を選んだときは絞り込まない")
  func allProducesNoQuery() {
    #expect(ProposalStatusFilter.all.queryItems(startingAndIndex: 0).isEmpty)
  }

  @Test("キーワード検索と併用しても、絞り込み条件が別枠で追加される")
  func startingAndIndexIsApplied() {
    let items = ProposalStatusFilter.implemented.queryItems(startingAndIndex: 1)
    #expect(
      items == [
        URLQueryItem(name: "where[and][1][status][contains]", value: "implemented"),
        URLQueryItem(name: "where[and][2][status][not_like]", value: "partially"),
      ])
  }

  @Test(
    "一覧に表示されるステータスと、絞り込みの分類が一致する",
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
    let matched = ProposalStatusFilterTests.simulatedServerMatch(raw: raw, filter: filter)
    #expect(matched, "「\(raw)」が「\(filter.label)」の絞り込みで取得できません")
    #expect(
      ProposalStatusFilterTests.expectedFilter(for: parsed) == filter,
      "一覧では「\(parsed.label)」と表示されるのに、絞り込みは「\(filter.label)」に分類しています")
  }

  private static func simulatedServerMatch(raw: String, filter: ProposalStatusFilter) -> Bool {
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
