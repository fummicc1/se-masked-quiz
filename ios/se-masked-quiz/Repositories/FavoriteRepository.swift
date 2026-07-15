//
//  FavoriteRepository.swift
//  se-masked-quiz
//
//  お気に入り登録の記録・判定を担うリポジトリ。SE/ST を横断して一覧表示する要件のため、
//  QuizRepository のような track 別 namespace 分割ではなく単一リストで一元管理する。
//

import Foundation
import SwiftUI

// MARK: - Repository Protocol

/// @mockable
protocol FavoriteRepository: Actor, Sendable {
  /// お気に入り状態をトグルし、トグル後の状態（true = 追加済み）を返す
  func toggle(proposalId: String, track: ProposalTrack) async -> Bool

  /// 指定の提案がお気に入り済みか
  func isFavorite(proposalId: String, track: ProposalTrack) async -> Bool

  /// 全お気に入りエントリを取得
  func getAllFavorites() async -> [FavoriteEntry]
}

// MARK: - Repository Implementation

actor FavoriteRepositoryImpl: FavoriteRepository {
  private let userDefaults: UserDefaults

  private static let favoritesKey = "favorite_entries"

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func toggle(proposalId: String, track: ProposalTrack) async -> Bool {
    var entries = loadEntries()
    if let index = entries.firstIndex(where: {
      $0.proposalId == proposalId && $0.track == track
    }) {
      entries.remove(at: index)
      saveEntries(entries)
      return false
    } else {
      entries.append(FavoriteEntry(proposalId: proposalId, track: track, addedAt: Date()))
      saveEntries(entries)
      return true
    }
  }

  func isFavorite(proposalId: String, track: ProposalTrack) async -> Bool {
    loadEntries().contains { $0.proposalId == proposalId && $0.track == track }
  }

  func getAllFavorites() async -> [FavoriteEntry] {
    loadEntries()
  }

  // MARK: - Private Helpers

  private func loadEntries() -> [FavoriteEntry] {
    guard let data = userDefaults.data(forKey: Self.favoritesKey),
      let entries = try? JSONDecoder().decode([FavoriteEntry].self, from: data)
    else {
      return []
    }
    return entries
  }

  private func saveEntries(_ entries: [FavoriteEntry]) {
    if let encoded = try? JSONEncoder().encode(entries) {
      userDefaults.set(encoded, forKey: Self.favoritesKey)
    }
  }
}

// MARK: - Environment

extension FavoriteRepositoryImpl: EnvironmentKey {
  static var defaultValue: any FavoriteRepository {
    FavoriteRepositoryImpl()
  }
}

extension EnvironmentValues {
  var favoriteRepository: any FavoriteRepository {
    get { self[FavoriteRepositoryImpl.self] }
    set { self[FavoriteRepositoryImpl.self] = newValue }
  }
}
