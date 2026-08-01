//
//  StreakStatsScreen.swift
//  se-masked-quiz
//
//  デイリーチャレンジの達成状況を俯瞰する統計画面。
//  現在/最長ストリーク・総学習日数・正答率のサマリと、直近7日/180日の学習履歴を可視化する。
//

import SwiftUI

struct StreakStatsScreen: View {
  @Environment(\.streakRepository) private var streakRepository
  @Environment(\.quizRepository) private var quizRepository
  @Environment(\.testingQuizRepository) private var testingQuizRepository

  @State private var streak: StreakRecord = .empty
  @State private var accuracy: QuizAccuracyAggregator.Result?

  private let calendar = Calendar.current

  var body: some View {
    List {
      Section {
        statsGrid
      }
      Section("直近7日") {
        weekDots
          .padding(.vertical, 4)
      }
      Section("学習の記録（直近180日）") {
        activityGrid
          .padding(.vertical, 4)
      }
    }
    .navigationTitle("ストリーク統計")
    .task {
      await loadData()
    }
  }

  // MARK: - Stats Grid

  private var statsGrid: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      StatTile(
        title: "現在のストリーク", value: "\(streak.currentStreak)日", icon: "flame.fill",
        color: AppColor.brand)
      StatTile(
        title: "最長ストリーク", value: "\(streak.longestStreak)日", icon: "trophy.fill", color: .yellow)
      StatTile(
        title: "総学習日数", value: "\(streak.totalActiveDays)日", icon: "calendar", color: .blue)
      StatTile(
        title: "正答率", value: accuracyText, icon: "checkmark.seal.fill", color: SemanticColor.correct)
    }
    .listRowInsets(EdgeInsets())
    .listRowBackground(Color.clear)
  }

  private var accuracyText: String {
    guard let percentage = accuracy?.accuracyPercentage else { return "―" }
    return "\(Int(percentage))%"
  }

  // MARK: - Week Dots

  private var last7Days: [Date] {
    recentDays(count: 7)
  }

  private var weekDots: some View {
    HStack(spacing: 12) {
      ForEach(last7Days, id: \.self) { day in
        VStack(spacing: 4) {
          Circle()
            .fill(isActive(on: day) ? SemanticColor.correct : Color.secondary.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay {
              if calendar.isDateInToday(day) {
                Circle().strokeBorder(AppColor.brand, lineWidth: 2)
              }
            }
          Text(weekdaySymbol(for: day))
            .font(AppFont.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(weekdaySymbol(for: day))曜日 \(isActive(on: day) ? "達成" : "未達成")")
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Activity Grid

  private var last180Days: [Date] {
    recentDays(count: StreakRecord.activeDaysRetentionDays)
  }

  private var activityGrid: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHGrid(
        rows: Array(repeating: GridItem(.fixed(12), spacing: 3), count: 7),
        spacing: 3
      ) {
        ForEach(last180Days, id: \.self) { day in
          RoundedRectangle(cornerRadius: 2)
            .fill(isActive(on: day) ? SemanticColor.correct : Color.secondary.opacity(0.15))
            .frame(width: 12, height: 12)
        }
      }
      .padding(.vertical, 2)
    }
  }

  // MARK: - Helpers

  private var activeDaySet: Set<Date> {
    Set(streak.activeDays.map { calendar.startOfDay(for: $0) })
  }

  private func isActive(on day: Date) -> Bool {
    activeDaySet.contains(calendar.startOfDay(for: day))
  }

  private func recentDays(count: Int) -> [Date] {
    let today = calendar.startOfDay(for: Date())
    return (0..<count).reversed().compactMap { offset in
      calendar.date(byAdding: .day, value: -offset, to: today)
    }
  }

  private func weekdaySymbol(for date: Date) -> String {
    let weekdayIndex = calendar.component(.weekday, from: date) - 1
    return calendar.veryShortWeekdaySymbols[weekdayIndex]
  }

  private func loadData() async {
    streak = await streakRepository.getStreak()
    let seScores = await quizRepository.getAllScores()
    let stScores = await testingQuizRepository.getAllScores()
    accuracy = QuizAccuracyAggregator().aggregate(scoresByTrack: [seScores, stScores])
  }
}

#Preview {
  NavigationStack {
    StreakStatsScreen()
  }
}
