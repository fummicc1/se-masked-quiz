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
enum RadialLayout {
  static func compute(nodes: [GraphNode], center: CGPoint, ringSpacing: CGFloat) -> GraphLayout {
    var positions: [String: CGPoint] = [:]
    let byHop = Dictionary(grouping: nodes, by: \.hop)
    for (hop, group) in byHop {
      if hop == 0 {
        if let root = group.first {
          positions[root.id] = center
        }
        continue
      }
      let radius = CGFloat(hop) * ringSpacing
      let sorted = group.sorted { $0.id < $1.id }
      let count = max(sorted.count, 1)
      for (index, node) in sorted.enumerated() {
        let theta = (2 * CGFloat.pi / CGFloat(count)) * CGFloat(index) - CGFloat.pi / 2
        positions[node.id] = CGPoint(
          x: center.x + radius * cos(theta),
          y: center.y + radius * sin(theta)
        )
      }
    }
    return GraphLayout(positions: positions)
  }
}
