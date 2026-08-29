import Foundation
import Testing

@testable import se_masked_quiz

private func decodeSegments(_ json: String) throws -> [ProposalSegment] {
  try JSONDecoder().decode([ProposalSegment].self, from: Data(json.utf8))
}

@Suite("段落データの読み取り")
struct ProposalSegmentTests {

  @Test("本文の断片を読み取れる")
  func readsTextSegment() throws {
    let segments = try decodeSegments(#"[{"kind":"text","text":"hello"}]"#)
    #expect(segments == [.text("hello")])
  }

  @Test("空欄の位置を読み取れる")
  func readsMaskSegment() throws {
    let segments = try decodeSegments(#"[{"kind":"mask","index":3}]"#)
    #expect(segments == [.mask(index: 3)])
  }

  @Test("本文と空欄が混ざった並びを順序どおり読み取れる")
  func readsMixedSegmentsInOrder() throws {
    let json = """
      [{"kind":"text","text":"Actors provide "},
       {"kind":"mask","index":3},
       {"kind":"text","text":" domains."}]
      """
    let segments = try decodeSegments(json)
    #expect(segments == [.text("Actors provide "), .mask(index: 3), .text(" domains.")])
  }

  @Test("何も無い段落を読み取れる")
  func readsEmptyParagraph() throws {
    #expect(try decodeSegments("[]").isEmpty)
  }

  @Test("知らない種類の要素は読み取りに失敗する")
  func failsOnUnknownKind() {
    #expect(throws: (any Error).self) {
      try decodeSegments(#"[{"kind":"image","src":"a.png"}]"#)
    }
  }

  @Test("空欄に位置が無いときは読み取りに失敗する")
  func failsWhenMaskHasNoIndex() {
    #expect(throws: (any Error).self) {
      try decodeSegments(#"[{"kind":"mask"}]"#)
    }
  }

  @Test("本文に文字列が無いときは読み取りに失敗する")
  func failsWhenTextHasNovalue() {
    #expect(throws: (any Error).self) {
      try decodeSegments(#"[{"kind":"text"}]"#)
    }
  }

  @Test("位置が数値でないときは読み取りに失敗する")
  func failsWhenIndexIsNotNumber() {
    #expect(throws: (any Error).self) {
      try decodeSegments(#"[{"kind":"mask","index":"3"}]"#)
    }
  }
}
