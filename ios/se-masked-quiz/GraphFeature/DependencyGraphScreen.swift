//
//  DependencyGraphScreen.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/06/27.
//

import SwiftUI

/// 選択した提案を中心に、依存（参照）関係の近傍をグラフ表示する画面。
/// ノードをタップして「中心に」（再ルート）または「クイズを開く」を選べる。
struct DependencyGraphScreen: View {
  @Environment(\.seRepository) var seRepository
  @StateObject private var viewModel = DependencyGraphViewModel()

  let rootProposalId: String
  let rootTitle: String

  @State private var scale: CGFloat = 1
  @State private var committedOffset: CGSize = .zero
  @State private var dragOffset: CGSize = .zero
  @State private var selectedNode: GraphNode?
  @State private var selectedProposal: SwiftEvolution?

  var body: some View {
    GeometryReader { proxy in
      let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
      ZStack {
        edgeCanvas(center: center)
        nodeViews(center: center)
      }
      .scaleEffect(scale)
      .offset(
        x: committedOffset.width + dragOffset.width,
        y: committedOffset.height + dragOffset.height
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture()
          .onChanged { dragOffset = $0.translation }
          .onEnded { value in
            committedOffset.width += value.translation.width
            committedOffset.height += value.translation.height
            dragOffset = .zero
          }
      )
      .simultaneousGesture(
        MagnificationGesture().onChanged { scale = min(max(0.5, $0), 2.5) }
      )
      .overlay(alignment: .top) { topBanner }
      .overlay(alignment: .bottom) {
        if let node = selectedNode {
          selectionBar(node)
        }
      }
    }
    .navigationTitle("依存グラフ")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task(id: selectedNode?.id) {
      await loadSelectedProposal()
    }
    .task {
      await viewModel.load(rootProposalId: rootProposalId, rootTitle: rootTitle)
    }
  }

  // MARK: - Subviews

  private func edgeCanvas(center: CGPoint) -> some View {
    Canvas { context, _ in
      for edge in viewModel.edges {
        guard let from = viewModel.layout.positions[edge.from],
          let to = viewModel.layout.positions[edge.to]
        else { continue }
        var path = Path()
        path.move(to: screenPoint(from, center: center))
        path.addLine(to: screenPoint(to, center: center))
        context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
      }
    }
  }

  private func nodeViews(center: CGPoint) -> some View {
    ForEach(viewModel.nodes) { node in
      if let position = viewModel.layout.positions[node.id] {
        NodeChipView(
          node: node,
          isRoot: node.hop == 0,
          isSelected: selectedNode?.id == node.id
        )
        .position(screenPoint(position, center: center))
        .onTapGesture { selectedNode = node }
      }
    }
  }

  @ViewBuilder
  private var topBanner: some View {
    if viewModel.isLoading {
      ProgressView()
        .padding(8)
        .glassCard(cornerRadius: 999)
        .padding(.top, 8)
    } else if viewModel.nodes.count <= 1 {
      Text("この提案が参照している提案はありません")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(8)
        .glassCard(cornerRadius: 999)
        .padding(.top, 8)
    }
  }

  @ViewBuilder
  private func selectionBar(_ node: GraphNode) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Text("#\(Int(node.id) ?? 0)")
          .font(AppFont.caption)
          .bold()
        MarkdownText(node.title)
          .font(AppFont.caption)
          .lineLimit(2)
        Spacer()
      }
      HStack(spacing: 12) {
        if node.id != rootProposalId {
          Button {
            reRoot(to: node)
          } label: {
            Label("中心に", systemImage: "scope")
          }
        }
        Spacer()
        if let proposal = selectedProposal, proposal.proposalId == node.id {
          NavigationLink(value: proposal) {
            Label("クイズを開く", systemImage: "play.fill")
          }
        } else {
          ProgressView()
        }
      }
      .font(AppFont.callout)
    }
    .padding()
    .glassCard()
    .padding()
  }

  // MARK: - Helpers

  private func screenPoint(_ point: CGPoint, center: CGPoint) -> CGPoint {
    CGPoint(x: center.x + point.x, y: center.y + point.y)
  }

  private func reRoot(to node: GraphNode) {
    selectedNode = nil
    selectedProposal = nil
    committedOffset = .zero
    dragOffset = .zero
    scale = 1
    Task { await viewModel.load(rootProposalId: node.id, rootTitle: node.title) }
  }

  private func loadSelectedProposal() async {
    guard let node = selectedNode else {
      selectedProposal = nil
      return
    }
    if selectedProposal?.proposalId == node.id { return }
    selectedProposal = nil
    selectedProposal = try? await seRepository.fetchProposals(byProposalIds: [node.id]).first
  }
}

/// グラフ上の1ノード（提案番号 + 短縮タイトル）。
private struct NodeChipView: View {
  let node: GraphNode
  let isRoot: Bool
  let isSelected: Bool

  @ScaledMetric(relativeTo: .caption2) private var titleFontSize: CGFloat = 9

  var body: some View {
    VStack(spacing: 2) {
      Text("#\(Int(node.id) ?? 0)")
        .font(AppFont.caption2)
        .bold()
      Text(node.title)
        .font(.system(size: titleFontSize))
        .lineLimit(1)
        .frame(maxWidth: 90)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isRoot ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.15))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    )
  }
}
