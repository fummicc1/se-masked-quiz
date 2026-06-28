//
//  ProposalTrack.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/28.
//

import Foundation

/// 提案のトラック。Swift Evolution(SE) と Swift Testing(ST) を区別する。
///
/// バックエンドではトラックごとに別コレクション/エンドポイントに分かれており、proposalId は
/// 各テーブル内で bare 4桁。`SE-`/`ST-` 接頭辞は表示専用で、取得元トラックから付与する。
enum ProposalTrack: String, Sendable, Codable, Hashable, CaseIterable {
  case swiftEvolution
  case swiftTesting

  /// 表示用の接頭辞（例: SE / ST）。
  var displayPrefix: String {
    switch self {
    case .swiftEvolution: return "SE"
    case .swiftTesting: return "ST"
    }
  }

  /// タブ等に出すトラック名。
  var title: String {
    switch self {
    case .swiftEvolution: return "Swift Evolution"
    case .swiftTesting: return "Swift Testing"
    }
  }

  /// Payload の proposals 系エンドポイントの slug。
  var proposalsSlug: String {
    switch self {
    case .swiftEvolution: return "proposals"
    case .swiftTesting: return "testing-proposals"
    }
  }

  /// Payload の quiz-answers 系エンドポイントの slug。
  var quizAnswersSlug: String {
    switch self {
    case .swiftEvolution: return "quiz-answers"
    case .swiftTesting: return "testing-quiz-answers"
    }
  }

  /// ローカル保存(UserDefaults)キーの名前空間。SE は従来キーのまま、ST は接頭辞で分離する。
  var storageNamespace: String {
    switch self {
    case .swiftEvolution: return ""
    case .swiftTesting: return "testing_"
    }
  }
}
