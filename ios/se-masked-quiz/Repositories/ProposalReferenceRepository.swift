//
//  ProposalReferenceRepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/27.
//

import Foundation
import SwiftUI

/// proposal-references コレクションの1辺（from が to を参照する有向エッジ）。
struct PayloadReference: Decodable, Sendable, Hashable {
  let fromProposalId: String
  let toProposalId: String
}

/// proposal 間の依存（参照）エッジを取得するリポジトリ。
/// 順方向（from 起点）＝前提提案・グラフ outgoing、逆方向（to 起点）＝影響範囲。
struct ProposalReferenceRepository: Sendable {
  private static let fetchLimit = 1000

  /// 指定した proposal 群が「参照している」エッジ（outgoing）を取得する。
  func fetchOutgoing(fromProposalIds ids: [String]) async throws -> [PayloadReference] {
    try await fetch(field: "fromProposalId", ids: ids)
  }

  /// 指定した proposal 群を「参照している」エッジ（incoming）を取得する。
  func fetchIncoming(toProposalIds ids: [String]) async throws -> [PayloadReference] {
    try await fetch(field: "toProposalId", ids: ids)
  }

  private func fetch(field: String, ids: [String]) async throws -> [PayloadReference] {
    guard !ids.isEmpty else { return [] }
    var result: [PayloadReference] = []
    for chunk in PayloadHTTP.chunked(ids, size: 50) {
      let url = try Self.referencesURL(baseURL: Env.serverBaseURL, field: field, ids: chunk)
      let decoded: PayloadListResponse<PayloadReference> = try await PayloadHTTP.get(url)
      result.append(contentsOf: decoded.docs)
    }
    return result
  }

  static func referencesURL(baseURL: String, field: String, ids: [String]) throws -> URL {
    var components = try PayloadHTTP.components(baseURL: baseURL, path: "/api/proposal-references")
    components.queryItems = [
      URLQueryItem(name: "where[\(field)][in]", value: ids.joined(separator: ",")),
      URLQueryItem(name: "limit", value: String(fetchLimit)),
    ]
    guard let url = components.url else {
      throw SERepositoryError.invalidBaseURL
    }
    return url
  }
}

extension ProposalReferenceRepository: EnvironmentKey {
  static var defaultValue: Self {
    ProposalReferenceRepository()
  }
}

extension EnvironmentValues {
  var referenceRepository: ProposalReferenceRepository {
    get { self[ProposalReferenceRepository.self] }
    set { self[ProposalReferenceRepository.self] = newValue }
  }
}
