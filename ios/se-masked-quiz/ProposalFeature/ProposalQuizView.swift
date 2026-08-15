//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {

  @Environment(\.llmService) var llmService
  @Environment(\.seRepository) var seRepository
  @Environment(\.referenceRepository) var referenceRepository

  @State private var modalWebUrl: URL?
  @StateObject var quizViewModel: QuizViewModel
  @State private var isAppeared = false
  @State private var showsLLMGenerationSheet = false
  @State private var showsLLMQuizView = false
  @State private var showsModelRequiredAlert = false
  @State private var isModelAvailable = false
  @State private var relatedProposals: [SwiftEvolution] = []

  let proposal: SwiftEvolution

  init(
    proposal: SwiftEvolution,
    quizRepository: any QuizRepository,
    streakRepository: any StreakRepository = StreakRepositoryImpl(),
    analytics: any AnalyticsService = ConsoleAnalyticsService()
  ) {
    self.proposal = proposal
    _quizViewModel = StateObject(
      wrappedValue: QuizViewModel(
        proposalId: proposal.proposalId,
        quizRepository: quizRepository,
        streakRepository: streakRepository,
        analytics: analytics
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      if let currentScore = quizViewModel.currentScore {
        HStack {
          HStack {
            Text("現在のスコア: \(Int(currentScore.percentage))%")
              .font(AppFont.headline)
            Text("(\(currentScore.correctCount)/\(currentScore.totalCount)問正解)")
              .font(AppFont.subheadline)
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
          Spacer()
          Button(action: {
            quizViewModel.isShowingResetAlert = true
          }) {
            Image(systemName: "arrow.counterclockwise")
              .foregroundStyle(SemanticColor.incorrect)
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityLabel("クイズをリセット")
        }
        .padding(.horizontal)
        .padding(.vertical, AppSpacing.sm)
      }

      if !relatedProposals.isEmpty {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
          Label("先に読むと理解しやすい提案", systemImage: "book")
            .font(AppFont.subheadline.weight(.semibold))
            .padding(.horizontal)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
              ForEach(relatedProposals) { related in
                NavigationLink(value: related) {
                  RelatedProposalCard(proposal: related)
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.horizontal)
          }
        }
        .padding(.vertical, AppSpacing.sm)
      }

      DefaultWebView(
        htmlContent: .string(proposal.content),
        onNavigate: { url in
          modalWebUrl = url
        },
        onMaskedWordTap: { maskIndex in
          quizViewModel.showQuizSelections(maskIndex: maskIndex)
        },
        isCorrect: $quizViewModel.isCorrect,
        answers: $quizViewModel.answers,
        scrollToMaskIndex: quizViewModel.pendingScrollMaskIndex,
        focusedMaskIndex: quizViewModel.currentQuiz?.index
      )
      if quizViewModel.currentQuiz != nil {
        QuizSelectionsView(viewModel: quizViewModel)
      }
    }
    .navigationTitle(proposal.title)
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      // 依存グラフは Swift Evolution のみ（ST は v1 では対象外）
      if proposal.track == .swiftEvolution {
        ToolbarItem(placement: .primaryAction) {
          NavigationLink(
            value: DependencyGraphRoute(
              rootProposalId: proposal.proposalId,
              rootTitle: proposal.title
            )
          ) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
              .accessibilityLabel("依存グラフ")
          }
        }
      }
      ToolbarItem(placement: .primaryAction) {
        Button {
          if quizViewModel.hasLLMQuizzes {
            showsLLMQuizView = true
          } else if isModelAvailable {
            showsLLMGenerationSheet = true
          } else {
            showsModelRequiredAlert = true
          }
        } label: {
          Image(systemName: "wand.and.stars")
            .accessibilityLabel(quizViewModel.hasLLMQuizzes ? "生成済みクイズを開く" : "クイズを生成")
        }
      }
    }
    .sheet(isPresented: $showsLLMGenerationSheet, onDismiss: {
      if quizViewModel.hasLLMQuizzes {
        showsLLMQuizView = true
      }
    }) {
      LLMQuizGenerationSheet(
        proposal: proposal,
        quizViewModel: quizViewModel,
        llmService: llmService,
        onDismiss: { showsLLMGenerationSheet = false }
      )
    }
    .sheet(isPresented: $showsLLMQuizView) {
      LLMQuizView(
        viewModel: quizViewModel,
        onRegenerate: {
          showsLLMQuizView = false
          showsLLMGenerationSheet = true
        },
        onDismiss: { showsLLMQuizView = false }
      )
    }
    .task {
      await quizViewModel.configure()
    }
    .task {
      await loadRelatedProposals()
    }
    .onAppear {
      Task {
        isModelAvailable = await llmService.isModelDownloaded(named: LLMModelConfig.modelId)
      }
    }
    .alert("モデルのダウンロードが必要", isPresented: $showsModelRequiredAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("LLMクイズを生成するには、設定画面からモデルをダウンロードしてください。")
    }
    .alert("クイズをリセット", isPresented: $quizViewModel.isShowingResetAlert) {
      Button("キャンセル", role: .cancel) {}
      Button("リセット", role: .destructive) {
        Task {
          await quizViewModel.resetQuiz(for: proposal.proposalId)
          await quizViewModel.configure()
        }
      }
    } message: {
      Text("このプロポーザルのクイズの進捗をリセットしますか？\nこの操作は取り消せません。")
    }
  }

  /// この提案が参照している（理解の前提となる）提案を読み込む
  private func loadRelatedProposals() async {
    // 参照（依存）は Swift Evolution のみ。ST は別トラックで bare ID が衝突するため読み込まない。
    guard proposal.track == .swiftEvolution else { return }
    do {
      let edges = try await referenceRepository.fetchOutgoing(fromProposalIds: [proposal.proposalId])
      let ids = Array(Set(edges.map(\.toProposalId))).sorted()
      guard !ids.isEmpty else { return }
      let fetched = try await seRepository.fetchProposals(byProposalIds: ids)
      relatedProposals = fetched.sorted { $0.proposalId < $1.proposalId }
    } catch {
      // 失敗時は前提提案を出さずにクイズ表示を継続
      print("Failed to load related proposals:", error)
    }
  }
}
