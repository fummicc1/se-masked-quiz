//
//  FavoritesScreen.swift
//  se-masked-quiz
//
//  お気に入り登録された提案をSE/ST横断で一覧表示する画面。
//

import SwiftUI

/// お気に入り画面への遷移値。NavigationStack の value-based 遷移で使う。
struct FavoritesRoute: Hashable {}

struct FavoritesScreen: View {
  @Environment(\.seRepository) private var repository
  @Environment(\.favoriteRepository) private var favoriteRepository

  @State private var resolvedFavorites: [ResolvedFavorite] = []
  @State private var isLoading = true

  var body: some View {
    List {
      ForEach(resolvedFavorites) { resolved in
        NavigationLink(value: resolved.proposal) {
          VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
              MarkdownText(resolved.proposal.title)
                .font(AppFont.headline)
              Text(resolved.proposal.displayId)
                .font(AppFont.caption)
            }
            MarkdownText(resolved.proposal.authors)
              .font(AppFont.subheadline)
          }
        }
      }
    }
    .overlay {
      if !isLoading && resolvedFavorites.isEmpty {
        ContentUnavailableView(
          "お気に入りはまだありません",
          systemImage: "bookmark",
          description: Text("提案一覧のブックマークアイコンをタップすると、ここに追加されます。")
        )
      }
    }
    .navigationTitle("お気に入り")
    .task {
      await loadFavoriteProposals()
    }
  }

  private func loadFavoriteProposals() async {
    isLoading = true
    defer { isLoading = false }

    let entries = await favoriteRepository.getAllFavorites()
    let resolved = await withTaskGroup(of: ResolvedFavorite?.self) { group in
      for entry in entries {
        group.addTask {
          do {
            guard
              let proposal = try await repository.fetchProposal(
                byProposalId: entry.proposalId, track: entry.track)
            else { return nil }
            return ResolvedFavorite(entry: entry, proposal: proposal)
          } catch {
            // 削除済み提案・一時的なエラー時は静かにスキップし、一覧全体の表示は継続する
            print("Failed to load favorite proposal \(entry.proposalId):", error)
            return nil
          }
        }
      }
      var results: [ResolvedFavorite] = []
      for await item in group {
        if let item {
          results.append(item)
        }
      }
      return results
    }
    resolvedFavorites = resolved.sorted { $0.entry.addedAt > $1.entry.addedAt }
  }
}

private struct ResolvedFavorite: Identifiable {
  let entry: FavoriteEntry
  let proposal: SwiftEvolution
  var id: String { entry.id }
}

#Preview {
  NavigationStack {
    FavoritesScreen()
  }
}
