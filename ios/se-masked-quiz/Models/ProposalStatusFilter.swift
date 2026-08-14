//
//  ProposalStatusFilter.swift
//  se-masked-quiz
//
//  一覧のステータス絞り込み条件。
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

  func queryItems(startingAndIndex: Int) -> [URLQueryItem] {
    switch self {
    case .all:
      return []
    case .implemented:
      return [
        URLQueryItem(
          name: "where[and][\(startingAndIndex)][status][contains]", value: "implemented"),
        URLQueryItem(
          name: "where[and][\(startingAndIndex + 1)][status][not_like]", value: "partially"),
      ]
    case .withdrawn:
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
