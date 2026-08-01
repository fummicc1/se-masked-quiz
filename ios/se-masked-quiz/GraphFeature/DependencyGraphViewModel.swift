//
//  DependencyGraphViewModel.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/27.
//

import Foundation

/// root 提案からの依存近傍を BFS で読み込み、放射状レイアウトを計算する。
///
/// エッジ取得とノード（title）取得をクロージャ注入にしているため、ネットワーク無しで単体テストできる。
@MainActor
final class DependencyGraphViewModel: ObservableObject {
  typealias OutgoingFetch = @Sendable ([String]) async throws -> [GraphEdge]
  typealias NodeFetch = @Sendable ([String]) async throws -> [GraphProposalNode]

  @Published private(set) var nodes: [GraphNode] = []
  @Published private(set) var edges: [GraphEdge] = []
  @Published private(set) var layout = GraphLayout(positions: [:])
  @Published private(set) var isLoading = false
  @Published private(set) var loadError: String?

  let maxHops: Int
  let maxNodes: Int
  let ringSpacing: CGFloat
  private let outgoingFetch: OutgoingFetch
  private let nodeFetch: NodeFetch

  init(
    maxHops: Int = 1,
    maxNodes: Int = 40,
    ringSpacing: CGFloat = 160,
    outgoingFetch: @escaping OutgoingFetch = { ids in
      let refs = try await ProposalReferenceRepository().fetchOutgoing(fromProposalIds: ids)
      return refs.map { GraphEdge(from: $0.fromProposalId, to: $0.toProposalId) }
    },
    nodeFetch: @escaping NodeFetch = { ids in
      try await SERepository().fetchGraphNodes(byProposalIds: ids)
    }
  ) {
    self.maxHops = maxHops
    self.maxNodes = maxNodes
    self.ringSpacing = ringSpacing
    self.outgoingFetch = outgoingFetch
    self.nodeFetch = nodeFetch
  }

  func load(rootProposalId: String, rootTitle: String) async {
    isLoading = true
    loadError = nil
    defer { isLoading = false }

    var visited: Set<String> = [rootProposalId]
    var collectedNodes: [GraphNode] = [GraphNode(id: rootProposalId, title: rootTitle, hop: 0)]
    var collectedEdges: Set<GraphEdge> = []
    var frontier: [String] = [rootProposalId]

    do {
      var hop = 1
      while hop <= max(maxHops, 1), !frontier.isEmpty, collectedNodes.count < maxNodes {
        let frontierSet = Set(frontier)
        let outgoing = try await outgoingFetch(frontier)

        // 現フロンティアを起点とするエッジを収集（循環・交差リンクも含む）
        for edge in outgoing where frontierSet.contains(edge.from) {
          collectedEdges.insert(edge)
        }

        let nextIds = outgoing.map(\.to).filter { !visited.contains($0) }
        let batch = Array(Set(nextIds)).sorted()
        guard !batch.isEmpty else { break }

        let fetchedNodes = try await nodeFetch(batch)
        let titleById = Dictionary(
          fetchedNodes.map { ($0.proposalId, $0.title) },
          uniquingKeysWith: { first, _ in first }
        )

        var newFrontier: [String] = []
        for pid in batch {
          guard collectedNodes.count < maxNodes else { break }
          guard !visited.contains(pid) else { continue }
          visited.insert(pid)
          collectedNodes.append(GraphNode(id: pid, title: titleById[pid] ?? "SE-\(pid)", hop: hop))
          newFrontier.append(pid)
        }
        frontier = newFrontier
        hop += 1
      }

      // 両端が実在ノードであるエッジだけ残す（maxNodes で打ち切られた先のエッジを除外）
      let nodeIds = Set(collectedNodes.map(\.id))
      let prunedEdges = collectedEdges.filter { nodeIds.contains($0.from) && nodeIds.contains($0.to) }

      nodes = collectedNodes
      edges = Array(prunedEdges)
      layout = RadialLayout.compute(nodes: collectedNodes, center: .zero, ringSpacing: ringSpacing)
    } catch {
      loadError = error.localizedDescription
    }
  }
}
