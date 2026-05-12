//
//  SERepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation
import SwiftUI

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

  func fetch(page: Int, searchText: String? = nil) async throws -> PayloadListResponse<PayloadProposal> {
    let baseURL = Env.serverBaseURL
    let apiKey = Env.serverApiKey
    let requestURL = try Self.proposalsURL(
      baseURL: baseURL,
      page: page,
      limit: Self.pageSize,
      searchText: searchText
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

  static func proposalsURL(
    baseURL: String,
    page: Int,
    limit: Int,
    searchText: String? = nil
  ) throws -> URL {
    var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasSuffix("/") {
      trimmed.removeLast()
    }
    guard var components = URLComponents(string: "\(trimmed)/api/proposals") else {
      throw SERepositoryError.invalidBaseURL
    }
    var items: [URLQueryItem] = [
      URLQueryItem(name: "page", value: String(page)),
      URLQueryItem(name: "limit", value: String(limit)),
      URLQueryItem(name: "sort", value: "proposalId"),
    ]
    let trimmedSearch = (searchText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedSearch.isEmpty {
      items.append(URLQueryItem(name: "where[or][0][title][contains]", value: trimmedSearch))
      items.append(URLQueryItem(name: "where[or][1][proposalId][contains]", value: trimmedSearch))
      items.append(URLQueryItem(name: "where[or][2][authors][contains]", value: trimmedSearch))
    }
    components.queryItems = items
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }
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

  func toSwiftEvolution() -> SwiftEvolution {
    SwiftEvolution(
      id: String(id),
      proposalId: proposalId,
      title: title,
      reviewManager: reviewManager,
      status: status,
      authors: authors,
      content: content
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
