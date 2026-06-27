import Foundation
import Testing
@testable import se_masked_quiz

@Suite("ProposalReferenceRepository / proposal-references REST API")
struct ProposalReferenceRepositoryTests {

  @Test("PayloadReference をデコードできる")
  func decodeReference() throws {
    let json = """
    {
      "docs": [ { "id": 1, "fromProposalId": "0304", "toProposalId": "0296" } ],
      "totalDocs": 1, "limit": 1000, "totalPages": 1, "page": 1,
      "hasNextPage": false, "hasPrevPage": false
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(PayloadListResponse<PayloadReference>.self, from: data)
    let first = try #require(response.docs.first)
    #expect(first.fromProposalId == "0304")
    #expect(first.toProposalId == "0296")
  }

  @Test("outgoing は where[fromProposalId][in] とカンマ区切りIDを生成する")
  func outgoingURL() throws {
    let url = try ProposalReferenceRepository.referencesURL(
      baseURL: "https://example.com/",
      field: "fromProposalId",
      ids: ["0304", "0306"]
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[fromProposalId][in]", value: "0304,0306")))
    #expect(items.contains(URLQueryItem(name: "limit", value: "1000")))
  }

  @Test("incoming は where[toProposalId][in] を生成する")
  func incomingURL() throws {
    let url = try ProposalReferenceRepository.referencesURL(
      baseURL: "https://example.com",
      field: "toProposalId",
      ids: ["0304"]
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[toProposalId][in]", value: "0304")))
  }
}
