//
//  SwiftEvolution.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation

struct SwiftEvolution: Sendable, Codable, Identifiable, Hashable {
  var id: String
  var proposalId: String
  var title: String
  // Markdown format
  var reviewManager: String?
  // Markdown format
  var status: String?
  // Markdown format
  var authors: String
  // HTML format
  var content: String
  // 取得元トラック（SE/ST）。表示接頭辞やクイズ取得先の判別に使う。
  var track: ProposalTrack = .swiftEvolution

  /// 表示用ID（例: SE-0001 / ST-0001）。proposalId はトラック内で bare 4桁のため接頭辞をここで付与。
  var displayId: String {
    "\(track.displayPrefix)-\(proposalId)"
  }

  init(
    id: String,
    proposalId: String,
    title: String,
    reviewManager: String?,
    status: String?,
    authors: String,
    content: String,
    track: ProposalTrack = .swiftEvolution
  ) {
    self.id = id
    self.proposalId = proposalId
    self.title = title
    self.reviewManager = reviewManager
    self.status = status
    self.authors = authors
    self.content = content
    self.track = track
  }

  // 旧データ（track キー無し）でも安全にデコードできるよう track は省略可能扱いにする。
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    proposalId = try c.decode(String.self, forKey: .proposalId)
    title = try c.decode(String.self, forKey: .title)
    reviewManager = try c.decodeIfPresent(String.self, forKey: .reviewManager)
    status = try c.decodeIfPresent(String.self, forKey: .status)
    authors = try c.decode(String.self, forKey: .authors)
    content = try c.decode(String.self, forKey: .content)
    track = try c.decodeIfPresent(ProposalTrack.self, forKey: .track) ?? .swiftEvolution
  }
}
