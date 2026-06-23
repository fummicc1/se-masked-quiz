//
//  DailyChallengeService.swift
//  se-masked-quiz
//
//  「今日のチャレンジ」となる提案を、日付から決定論的に選ぶ純粋ロジック。
//  サーバ不要・オフライン可・テスト容易（同じ日付なら必ず同じ結果）。
//

import Foundation

struct DailyChallengeService: Sendable {
  /// ローテーションの基準日（エポック）
  static let referenceDate = Date(timeIntervalSince1970: 0)

  /// クイズを持つ提案IDの一覧から、その日のチャレンジ対象を返す。
  /// クイズが存在する提案のみを対象にするため、必ず出題可能な提案が選ばれる。
  /// - Parameters:
  ///   - quizzedProposalIds: クイズ（穴埋め）が存在する提案IDの集合
  ///   - date: 対象日
  func todaysProposalId(
    from quizzedProposalIds: [String],
    date: Date,
    calendar: Calendar = .current
  ) -> String? {
    let sorted = quizzedProposalIds.sorted()
    guard !sorted.isEmpty else { return nil }
    let dayIndex = dayNumber(for: date, calendar: calendar)
    // 負の経過日数でも正のインデックスになるよう補正
    let index = ((dayIndex % sorted.count) + sorted.count) % sorted.count
    return sorted[index]
  }

  /// 基準日からの経過日数
  func dayNumber(for date: Date, calendar: Calendar = .current) -> Int {
    let start = calendar.startOfDay(for: Self.referenceDate)
    let day = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: start, to: day).day ?? 0
  }
}
