import Foundation
import Testing
@testable import se_masked_quiz

@Suite("SERepository / Strapi payload")
struct SERepositoryTests {

  @Test("Strapi v4 形式（attributes ネスト）を SwiftEvolution に変換できる")
  func decodeStrapiV4NestedAttributes() throws {
    let json = """
    {
      "data": [
        {
          "id": 1,
          "attributes": {
            "proposalId": "0001",
            "title": "SE-0001",
            "authors": "Alice",
            "content": "<p>hello</p>",
            "reviewManager": null,
            "status": null
          }
        }
      ],
      "meta": {}
    }
    """
    let data = try #require(json.data(using: .utf8))
    let proposals = try StrapiProposalPayload.decodeProposals(from: data)
    #expect(proposals.count == 1)
    let first = try #require(proposals.first)
    #expect(first.id == "1")
    #expect(first.proposalId == "0001")
    #expect(first.title == "SE-0001")
    #expect(first.authors == "Alice")
    #expect(first.content == "<p>hello</p>")
    #expect(first.reviewManager == nil)
    #expect(first.status == nil)
  }

  @Test("documentId がある場合は id に documentId を優先する")
  func decodePrefersDocumentIdForStableId() throws {
    let json = """
    {
      "data": [
        {
          "id": 1,
          "documentId": "doc-abc",
          "attributes": {
            "proposalId": "0001",
            "title": "T",
            "authors": "A",
            "content": "c"
          }
        }
      ]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let proposals = try StrapiProposalPayload.decodeProposals(from: data)
    let first = try #require(proposals.first)
    #expect(first.id == "doc-abc")
  }

  @Test("フラットなエントリ（attributes なし）をデコードできる")
  func decodeFlatEntry() throws {
    let json = """
    {
      "data": [
        {
          "id": 42,
          "proposalId": "0002",
          "title": "Flat",
          "authors": "Bob",
          "content": "<div>x</div>"
        }
      ]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let proposals = try StrapiProposalPayload.decodeProposals(from: data)
    let first = try #require(proposals.first)
    #expect(first.id == "42")
    #expect(first.proposalId == "0002")
    #expect(first.title == "Flat")
  }

  @Test("id が文字列でも解釈できる")
  func decodeStringNumericId() throws {
    let json = """
    {
      "data": [
        {
          "id": "7",
          "attributes": {
            "proposalId": "0003",
            "title": "T",
            "authors": "A",
            "content": "c"
          }
        }
      ]
    }
    """
    let data = try #require(json.data(using: .utf8))
    let proposals = try StrapiProposalPayload.decodeProposals(from: data)
    let first = try #require(proposals.first)
    #expect(first.id == "7")
  }
}
