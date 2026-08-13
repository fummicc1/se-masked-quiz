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

  @Test("searchText未指定時は where 系クエリを含まず、デフォルトで降順ソートになる")
  func proposalsURLWithoutSearchText() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com/",
      page: 1,
      limit: 10
    )
    let query = url.query ?? ""
    #expect(query.contains("page=1"))
    #expect(query.contains("limit=10"))
    #expect(query.contains("sort=-proposalId"))
    #expect(!query.contains("where"))
  }

  @Test("sortOrder=ascending のとき sort=proposalId が指定される")
  func proposalsURLAscendingSort() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      sortOrder: .ascending
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "sort", value: "proposalId")))
  }

  @Test("sortOrder=descending のとき sort=-proposalId が指定される")
  func proposalsURLDescendingSort() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      sortOrder: .descending
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "sort", value: "-proposalId")))
  }

  @Test("searchText指定時は title/proposalId/authors への contains クエリが含まれる")
  func proposalsURLWithSearchText() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 2,
      limit: 10,
      searchText: "actor"
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "page", value: "2")))
    #expect(
      items.contains(URLQueryItem(name: "where[and][0][or][0][title][contains]", value: "actor")))
    #expect(
      items.contains(
        URLQueryItem(name: "where[and][0][or][1][proposalId][contains]", value: "actor")))
    #expect(
      items.contains(URLQueryItem(name: "where[and][0][or][2][authors][contains]", value: "actor")))
  }

  @Test("statusFilter指定時は where[and][0][status][contains] が含まれる")
  func proposalsURLWithStatusFilter() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      statusFilter: .accepted
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[and][0][status][contains]", value: "accepted")))
  }

  @Test("statusFilter=implemented は partially を not_like で除外する")
  func proposalsURLWithImplementedFilter() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      statusFilter: .implemented
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(
      items.contains(URLQueryItem(name: "where[and][0][status][contains]", value: "implemented")))
    #expect(
      items.contains(URLQueryItem(name: "where[and][1][status][not_like]", value: "partially")))
  }

  @Test("statusFilter=withdrawn は withdrawn/expired の OR 条件になる")
  func proposalsURLWithWithdrawnFilter() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      statusFilter: .withdrawn
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(
      items.contains(
        URLQueryItem(name: "where[and][0][or][0][status][contains]", value: "withdrawn")))
    #expect(
      items.contains(
        URLQueryItem(name: "where[and][0][or][1][status][contains]", value: "expired")))
  }

  @Test("searchText と statusFilter の併用時は検索が and[0]、ステータスが and[1] に入る")
  func proposalsURLWithSearchTextAndStatusFilter() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      searchText: "actor",
      statusFilter: .rejected
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(
      items.contains(URLQueryItem(name: "where[and][0][or][0][title][contains]", value: "actor")))
    #expect(items.contains(URLQueryItem(name: "where[and][1][status][contains]", value: "rejected")))
  }

  @Test("statusFilter=all は where 系クエリを追加しない")
  func proposalsURLWithAllStatusFilter() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      statusFilter: .all
    )
    let query = url.query ?? ""
    #expect(!query.contains("where"))
  }

  @Test("searchText が空白のみの場合は where 系クエリを含まない")
  func proposalsURLWithWhitespaceSearchText() throws {
    let url = try SERepository.proposalsURL(
      baseURL: "https://example.com",
      page: 1,
      limit: 10,
      searchText: "   "
    )
    let query = url.query ?? ""
    #expect(!query.contains("where"))
  }

  @Test("proposalsByIdsURL は where[proposalId][in] とカンマ区切りIDを含む")
  func proposalsByIdsURL() throws {
    let url = try SERepository.proposalsByIdsURL(
      baseURL: "https://example.com/",
      proposalIds: ["0005", "0023"]
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[proposalId][in]", value: "0005,0023")))
    #expect(items.contains(URLQueryItem(name: "limit", value: "2")))
  }

  @Test("graphNodesURL は in と select[proposalId]/select[title] を含み content を要求しない")
  func graphNodesURL() throws {
    let url = try SERepository.graphNodesURL(
      baseURL: "https://example.com",
      proposalIds: ["0005", "0023"]
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[proposalId][in]", value: "0005,0023")))
    #expect(items.contains(URLQueryItem(name: "select[proposalId]", value: "true")))
    #expect(items.contains(URLQueryItem(name: "select[title]", value: "true")))
    let query = url.query ?? ""
    #expect(!query.contains("select%5Bcontent%5D"))
  }

  @Test("PayloadProposalNode を select レスポンスからデコードできる（content 不要）")
  func decodeGraphNode() throws {
    let json = """
    {
      "docs": [ { "id": 7, "proposalId": "0304", "title": "Structured Concurrency" } ],
      "totalDocs": 1, "limit": 1, "totalPages": 1, "page": 1,
      "hasNextPage": false, "hasPrevPage": false
    }
    """
    let data = try #require(json.data(using: .utf8))
    let response = try JSONDecoder().decode(PayloadListResponse<PayloadProposalNode>.self, from: data)
    let first = try #require(response.docs.first)
    #expect(first.proposalId == "0304")
    #expect(first.title == "Structured Concurrency")
  }

  @Test("PayloadHTTP.chunked は指定サイズで分割する")
  func chunked() {
    let ids = (1 ... 5).map { String($0) }
    let chunks = PayloadHTTP.chunked(ids, size: 2)
    #expect(chunks.count == 3)
    #expect(chunks.first == ["1", "2"])
    #expect(chunks.last == ["5"])
    #expect(PayloadHTTP.chunked([], size: 2).isEmpty)
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
