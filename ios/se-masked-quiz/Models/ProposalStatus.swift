//
//  ProposalStatus.swift
//  se-masked-quiz
//
//  提案のstatus（Markdown文字列、例: "**Implemented (Swift 5.9)**"）を
//  バッジ表示用のカテゴリ・短ラベル・色へ写像する。
//

import SwiftUI

enum ProposalStatus: Equatable, Sendable {
  case implemented(version: String?)
  case partiallyImplemented
  case accepted
  case activeReview
  case previewing
  case returned
  case rejected
  case withdrawn
  case unknown(text: String)

  /// Markdown装飾・括弧書き・リンクを除いた本文で判定する。
  /// "Partially implemented" が "implemented" を含む等の包含関係があるため判定順序を変えないこと。
  static func parse(_ raw: String?) -> ProposalStatus {
    guard let raw else { return .unknown(text: "") }
    let cleaned = cleanedText(raw)
    let lowered = cleaned.lowercased()
    let rules: [(keywords: [String], status: ProposalStatus)] = [
      (["partially"], .partiallyImplemented),
      (["implemented"], .implemented(version: swiftVersion(in: raw))),
      (["accepted"], .accepted),
      (["active review"], .activeReview),
      (["previewing"], .previewing),
      (["rejected"], .rejected),
      (["returned"], .returned),
      (["withdrawn", "expired"], .withdrawn),
    ]
    for rule in rules where rule.keywords.contains(where: lowered.contains) {
      return rule.status
    }
    return .unknown(text: cleaned)
  }

  var label: String {
    switch self {
    case .implemented(let version): return Self.implementedLabel(version)
    case .unknown(let text): return text
    default: return simpleLabel
    }
  }

  private static func implementedLabel(_ version: String?) -> String {
    version.map { "Swift \($0)" } ?? "Implemented"
  }

  /// 連想値を持たないcaseの固定ラベル。1つのswitchに全caseを並べると
  /// 循環的複雑度が閾値(10)を超えるため label から分割している
  private var simpleLabel: String {
    switch self {
    case .partiallyImplemented: return "Partially Implemented"
    case .accepted: return "Accepted"
    case .activeReview: return "Active Review"
    case .previewing: return "Previewing"
    case .returned: return "Returned"
    case .rejected: return "Rejected"
    case .withdrawn: return "Withdrawn"
    default: return ""
    }
  }

  var color: Color {
    switch self {
    case .implemented: return SemanticColor.correct
    case .partiallyImplemented, .accepted: return SemanticColor.inProgress
    case .activeReview, .previewing, .returned: return SemanticColor.warning
    case .rejected: return SemanticColor.incorrect
    case .withdrawn, .unknown: return SemanticColor.neutral
    }
  }

  /// "**" 装飾を除き、最初の "(" / "[" 以降（レビュー期間・Rationaleリンク等）を落とす
  private static func cleanedText(_ raw: String) -> String {
    var text = raw.replacingOccurrences(of: "**", with: "")
    if let cutIndex = text.firstIndex(where: { $0 == "(" || $0 == "[" }) {
      text = String(text[..<cutIndex])
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func swiftVersion(in raw: String) -> String? {
    guard let match = raw.firstMatch(of: /\(Swift ([0-9][0-9.]*)\)/) else { return nil }
    return String(match.1)
  }
}
