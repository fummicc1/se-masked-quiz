import Foundation
import Testing
@testable import se_masked_quiz

@Suite("SERepository / Payload CMS REST API")
struct SERepositoryTests {

  @Test("Payload REST API レスポンスを正しくデコードできる")
  func decodePayloadListResponse() throws {
    let json = """
    {
      "docs": [
        {
          "id": 1,
          "proposalId": "0001",
          "title": "SE-0001",
          "authors": "Alice",
          "content": "<p>hello</p>",
          "reviewManager": null,
          "status": null
        }
      ],
      "totalDocs": 1,
      "limit": 10,
      "totalPages": 1,
      "page": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(PayloadListResponse<PayloadProposal>.self, from: data)
    #expect(response.docs.count == 1)
    let first = try #require(response.docs.first)
    #expect(first.id == 1)
    #expect(first.proposalId == "0001")
    #expect(first.title == "SE-0001")
    #expect(first.authors == "Alice")
    #expect(first.content == "<p>hello</p>")
    #expect(first.reviewManager == nil)
    #expect(first.status == nil)
  }

  @Test("PayloadProposal を SwiftEvolution に変換できる")
  func convertToSwiftEvolution() throws {
    let json = """
    {
      "docs": [
        {
          "id": 42,
          "proposalId": "0002",
          "title": "Flat",
          "authors": "Bob",
          "content": "<div>x</div>",
          "reviewManager": "Manager",
          "status": "Accepted"
        }
      ],
      "totalDocs": 1,
      "limit": 10,
      "totalPages": 1,
      "page": 1,
      "hasNextPage": false,
      "hasPrevPage": false
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(PayloadListResponse<PayloadProposal>.self, from: data)
    let first = try #require(response.docs.first)
    let se = first.toSwiftEvolution()
    #expect(se.id == "42")
    #expect(se.proposalId == "0002")
    #expect(se.title == "Flat")
    #expect(se.authors == "Bob")
    #expect(se.reviewManager == "Manager")
    #expect(se.status == "Accepted")
  }

  @Test("ページネーション情報を正しくデコードできる")
  func decodePagination() throws {
    let json = """
    {
      "docs": [],
      "totalDocs": 100,
      "limit": 10,
      "totalPages": 10,
      "page": 3,
      "hasNextPage": true,
      "hasPrevPage": true
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(PayloadListResponse<PayloadProposal>.self, from: data)
    #expect(response.totalDocs == 100)
    #expect(response.limit == 10)
    #expect(response.totalPages == 10)
    #expect(response.page == 3)
    #expect(response.hasNextPage == true)
    #expect(response.hasPrevPage == true)
  }
}
