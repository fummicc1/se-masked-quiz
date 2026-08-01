import Foundation
import Testing
@testable import se_masked_quiz

@MainActor
@Suite("DependencyGraphViewModel / BFS + layout")
struct DependencyGraphViewModelTests {

  /// メモリ上の隣接リストでエッジ/ノード取得を差し替えた ViewModel を作る。
  private func makeViewModel(
    adjacency: [String: [String]],
    titles: [String: String],
    maxHops: Int = 1,
    maxNodes: Int = 40
  ) -> DependencyGraphViewModel {
    DependencyGraphViewModel(
      maxHops: maxHops,
      maxNodes: maxNodes,
      outgoingFetch: { ids in
        ids.flatMap { from in (adjacency[from] ?? []).map { GraphEdge(from: from, to: $0) } }
      },
      nodeFetch: { ids in
        ids.map { GraphProposalNode(proposalId: $0, title: titles[$0] ?? "SE-\($0)") }
      }
    )
  }

  @Test("hop1: root の参照先がノードとエッジになる")
  func hop1() async {
    let viewModel = makeViewModel(
      adjacency: ["0304": ["0296", "0306"]],
      titles: ["0296": "Async", "0306": "Actors"]
    )
    await viewModel.load(rootProposalId: "0304", rootTitle: "Structured Concurrency")
    #expect(Set(viewModel.nodes.map(\.id)) == ["0304", "0296", "0306"])
    #expect(viewModel.edges.count == 2)
    #expect(viewModel.nodes.first { $0.id == "0304" }?.hop == 0)
    #expect(viewModel.nodes.first { $0.id == "0296" }?.hop == 1)
  }

  @Test("循環参照でも有限のノード集合になり、両方向エッジを保持する")
  func cycle() async {
    let viewModel = makeViewModel(
      adjacency: ["A": ["B"], "B": ["A"]],
      titles: ["A": "a", "B": "b"],
      maxHops: 3
    )
    await viewModel.load(rootProposalId: "A", rootTitle: "a")
    #expect(Set(viewModel.nodes.map(\.id)) == ["A", "B"])
    #expect(viewModel.edges.contains(GraphEdge(from: "A", to: "B")))
    #expect(viewModel.edges.contains(GraphEdge(from: "B", to: "A")))
  }

  @Test("参照が無い場合は root ノードのみ")
  func emptyNeighborhood() async {
    let viewModel = makeViewModel(adjacency: ["X": []], titles: [:])
    await viewModel.load(rootProposalId: "X", rootTitle: "x")
    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.edges.isEmpty)
  }

  @Test("maxNodes でノード数が制限される")
  func nodeCap() async {
    let many = (1 ... 100).map { String(format: "%04d", $0) }
    let viewModel = makeViewModel(
      adjacency: ["0000": many],
      titles: [:],
      maxHops: 1,
      maxNodes: 10
    )
    await viewModel.load(rootProposalId: "0000", rootTitle: "root")
    #expect(viewModel.nodes.count <= 10)
  }

  @Test("RadialLayout: root は中心、hop1 ノードは半径 ringSpacing 上に並ぶ")
  func radialLayout() throws {
    let nodes = [
      GraphNode(id: "R", title: "r", hop: 0),
      GraphNode(id: "A", title: "a", hop: 1),
      GraphNode(id: "B", title: "b", hop: 1),
    ]
    let layout = RadialLayout.compute(nodes: nodes, center: .zero, ringSpacing: 100)
    #expect(layout.positions["R"] == .zero)
    let a = try #require(layout.positions["A"])
    let b = try #require(layout.positions["B"])
    #expect(abs(hypot(a.x, a.y) - 100) < 0.0001)
    #expect(abs(hypot(b.x, b.y) - 100) < 0.0001)
  }

  /// maxNodes 上限近くまでノードが集まったリング（root + 39ノード）を作る。
  private func crowdedNodes() -> [GraphNode] {
    [GraphNode(id: "R", title: "r", hop: 0)]
      + (1 ... 39).map { GraphNode(id: String(format: "%04d", $0), title: "n\($0)", hop: 1) }
  }

  @Test("RadialLayout: 混雑リングは半径が広がり、隣接ノードが重ならない距離を保つ")
  func radialLayoutCrowded() throws {
    let layout = RadialLayout.compute(nodes: crowdedNodes(), center: .zero, ringSpacing: 160)
    #expect(layout.positions["R"] == .zero)

    let first = try #require(layout.positions["0001"])
    #expect(hypot(first.x, first.y) > 160)

    let ids = (1 ... 39).map { String(format: "%04d", $0) }
    for index in 0 ..< (ids.count - 1) {
      let a = try #require(layout.positions[ids[index]])
      let b = try #require(layout.positions[ids[index + 1]])
      #expect(hypot(a.x - b.x, a.y - b.y) >= 60)
    }
  }

  @Test("RadialLayout: 入力順に依存せず同一レイアウトになる（決定論）")
  func radialLayoutDeterministic() {
    let nodes = crowdedNodes()
    let a = RadialLayout.compute(nodes: nodes, center: .zero, ringSpacing: 160)
    let b = RadialLayout.compute(nodes: nodes.shuffled(), center: .zero, ringSpacing: 160)
    #expect(a.positions == b.positions)
  }
}
