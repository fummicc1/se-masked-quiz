//
//  ProposalListScreen.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

struct ProposalListScreen: View {
  @Environment(\.seRepository) var repository
  @Environment(\.quizRepository) var quizRepository
  @Environment(\.testingQuizRepository) var testingQuizRepository
  @Environment(\.streakRepository) var streakRepository
  @Environment(\.analytics) var analytics
  @Environment(DeepLinkRouter.self) private var router
  @State private var proposals: AsyncProposals = .idle
  @State private var dailyProposal: SwiftEvolution?
  @State private var modalWebUrl: URL?
  @State private var currentPage: Int = 1
  @State private var hasNextPage: Bool = true
  @State private var shouldLoadNextPage: Bool = false
  @State private var showsSetting: Bool = false
  @State private var quizProgresses: [String: ProposalProgress] = [:]
  @State private var isLoadingProgress: Bool = false
  @State private var searchText: String = ""
  @State private var debouncedSearchText: String = ""
  @State private var sortOrder: ProposalSortOrder = .descending
  @State private var navigationPath = NavigationPath()

  /// このタブのトラック（Swift Evolution / Swift Testing）。
  let track: ProposalTrack

  init(track: ProposalTrack = .swiftEvolution) {
    self.track = track
  }

  /// トラックに対応するクイズリポジトリ（SE/ST でエンドポイント・ローカル保存が分かれる）。
  private var activeQuizRepository: any QuizRepository {
    track == .swiftEvolution ? quizRepository : testingQuizRepository
  }

  var body: some View {
    GeometryReader { proxy in
      NavigationStack(path: $navigationPath) {
        proposalsList
      }
      // 詳細画面でクイズに回答して戻ってきたとき（path が縮む）に進捗を再読込し、
      // 一覧の進捗率・正解率を最新化する
      .onChange(of: navigationPath.count) { oldCount, newCount in
        handleNavigationPathChange(oldCount: oldCount, newCount: newCount)
      }
      .sheet(isPresented: $showsSetting) {
        SettingScreen()
      }
      .onChange(of: shouldLoadNextPage) { oldValue, newValue in
        Task { await loadNextPageIfNeeded(oldValue: oldValue, newValue: newValue) }
      }
      .task(id: searchText) {
        await debounceSearchText()
      }
      .onChange(of: debouncedSearchText) { _, newValue in
        reloadFromFirstPage(searchText: newValue, sortOrder: sortOrder)
      }
      .onChange(of: sortOrder) { _, newValue in
        reloadFromFirstPage(searchText: debouncedSearchText, sortOrder: newValue)
      }
      .task {
        await loadInitialProposalsIfNeeded()
      }
      .sheet(item: $modalWebUrl) { url in
        webPreviewSheet(url: url, proxy: proxy)
      }
      // initial: true でコールドスタート時（Viewが表示される前に通知/DeepLinkが処理済みの場合）も
      // 既存の pendingChallenge を取りこぼさないようにする
      .onChange(of: router.pendingChallenge, initial: true) { _, newValue in
        handlePendingChallenge(newValue)
      }
    }
  }

  // MARK: - Body Helpers

  private func handleNavigationPathChange(oldCount: Int, newCount: Int) {
    guard newCount < oldCount else { return }
    Task { await loadQuizProgresses() }
  }

  /// 通知タップ/DeepLinkで保留中のチャレンジが自分のtrackと一致すれば取得して遷移する
  private func handlePendingChallenge(_ pending: DeepLinkRouter.PendingChallenge?) {
    guard let pending, pending.track == track else { return }
    Task {
      guard
        let proposal = try? await repository.fetchProposal(
          byProposalId: pending.proposalId, track: track)
      else { return }
      navigationPath.append(proposal)
      router.pendingChallenge = nil
    }
  }

