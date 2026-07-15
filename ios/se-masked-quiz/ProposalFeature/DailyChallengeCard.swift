//
//  DailyChallengeCard.swift
//  se-masked-quiz
//
//  ホーム（提案一覧）の先頭に表示する「今日のチャレンジ」カード。
//  習慣ループの起点：ストリーク（投資）の可視化と、今日解くべき提案（行動）への導線。
//

import SwiftUI

struct DailyChallengeCard: View {
  @Environment(\.streakRepository) private var streakRepository

  let proposal: SwiftEvolution

  @State private var streak: StreakRecord = .empty

  private var isDoneToday: Bool {
    streak.isActive(on: Date())
  }

  var body: some View {
    HStack(spacing: 14) {
      streakBadge

      VStack(alignment: .leading, spacing: 4) {
        Text("今日のチャレンジ")
          .font(AppFont.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        MarkdownText(proposal.title)
          .font(AppFont.headline)
          .lineLimit(2)

        Text(proposal.displayId)
          .font(AppFont.caption)
          .foregroundStyle(.secondary)

        if isDoneToday {
          Label("今日は達成済み", systemImage: "checkmark.circle.fill")
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(SemanticColor.correct)
        } else {
          Label("タップして挑戦", systemImage: "play.circle.fill")
            .font(AppFont.caption.weight(.semibold))
            .foregroundStyle(.tint)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.vertical, 6)
    .task(id: proposal.id) {
      streak = await streakRepository.getStreak()
    }
    .onAppear {
      Task { streak = await streakRepository.getStreak() }
    }
  }

  private var streakBadge: some View {
    VStack(spacing: 2) {
      Image(systemName: "flame.fill")
        .font(.title2)
        .foregroundStyle(
          streak.currentStreak > 0
            ? AnyShapeStyle(SemanticColor.streak) : AnyShapeStyle(.secondary))
      Text("\(streak.currentStreak)")
        .font(AppFont.title)
        .monospacedDigit()
      Text("日連続")
        .font(AppFont.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(width: 56)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("連続学習\(streak.currentStreak)日")
  }
}
