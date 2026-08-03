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
        edgeCanvas(center: center, selectedId: selectedNode?.id)
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
      .overlay(alignment: .topTrailing) { legendAndReset }
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

  /// エッジを矢印付きで描画する。選択ノードに接続するエッジは後から accent 色で上書きして強調する。
  private func edgeCanvas(center: CGPoint, selectedId: String?) -> some View {
    Canvas { context, _ in
      let highlighted = viewModel.edges.filter {
        $0.from == selectedId || $0.to == selectedId
      }
      let normal = viewModel.edges.filter {
        $0.from != selectedId && $0.to != selectedId
      }
      for edge in normal {
        drawEdge(edge, in: &context, center: center, color: .secondary.opacity(0.35), lineWidth: 1)
      }
      for edge in highlighted {
        drawEdge(edge, in: &context, center: center, color: .accentColor, lineWidth: 2)
      }
    }
  }

  /// from→to の線分と、toノード手前に「参照先（先に読む提案）」方向を示す三角形の矢印を描く。
  private func drawEdge(
    _ edge: GraphEdge,
    in context: inout GraphicsContext,
    center: CGPoint,
    color: Color,
    lineWidth: CGFloat
  ) {
    guard let fromPos = viewModel.layout.positions[edge.from],
      let toPos = viewModel.layout.positions[edge.to]
    else { return }
    let from = screenPoint(fromPos, center: center)
    let to = screenPoint(toPos, center: center)
    let dx = to.x - from.x
    let dy = to.y - from.y
    let length = hypot(dx, dy)
    // ノードチップに矢印が潜り込まないよう手前で止める
    let nodeMargin: CGFloat = 36
    guard length > nodeMargin else { return }
    let ux = dx / length
    let uy = dy / length
    let tip = CGPoint(x: to.x - ux * nodeMargin, y: to.y - uy * nodeMargin)

    var line = Path()
    line.move(to: from)
    line.addLine(to: tip)
    context.stroke(line, with: .color(color), lineWidth: lineWidth)

    let arrowLength: CGFloat = 8
    let arrowHalfWidth: CGFloat = 4.5
    let base = CGPoint(x: tip.x - ux * arrowLength, y: tip.y - uy * arrowLength)
    let perp = CGPoint(x: -uy, y: ux)
    var arrow = Path()
    arrow.move(to: tip)
    arrow.addLine(
      to: CGPoint(x: base.x + perp.x * arrowHalfWidth, y: base.y + perp.y * arrowHalfWidth))
    arrow.addLine(
      to: CGPoint(x: base.x - perp.x * arrowHalfWidth, y: base.y - perp.y * arrowHalfWidth))
    arrow.closeSubpath()
    context.fill(arrow, with: .color(color))
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

  /// 凡例と、パン/ズーム変形時のみ出す表示リセットボタン。
  /// 下部は選択バーと重なるため、まとめて右上に置く。
  private var legendAndReset: some View {
    VStack(alignment: .trailing, spacing: AppSpacing.sm) {
      VStack(alignment: .leading, spacing: AppSpacing.xs) {
        HStack(spacing: AppSpacing.xs) {
          Circle()
            .fill(Color.accentColor)
            .frame(width: 8, height: 8)
          Text("現在の提案")
        }
        HStack(spacing: AppSpacing.xs) {
          Image(systemName: "arrow.right")
          Text("先に読む提案へ")
        }
      }
      .font(AppFont.caption2)
      .foregroundStyle(.secondary)
      .padding(AppSpacing.sm)
      .glassCard(cornerRadius: AppRadius.medium)

      if scale != 1 || committedOffset != .zero {
        Button {
          withAnimation(.snappy) {
            scale = 1
            committedOffset = .zero
            dragOffset = .zero
          }
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .glassCard(cornerRadius: 999)
        .accessibilityLabel("表示をリセット")
      }
    }
    .padding(.top, AppSpacing.sm)
    .padding(.trailing, AppSpacing.md)
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
/// エッジが下を通るため背景は不透明にし、rootはaccent塗り+白文字で最も目立たせる。
private struct NodeChipView: View {
  let node: GraphNode
  let isRoot: Bool
  let isSelected: Bool

  var body: some View {
    VStack(spacing: 2) {
      Text("SE-\(node.id)")
        .font(AppFont.caption2)
        .bold()
      Text(node.title)
        .font(AppFont.caption2)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 120)
    }
    .foregroundStyle(isRoot ? Color.white : Color.primary)
    .padding(.horizontal, AppSpacing.sm)
    .padding(.vertical, 6)
    .background {
      ZStack {
        RoundedRectangle(cornerRadius: AppRadius.medium)
          .fill(.background)
        RoundedRectangle(cornerRadius: AppRadius.medium)
          .fill(isRoot ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.secondary))
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: AppRadius.medium)
        .stroke(strokeStyle, lineWidth: isSelected ? 2 : 1)
    )
  }

  /// 選択枠は非rootならaccent、root（accent塗り）上では白で示す。非選択の非rootは薄い輪郭のみ。
  private var strokeStyle: AnyShapeStyle {
    if isSelected {
      return AnyShapeStyle(isRoot ? Color.white : Color.accentColor)
    }
    return isRoot ? AnyShapeStyle(.clear) : AnyShapeStyle(.separator)
  }
}