  private func debounceSearchText() async {
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    debouncedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func loadNextPageIfNeeded(oldValue: Bool, newValue: Bool) async {
    guard !oldValue, newValue, !proposals.isLoading, hasNextPage else { return }
    proposals.startLoading()
    do {
      let response = try await repository.fetch(
        page: currentPage,
        searchText: debouncedSearchText.isEmpty ? nil : debouncedSearchText,
        sortOrder: sortOrder,
        track: track
      )
      hasNextPage = response.hasNextPage
      var currentProposals = proposals.content
      currentProposals.append(contentsOf: response.docs.map { $0.toSwiftEvolution(track: track) })
      proposals = .loaded(currentProposals)
      currentPage += 1
    } catch {
      proposals = .error(error)
    }
  }

  private func loadInitialProposalsIfNeeded() async {
    guard proposals.content.isEmpty, !proposals.isLoading else { return }
    do {
      proposals.startLoading()
      let response = try await repository.fetch(page: currentPage, sortOrder: sortOrder, track: track)
      hasNextPage = response.hasNextPage
      self.proposals = .loaded(response.docs.map { $0.toSwiftEvolution(track: track) })
      currentPage += 1

      // 進捗情報を読み込む
      await loadQuizProgresses()

      // 今日のチャレンジを読み込む（Swift Evolution タブのみ）
      if track == .swiftEvolution {
        await loadDailyChallenge()
      }
    } catch {
      self.proposals = .error(error)
    }
  }

  @ViewBuilder
  private func webPreviewSheet(url: URL, proxy: GeometryProxy) -> some View {
    #if os(iOS)
      DefaultWebView(
        htmlContent: .url(url),
        onNavigate: { modalWebUrl = $0 },
        onMaskedWordTap: { _ in
        },
        isCorrect: .constant([:]),
        answers: .constant([:])
      )
    #else
      VStack(spacing: 0) {
        HStack {
          Text(url.absoluteString)
          Spacer()
          Button("Close") {
            modalWebUrl = nil
          }
        }
        .padding(8)
        DefaultWebView(
          htmlContent: .url(url),
          onNavigate: { modalWebUrl = $0 },
          onMaskedWordTap: { _ in
          },
          isCorrect: .constant([:]),
          answers: .constant([:])
        )
        .frame(
          width: proxy.size.width * 0.8,
          height: proxy.size.height * 0.8
        )
      }
    #endif
  }

  // MARK: - Subviews

  @ViewBuilder
  private var proposalsList: some View {
    List {
      if let daily = dailyProposal {
        Section {
          HStack {
            NavigationLink(value: daily) {
              DailyChallengeCard(proposal: daily)
            }
            NavigationLink(value: StreakStatsRoute()) {
              Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
          }
        }
      }
      ForEach(proposals.content) { proposal in
        NavigationLink(value: proposal) {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              MarkdownText(proposal.title)
                .font(.headline)
              Text(proposal.displayId)
                .font(.caption)
            }
            MarkdownText(proposal.status ?? "")
              .font(.subheadline)
            MarkdownText(proposal.authors)
              .font(.subheadline)
            MarkdownText(proposal.reviewManager ?? "")
              .font(.subheadline)

            if let progress = quizProgresses[proposal.proposalId] {
              QuizProgressView(progress: progress)
                .padding(.top, 4)
            }
          }
        }
        .onAppear {
          guard let proposalIndex = proposals.content.firstIndex(of: proposal) else {
            return
          }
          shouldLoadNextPage = proposalIndex >= proposals.content.count - 5
        }
      }
    }
    .overlay {
      if proposals.content.isEmpty,
        !proposals.isLoading,
        !debouncedSearchText.isEmpty
      {
        ContentUnavailableView.search(text: debouncedSearchText)
      }
    }
    .navigationTitle(track.title)
    .modifier(ProposalListSearchableModifier(searchText: $searchText))
    .navigationDestination(for: SwiftEvolution.self) { proposal in
      ProposalQuizView(
        proposal: proposal,
        quizRepository: proposal.track == .swiftEvolution ? quizRepository : testingQuizRepository,
        streakRepository: streakRepository,
        analytics: analytics
      )
    }
    .navigationDestination(for: DependencyGraphRoute.self) { route in
      DependencyGraphScreen(
        rootProposalId: route.rootProposalId,
        rootTitle: route.rootTitle
      )
    }
    .navigationDestination(for: StreakStatsRoute.self) { _ in
      StreakStatsScreen()
    }
    .toolbar {
      #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
          Button {
            showsSetting = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          sortMenu
        }
      #elseif os(macOS)
        ToolbarItem(placement: .navigation) {
          Button {
            showsSetting = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
        ToolbarItem(placement: .primaryAction) {
          sortMenu
        }
      #endif
    }
  }

  private var sortMenu: some View {
    Menu {
      Picker("並び順", selection: $sortOrder) {
        Label("提案番号 昇順", systemImage: "arrow.up").tag(ProposalSortOrder.ascending)
        Label("提案番号 降順", systemImage: "arrow.down").tag(ProposalSortOrder.descending)
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down")
        .accessibilityLabel("並び順")
    }
  }

  // MARK: - Private Methods

  private func reloadFromFirstPage(searchText: String, sortOrder: ProposalSortOrder) {
    currentPage = 1
    hasNextPage = true
    proposals = .loading([])
    Task {
      do {
        let response = try await repository.fetch(
          page: currentPage,
          searchText: searchText.isEmpty ? nil : searchText,
          sortOrder: sortOrder,
          track: track
        )
        hasNextPage = response.hasNextPage
        proposals = .loaded(response.docs.map { $0.toSwiftEvolution(track: track) })
        currentPage += 1
      } catch {
        proposals = .error(error)
      }
    }
  }

  /// クイズの進捗情報を読み込む
  private func loadQuizProgresses() async {
    isLoadingProgress = true
    defer { isLoadingProgress = false }

    do {
      // 全提案のスコアを取得
      let allScores = await activeQuizRepository.getAllScores()

      // 全提案のクイズ数を取得
      let allQuizCounts = try await activeQuizRepository.getAllQuizCounts()

      // ProposalProgressマップを生成
      var progresses: [String: ProposalProgress] = [:]

      for (proposalId, totalCount) in allQuizCounts {
        let score = allScores[proposalId]
        let answeredCount = score?.questionResults.count ?? 0
        let correctCount = score?.correctCount ?? 0

        progresses[proposalId] = ProposalProgress(
          proposalId: proposalId,
          answeredCount: answeredCount,
          totalCount: totalCount,
          correctCount: correctCount
        )
      }

      quizProgresses = progresses
    } catch {
      print("Failed to load quiz progresses:", error)
      // エラー時も進捗なしで表示を継続
    }
  }

  /// 今日のチャレンジ対象の提案を決定論的に選び、内容を読み込む
  private func loadDailyChallenge() async {
    do {
      let counts = try await activeQuizRepository.getAllQuizCounts()
      let service = DailyChallengeService()
      guard
        let proposalId = service.todaysProposalId(from: Array(counts.keys), date: Date())
      else {
        return
      }
      dailyProposal = try await repository.fetchProposal(byProposalId: proposalId)
    } catch {
      print("Failed to load daily challenge:", error)
      // 失敗時はカードを出さずに一覧のみ表示を継続
    }
  }
}

private struct ProposalListSearchableModifier: ViewModifier {
  @Binding var searchText: String

  func body(content: Content) -> some View {
    #if os(iOS)
      content.searchable(
        text: $searchText,
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: "タイトル / 提案ID / 著者で検索"
      )
    #else
      content.searchable(
        text: $searchText,
        prompt: "タイトル / 提案ID / 著者で検索"
      )
    #endif
  }
}

extension URL: @retroactive Identifiable {
  public var id: String {
    absoluteString
  }
}

extension Binding {
  func isNotNil<V>() -> Binding<Bool> where Value == V? {
    .init(
      get: {
        self.wrappedValue != nil
      },
      set: {
        if !$0 {
          self.wrappedValue = nil
        }
      })
  }
}

#Preview {
  ProposalListScreen()
}
