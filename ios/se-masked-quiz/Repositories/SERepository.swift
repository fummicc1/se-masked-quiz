//
//  SERepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation
import SwiftUI

enum ProposalSortOrder: String, CaseIterable, Sendable, Hashable {
  case ascending
  case descending

  var queryValue: String {
    switch self {
    case .ascending:
      return "proposalId"
    case .descending:
      return "-proposalId"
    }
  }
}

enum SERepositoryError: Error, LocalizedError, Equatable {
  case invalidBaseURL
  case httpStatus(Int)
  case emptyResponseBody
  case decodingFailed

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      return "提案一覧の取得先URLの形式が正しくありません。"
    case .httpStatus(let code):
      return "提案一覧を取得できませんでした（HTTP \(code)）。"
    case .emptyResponseBody:
      return "提案一覧の応答が空でした。"
    case .decodingFailed:
      return "提案一覧のデータを読み取れませんでした。"
    }
  }
}

struct SERepository: Sendable {
  private static let pageSize = 10

  func fetch(
    page: Int,
    searchText: String? = nil,
    sortOrder: ProposalSortOrder = .descending,
    statusFilter: ProposalStatusFilter = .all,
    track: ProposalTrack = .swiftEvolution
  ) async throws -> PayloadListResponse<PayloadProposal> {
    let baseURL = Env.serverBaseURL
    let apiKey = Env.serverApiKey
    let requestURL = try Self.proposalsURL(
      baseURL: baseURL,
      page: page,
      limit: Self.pageSize,
      searchText: searchText,
      sortOrder: sortOrder,
      statusFilter: statusFilter,
      track: track
    )
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("users API-Key \(apiKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SERepositoryError.httpStatus(-1)
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw SERepositoryError.httpStatus(http.statusCode)
    }
    guard !data.isEmpty else {
      throw SERepositoryError.emptyResponseBody
    }
    do {
      let decoded = try JSONDecoder().decode(PayloadListResponse<PayloadProposal>.self, from: data)
      return decoded
    } catch {
      throw SERepositoryError.decodingFailed
    }
  }

  /// 複数の提案IDをまとめて取得する（前提提案チップ用。本文含むフル取得）
  func fetchProposals(byProposalIds ids: [String]) async throws -> [SwiftEvolution] {
    guard !ids.isEmpty else { return [] }
    var result: [SwiftEvolution] = []
    for chunk in PayloadHTTP.chunked(ids, size: 50) {
      let url = try Self.proposalsByIdsURL(baseURL: Env.serverBaseURL, proposalIds: chunk)
      let decoded: PayloadListResponse<PayloadProposal> = try await PayloadHTTP.get(url)
      result.append(contentsOf: decoded.docs.map { $0.toSwiftEvolution() })
    }
    return result
  }

  /// グラフ描画用に提案IDから軽量ノード（proposalId/title のみ）を取得する。
  /// `select` で巨大な content を転送しない。
  func fetchGraphNodes(byProposalIds ids: [String]) async throws -> [GraphProposalNode] {
    guard !ids.isEmpty else { return [] }
    var result: [GraphProposalNode] = []
    for chunk in PayloadHTTP.chunked(ids, size: 50) {
      let url = try Self.graphNodesURL(baseURL: Env.serverBaseURL, proposalIds: chunk)
      let decoded: PayloadListResponse<PayloadProposalNode> = try await PayloadHTTP.get(url)
      result.append(contentsOf: decoded.docs.map { GraphProposalNode(proposalId: $0.proposalId, title: $0.title) })
    }
    return result
  }

  /// 提案IDを指定して単一の提案を取得する（デイリーチャレンジ用）
  func fetchProposal(
    byProposalId proposalId: String,
    track: ProposalTrack = .swiftEvolution
  ) async throws -> SwiftEvolution? {
    let baseURL = Env.serverBaseURL
    let apiKey = Env.serverApiKey
    var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasSuffix("/") {
      trimmed.removeLast()
    }
    guard var components = URLComponents(string: "\(trimmed)/api/\(track.proposalsSlug)") else {
      throw SERepositoryError.invalidBaseURL
    }
    components.queryItems = [
      URLQueryItem(name: "where[proposalId][equals]", value: proposalId),
      URLQueryItem(name: "limit", value: "1"),
    ]
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("users API-Key \(apiKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SERepositoryError.httpStatus(-1)
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw SERepositoryError.httpStatus(http.statusCode)
    }
    let decoded = try JSONDecoder().decode(PayloadListResponse<PayloadProposal>.self, from: data)
    return decoded.docs.first?.toSwiftEvolution(track: track)
  }

