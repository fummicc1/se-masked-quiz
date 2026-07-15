//
//  FavoriteButton.swift
//  se-masked-quiz
//
//  提案一覧の各行でお気に入り状態をトグルするボタン。
//  List内でNavigationLinkと並べても開示矢印が重複しないよう、Buttonベースで実装する。
//

import SwiftUI

struct FavoriteButton: View {
  let isFavorite: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
        .foregroundStyle(isFavorite ? AnyShapeStyle(SemanticColor.accent) : AnyShapeStyle(Color.secondary))
        .frame(minWidth: 44, minHeight: 44)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(isFavorite ? "お気に入り解除" : "お気に入りに追加")
  }
}

#Preview("未登録") {
  FavoriteButton(isFavorite: false, action: {})
}

#Preview("登録済み") {
  FavoriteButton(isFavorite: true, action: {})
}
