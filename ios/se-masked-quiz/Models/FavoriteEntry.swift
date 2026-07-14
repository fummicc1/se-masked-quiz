//
//  FavoriteEntry.swift
//  se-masked-quiz
//
//  お気に入り登録された提案を表す。proposalId は SE/ST 間で衝突しうる
//  bare 4桁のため、track を保持して個別に区別する。
//

import Foundation

struct FavoriteEntry: Codable, Equatable, Sendable, Identifiable {
  var id: String { "\(track.rawValue)_\(proposalId)" }

  let proposalId: String
  let track: ProposalTrack
  let addedAt: Date
}