  static func proposalsURL(
    baseURL: String,
    page: Int,
    limit: Int,
    searchText: String? = nil,
    sortOrder: ProposalSortOrder = .descending,
    statusFilter: ProposalStatusFilter = .all,
    track: ProposalTrack = .swiftEvolution
  ) throws -> URL {
    var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasSuffix("/") {
      trimmed.removeLast()
    }
    guard var components = URLComponents(string: "\(trimmed)/api/\(track.proposalsSlug)") else {
      throw SERepositoryError.invalidBaseURL
    }
    var items: [URLQueryItem] = [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "sort", value: sortOrder.queryValue),
    ]
    // 検索とステータス絞り込みをANDで両立させるため、条件は where[and][N] 配下に並べる
    var andIndex = 0
    let trimmedSearch = (searchText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedSearch.isEmpty {
      for (fieldIndex, field) in ["title", "proposalId", "authors"].enumerated() {
        items.append(
          URLQueryItem(
            name: "where[and][\(andIndex)][or][\(fieldIndex)][\(field)][contains]",
            value: trimmedSearch))
      }
      andIndex += 1
    }
    items.append(contentsOf: statusFilter.queryItems(startingAndIndex: andIndex))
    components.queryItems = items
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }

  static func proposalsByIdsURL(baseURL: String, proposalIds: [String]) throws -> URL {
    var components = try PayloadHTTP.components(baseURL: baseURL, path: "/api/proposals")
    components.queryItems = [
      URLQueryItem(name: "where[proposalId][in]", value: proposalIds.joined(separator: ",")),
      URLQueryItem(name: "limit", value: String(max(proposalIds.count, 1))),
    ]
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }

  static func graphNodesURL(baseURL: String, proposalIds: [String]) throws -> URL {
    var components = try PayloadHTTP.components(baseURL: baseURL, path: "/api/proposals")
    components.queryItems = [
      URLQueryItem(name: "where[proposalId][in]", value: proposalIds.joined(separator: ",")),
      URLQueryItem(name: "select[proposalId]", value: "true"),
      URLQueryItem(name: "select[title]", value: "true"),
      URLQueryItem(name: "limit", value: String(max(proposalIds.count, 1))),
    ]
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }
}

// MARK: - Shared Payload HTTP helpers

/// 認証ヘッダ付き GET と共通デコードをまとめた Payload REST のヘルパー。
enum PayloadHTTP {
  static func components(baseURL: String, path: String) throws -> URLComponents {
    var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasSuffix("/") {
      trimmed.removeLast()
    }
    guard let components = URLComponents(string: "\(trimmed)\(path)") else {
      throw SERepositoryError.invalidBaseURL
    }
    return components
  }

  static func get<T: Decodable & Sendable>(_ url: URL) async throws -> T {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("users API-Key \(Env.serverApiKey)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SERepositoryError.httpStatus(-1)
    }
    guard (200 ... 299).contains(http.statusCode) else {
      throw SERepositoryError.httpStatus(http.statusCode)
    }
    guard !data.isEmpty else {
      throw SERepositoryError.emptyResponseBody
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw SERepositoryError.decodingFailed
    }
  }

  /// `where[...][in]` のリストが長くなりすぎないよう一定数で分割する。
  static func chunked(_ ids: [String], size: Int) -> [[String]] {
    guard size > 0 else { return ids.isEmpty ? [] : [ids] }
    return stride(from: 0, to: ids.count, by: size).map {
      Array(ids[$0 ..< min($0 + size, ids.count)])
    }
  }
}

// MARK: - Graph node models

/// `select` で title のみ取得した軽量な提案ノード。
struct PayloadProposalNode: Decodable, Sendable {
  let proposalId: String
  let title: String
}

struct GraphProposalNode: Sendable, Hashable, Identifiable {
  var id: String { proposalId }
  let proposalId: String
  let title: String
}

// MARK: - Payload REST API Response Models

struct PayloadListResponse<T: Decodable & Sendable>: Decodable, Sendable {
  let docs: [T]
  let totalDocs: Int
  let limit: Int
  let totalPages: Int
  let page: Int
  let hasNextPage: Bool
  let hasPrevPage: Bool
}

struct PayloadProposal: Decodable, Sendable {
  let id: Int
  let proposalId: String
  let title: String
  let authors: String
  let content: String
  let reviewManager: String?
  let status: String?

  func toSwiftEvolution(track: ProposalTrack = .swiftEvolution) -> SwiftEvolution {
    SwiftEvolution(
      id: String(id),
      proposalId: proposalId,
      title: title,
      reviewManager: reviewManager,
      status: status,
      authors: authors,
      content: content,
      track: track
    )
  }
}

extension SERepository: EnvironmentKey {
  static var defaultValue: Self {
    SERepository()
  }
}

extension EnvironmentValues {
  var seRepository: SERepository {
    get { self[SERepository.self] }
    set { self[SERepository.self] = newValue }
  }
}
