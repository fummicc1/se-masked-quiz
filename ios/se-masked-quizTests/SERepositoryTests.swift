import Foundation
import Testing
@testable import se_masked_quiz

@Suite("提案一覧の取得")
struct SERepositoryTests {

  @Test("サーバーの応答から提案を読み取れる")
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

  @Test("読み取った提案の各項目がアプリで扱う形に引き継がれる")
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

  @Test("検索も絞り込みもしないときは、提案番号の新しい順で取得する")
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

  @Test("提案番号の古い順に並べ替えられる")
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

  @Test("提案番号の新しい順に並べ替えられる")
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

  @Test("キーワード検索はタイトル・提案番号・著者のいずれかに一致する提案を探す")
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

  @Test("ステータスを選ぶと、そのステータスの提案だけを取得する")
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

  @Test("Implemented で絞り込むと、Partially Implemented の提案は除外される")
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

  @Test("Withdrawn で絞り込むと、Expired の提案も含める")
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

  @Test("キーワード検索とステータス絞り込みを同時に使うと、両方の条件を満たす提案だけを取得する")
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

  @Test("「すべて」を選んだときはステータスで絞り込まない")
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

  @Test("空白だけを入力しても検索条件として扱わない")
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

  @Test("提案番号を複数指定して、まとめて取得できる")
  func proposalsByIdsURL() throws {
    let url = try SERepository.proposalsByIdsURL(
      baseURL: "https://example.com/",
      proposalIds: ["0005", "0023"]
    )
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    #expect(items.contains(URLQueryItem(name: "where[proposalId][in]", value: "0005,0023")))
    #expect(items.contains(URLQueryItem(name: "limit", value: "2")))
  }

  @Test("依存グラフ用の取得では、本文を除いた提案番号とタイトルだけを要求する")
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

  @Test("本文を含まない応答からでも、依存グラフ用の提案を読み取れる")
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

  @Test("まとめて取得する提案番号は、指定した件数ごとに分割される")
  func chunked() {
    let ids = (1 ... 5).map { String($0) }
    let chunks = PayloadHTTP.chunked(ids, size: 2)
    #expect(chunks.count == 3)
    #expect(chunks.first == ["1", "2"])
    #expect(chunks.last == ["5"])
    #expect(PayloadHTTP.chunked([], size: 2).isEmpty)
  }

  @Test("次のページがあるかどうかを応答から読み取れる")
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
