//
//  DependencyGraphRoute.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/27.
//

import Foundation

/// 依存グラフ画面への遷移値。NavigationStack の value-based 遷移で使う。
struct DependencyGraphRoute: Hashable {
  let rootProposalId: String
  let rootTitle: String
}
