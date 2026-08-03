import Testing

@testable import se_masked_quiz

@Suite("ProposalStatus Tests")
struct ProposalStatusTests {

  // MARK: - Implemented系

  @Test("Implemented - バージョン付き")
  func implementedWithVersion() {
    let status = ProposalStatus.parse("**Implemented (Swift 5.9)**")
    #expect(status == .implemented(version: "5.9"))
    #expect(status.label == "Swift 5.9")
  }

  @Test("Implemented - パッチバージョン付き")
  func implementedWithPatchVersion() {
    let status = ProposalStatus.parse("**Implemented (Swift 3.0.1)**")
    #expect(status == .implemented(version: "3.0.1"))
    #expect(status.label == "Swift 3.0.1")
  }

  @Test("Implemented - バージョン無し")
  func implementedWithoutVersion() {
    let status = ProposalStatus.parse("**Implemented**")
    #expect(status == .implemented(version: nil))
    #expect(status.label == "Implemented")
  }

  @Test("Implemented with Modifications はimplemented扱い")
  func implementedWithModifications() {
    let status = ProposalStatus.parse("**Implemented with Modifications (Swift 5.4)**")
    #expect(status == .implemented(version: "5.4"))
  }

  @Test("Partially implemented はimplementedより優先して判定される")
  func partiallyImplemented() {
    let status = ProposalStatus.parse("**Partially implemented (Swift 5.1)**")
    #expect(status == .partiallyImplemented)
    #expect(status.label == "Partially Implemented")
  }

  // MARK: - レビュー進行系

  @Test("Accepted")
  func accepted() {
    #expect(ProposalStatus.parse("**Accepted**") == .accepted)
  }

  @Test("Accepted with modifications はaccepted扱い")
  func acceptedWithModifications() {
    #expect(ProposalStatus.parse("**Accepted with modifications**") == .accepted)
  }

  @Test("Active review - レビュー期間付き")
  func activeReviewWithPeriod() {
    #expect(
      ProposalStatus.parse("**Active review (March 1...March 11, 2024)**") == .activeReview)
  }

  @Test("Active Review - 大文字ゆれ")
  func activeReviewCaseVariant() {
    #expect(ProposalStatus.parse("**Active Review**") == .activeReview)
  }

  @Test("Previewing")
  func previewing() {
    #expect(ProposalStatus.parse("**Previewing**") == .previewing)
  }

  // MARK: - 不成立系

  @Test("Rejected")
  func rejected() {
    #expect(ProposalStatus.parse("**Rejected**") == .rejected)
  }

  @Test("Rejected - Rationaleリンク付きでもリンク文字列を含まない")
  func rejectedWithRationaleLink() {
    let status = ProposalStatus.parse(
      "**Rejected** ([Rationale](https://forums.swift.org/t/rationale/12345))")
    #expect(status == .rejected)
    #expect(status.label == "Rejected")
  }

  @Test("Returned for revision")
  func returnedForRevision() {
    #expect(ProposalStatus.parse("**Returned for revision**") == .returned)
  }

  @Test("Returned for Revision - 大文字ゆれ")
  func returnedCaseVariant() {
    #expect(ProposalStatus.parse("**Returned for Revision**") == .returned)
  }

  @Test("Withdrawn")
  func withdrawn() {
    #expect(ProposalStatus.parse("**Withdrawn**") == .withdrawn)
  }

  @Test("Expired はwithdrawn扱い")
  func expired() {
    #expect(ProposalStatus.parse("**Expired**") == .withdrawn)
  }

  // MARK: - エッジケース

  @Test("前後の空白ゆれを許容する")
  func whitespaceVariant() {
    #expect(ProposalStatus.parse("  **Implemented (Swift 5.9)**  ") == .implemented(version: "5.9"))
  }

  @Test("nil はunknown（空ラベル）")
  func nilStatus() {
    let status = ProposalStatus.parse(nil)
    #expect(status == .unknown(text: ""))
    #expect(status.label.isEmpty)
  }

  @Test("空文字はunknown（空ラベル）")
  func emptyStatus() {
    #expect(ProposalStatus.parse("").label.isEmpty)
  }

  @Test("未知の語彙はunknownとして本文をそのままラベルにする")
  func unknownVocabulary() {
    let status = ProposalStatus.parse("**Scheduled for review (April 2026)**")
    #expect(status == .unknown(text: "Scheduled for review"))
    #expect(status.label == "Scheduled for review")
  }
}
