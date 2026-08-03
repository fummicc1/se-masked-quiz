//
//  DependencyGraphModels.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/27.
//

import Foundation

/// グラフのノード（提案）。`hop` は root からの距離（0 = root）。
struct GraphNode: Identifiable, Hashable {
  let id: String  // proposalId
  let title: String
  let hop: Int
}

/// 有向エッジ（from が to を参照する）。
struct GraphEdge: Hashable {
  let from: String
  let to: String
}

/// proposalId → 画面座標（中心を原点とした相対座標）。
struct GraphLayout {
  var positions: [String: CGPoint]
}

/// root を中心に置き、hop k のノードを半径 k·ringSpacing の同心円上へ等間隔配置する決定論レイアウト。
///
/// ノード数がリング周長に対して多い場合はノードチップ同士が重なって読めなくなるため、
/// 弧長が `minArcSpacing` を下回らないよう半径を広げ、さらに偶奇 index で内外リングへ
/// 振り分けて（スタッガー）角密度を実質半分にする。混雑していないリングは従来配置のまま。
enum RadialLayout {
  static func compute(
    nodes: [GraphNode],
    center: CGPoint,
    ringSpacing: CGFloat,
    minArcSpacing: CGFloat = 100,
    staggerOffset: CGFloat = 60
  ) -> GraphLayout {
    var positions: [String: CGPoint] = [:]
    let byHop = Dictionary(grouping: nodes, by: \.hop)
    for (hop, group) in byHop {
      if hop == 0 {
        if let root = group.first {
          positions[root.id] = center
        }
        continue
      }
      let baseRadius = CGFloat(hop) * ringSpacing
      let sorted = group.sorted { $0.id < $1.id }
      let count = max(sorted.count, 1)
      let requiredRadius = CGFloat(count) * minArcSpacing / (2 * .pi)
      let isCrowded = requiredRadius > baseRadius
      let radius = max(baseRadius, requiredRadius)
      for (index, node) in sorted.enumerated() {
        let theta = (2 * CGFloat.pi / CGFloat(count)) * CGFloat(index) - CGFloat.pi / 2
        let staggeredRadius =
          isCrowded
          ? radius + (index.isMultiple(of: 2) ? -staggerOffset / 2 : staggerOffset / 2)
          : radius
        positions[node.id] = CGPoint(
          x: center.x + staggeredRadius * cos(theta),
          y: center.y + staggeredRadius * sin(theta)
        )
      }
    }
    return GraphLayout(positions: positions)
  }
}
