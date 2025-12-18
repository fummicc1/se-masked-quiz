//
//  ReviewDashboardView.swift
//  se-masked-quiz
//
//  Created for Issue #12: SRS Review Dashboard
//

import SwiftUI
import Charts

/// SRS復習ダッシュボード
struct ReviewDashboardView: View {
  @Environment(\.srsScheduler) private var srsScheduler
  @State private var reviewStats: ReviewStats?
  @State private var dailyQueue: DailyReviewQueue?
  @State private var isLoading = true
  @State private var error: Error?

  let proposalId: String

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if isLoading {
          ProgressView("読み込み中...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = error {
          ErrorView(error: error)
        } else {
          if let stats = reviewStats {
            OverviewSection(stats: stats)
            MasteryChartSection(stats: stats)
            UpcomingReviewsSection(stats: stats, queue: dailyQueue)
          } else {
            EmptyStateView()
          }
        }
      }
      .padding()
    }
    .navigationTitle("復習状況")
    .task {
      await loadData()
    }
    .refreshable {
      await loadData()
    }
  }

  private func loadData() async {
    isLoading = true
    error = nil

    do {
      async let statsTask = srsScheduler.getReviewStats(for: proposalId)
      async let queueTask = srsScheduler.generateDailyQueue(for: proposalId)

      let (loadedStats, loadedQueue) = try await (statsTask, queueTask)

      reviewStats = loadedStats
      dailyQueue = loadedQueue
    } catch {
      self.error = error
    }

    isLoading = false
  }
}

// MARK: - Overview Section

private struct OverviewSection: View {
  let stats: ReviewStats

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("概要")
        .font(.headline)

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
      ], spacing: 12) {
        StatCard(
          title: "総復習回数",
          value: "\(stats.totalReviews)",
          icon: "repeat",
          color: .blue
        )

        StatCard(
          title: "習熟度",
          value: String(format: "%.0f%%", stats.masteryScore),
          icon: "star.fill",
          color: .yellow
        )

        StatCard(
          title: "期限切れ",
          value: "\(stats.overdueCount)",
          icon: "exclamationmark.triangle.fill",
          color: stats.overdueCount > 0 ? .red : .green
        )

        StatCard(
          title: "今日の復習",
          value: "\(stats.dueTodayCount)",
          icon: "calendar",
          color: .orange
        )
      }
    }
  }
}

// MARK: - Mastery Chart Section

private struct MasteryChartSection: View {
  let stats: ReviewStats

  private var chartData: [(MasteryLevel, Int)] {
    MasteryLevel.allCases.map { level in
      (level, stats.masteryLevelCounts[level] ?? 0)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("習熟度分布")
        .font(.headline)

      if chartData.allSatisfy({ $0.1 == 0 }) {
        Text("まだデータがありません")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        Chart(chartData, id: \.0) { level, count in
          BarMark(
            x: .value("習熟度", level.rawValue),
            y: .value("問題数", count)
          )
          .foregroundStyle(by: .value("レベル", level.rawValue))
        }
        .frame(height: 200)
        .chartForegroundStyleScale([
          MasteryLevel.learning.rawValue: Color.red,
          MasteryLevel.reviewing.rawValue: Color.orange,
          MasteryLevel.familiar.rawValue: Color.blue,
          MasteryLevel.mastered.rawValue: Color.green,
        ])
      }
    }
  }
}

// MARK: - Upcoming Reviews Section

private struct UpcomingReviewsSection: View {
  let stats: ReviewStats
  let queue: DailyReviewQueue?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("今後の予定")
        .font(.headline)

      if let queue = queue, queue.totalCount > 0 {
        VStack(spacing: 8) {
          if !queue.reviewItems.isEmpty {
            HStack {
              Image(systemName: "repeat")
                .foregroundStyle(.orange)
              Text("復習: \(queue.reviewItems.count)問")
              Spacer()
            }
          }

          if !queue.newItems.isEmpty {
            HStack {
              Image(systemName: "sparkles")
                .foregroundStyle(.blue)
              Text("新規: \(queue.newItems.count)問")
              Spacer()
            }
          }

          if let nextReview = stats.nextReviewDate {
            HStack {
              Image(systemName: "clock")
                .foregroundStyle(.green)
              Text("次回復習: \(nextReview.formatted(date: .abbreviated, time: .shortened))")
              Spacer()
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
      } else {
        Text("今日の復習はありません")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      }
    }
  }
}

// MARK: - Supporting Views

private struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(color)
        Spacer()
      }

      Text(value)
        .font(.title2)
        .fontWeight(.bold)

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

private struct ErrorView: View {
  let error: Error

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.largeTitle)
        .foregroundStyle(.red)

      Text("エラーが発生しました")
        .font(.headline)

      Text(error.localizedDescription)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

private struct EmptyStateView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "book.closed")
        .font(.largeTitle)
        .foregroundStyle(.gray)

      Text("復習データがありません")
        .font(.headline)

      Text("クイズに回答すると、復習データが記録されます。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

// MARK: - MasteryLevel Extension

extension MasteryLevel: CaseIterable {
  static var allCases: [MasteryLevel] {
    [.learning, .reviewing, .familiar, .mastered]
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ReviewDashboardView(proposalId: "SE-0296")
  }
}
