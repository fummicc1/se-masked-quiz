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

  func fetch(offset: Int, query: String? = nil) async throws -> [SwiftEvolution] {
    let baseURL = Env.strapiBaseURL
    let token = Env.strapiApiToken
    let requestURL = try Self.proposalsURL(baseURL: baseURL, offset: offset, limit: Self.pageSize, query: query)
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
      return try StrapiProposalPayload.decodeProposals(from: data)
    } catch {
      throw SERepositoryError.decodingFailed
    }
  }

  private static func proposalsURL(baseURL: String, offset: Int, limit: Int, query: String? = nil) throws -> URL {
    var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    while trimmed.hasSuffix("/") {
      trimmed.removeLast()
    }
    guard var components = URLComponents(string: "\(trimmed)/proposals") else {
      throw SERepositoryError.invalidBaseURL
    }
    var queryItems = [
      URLQueryItem(name: "pagination[start]", value: String(offset)),
      URLQueryItem(name: "pagination[limit]", value: String(limit)),
    ]
    if let query, !query.isEmpty {
      queryItems.append(URLQueryItem(name: "filters[$or][0][title][$containsi]", value: query))
      queryItems.append(URLQueryItem(name: "filters[$or][1][proposalId][$containsi]", value: query))
    }
    components.queryItems = queryItems
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }
}

// MARK: - Strapi REST → domain

/// Strapi REST の `data` 配列を `SwiftEvolution` に変換する。
/// `attributes` ネスト（Strapi v4）とフラットなエントリ（Strapi v5 系の一部構成）の両方を受け付ける。
enum StrapiProposalPayload {
  private struct ListEnvelope: Decodable {
    let data: [StrapiItem]
  }

  private struct StrapiItem: Decodable {
    let id: Int?
    let documentId: String?
    let proposalFields: ProposalFields

    enum CodingKeys: String, CodingKey {
      case id
      case documentId
      case attributes
    }

    private static func decodeOptionalNumericId(from container: KeyedDecodingContainer<CodingKeys>)
      -> Int?
    {
      if let intValue = try? container.decode(Int.self, forKey: .id) {
        return intValue
      }
      if let stringValue = try? container.decode(String.self, forKey: .id), let intValue = Int(stringValue) {
        return intValue
      }
      return nil
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = Self.decodeOptionalNumericId(from: container)
      documentId = try container.decodeIfPresent(String.self, forKey: .documentId)
      if let nested = try container.decodeIfPresent(ProposalFields.self, forKey: .attributes) {
        proposalFields = nested
      } else {
        proposalFields = try ProposalFields(from: decoder)
      }
    }

    func swiftEvolution() -> SwiftEvolution {
      let stableId = documentId ?? String(id ?? 0)
      let fields = proposalFields
      return SwiftEvolution(
        id: stableId,
        proposalId: fields.proposalId,
        title: fields.title,
        reviewManager: fields.reviewManager,
        status: fields.status,
        authors: fields.authors,
        content: fields.content
      )
    }
  }

  private struct ProposalFields: Decodable {
    let proposalId: String
    let title: String
    let reviewManager: String?
    let status: String?
    let authors: String
    let content: String
  }

  static func decodeProposals(from data: Data) throws -> [SwiftEvolution] {
    let envelope = try JSONDecoder().decode(ListEnvelope.self, from: data)
    return envelope.data.map { $0.swiftEvolution() }
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
