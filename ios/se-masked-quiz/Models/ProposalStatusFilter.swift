//
//  ProposalStatusFilter.swift
//  se-masked-quiz
//
//  一覧画面のステータス絞り込み条件。Payload REST の where クエリへ写像する。
//  キーワードは ProposalStatus.parse の判定基準と対応を保つこと。
//

import Foundation

enum ProposalStatusFilter: String, CaseIterable, Sendable, Hashable {
  case all
  case implemented
  case partiallyImplemented
  case accepted
  case activeReview
  case previewing
  case returned
  case rejected
  case withdrawn

  /// メニュー表示用ラベル。一覧バッジ（ProposalStatus.label）の表記と揃える。
  /// switch にすると case 数で循環的複雑度が閾値(10)を超えるため辞書で引く
  var label: String {
    Self.labels[self] ?? ""
  }

  private static let labels: [ProposalStatusFilter: String] = [
    .all: "すべて",
    .implemented: "Implemented",
    .partiallyImplemented: "Partially Implemented",
    .accepted: "Accepted",
    .activeReview: "Active Review",
    .previewing: "Previewing",
    .returned: "Returned",
    .rejected: "Rejected",
    .withdrawn: "Withdrawn",
  ]

  /// Payload REST の where[and][N]... に載せる条件を組み立てる。
  /// status はMarkdown混じりの自由文字列のため contains ベースで照合する。
  func queryItems(startingAndIndex: Int) -> [URLQueryItem] {
    switch self {
    case .all:
      return []
    case .implemented:
      // "Partially implemented" も "implemented" を含むため not_like で除外する
      return [
        URLQueryItem(
          name: "where[and][\(startingAndIndex)][status][contains]", value: "implemented"),
        URLQueryItem(
          name: "where[and][\(startingAndIndex + 1)][status][not_like]", value: "partially"),
      ]
    case .withdrawn:
      // ProposalStatus.parse と同様に "expired" も Withdrawn として扱う
      return [
        URLQueryItem(
          name: "where[and][\(startingAndIndex)][or][0][status][contains]", value: "withdrawn"),
        URLQueryItem(
          name: "where[and][\(startingAndIndex)][or][1][status][contains]", value: "expired"),
      ]
    default:
      return [
        URLQueryItem(
          name: "where[and][\(startingAndIndex)][status][contains]", value: containsKeyword)
      ]
    }
  }

  /// 単一 contains で照合できる case のキーワード
  private var containsKeyword: String {
    switch self {
    case .partiallyImplemented: return "partially"
    case .accepted: return "accepted"
    case .activeReview: return "active review"
    case .previewing: return "previewing"
    case .returned: return "returned"
    case .rejected: return "rejected"
    default: return ""
    }
  }
}
