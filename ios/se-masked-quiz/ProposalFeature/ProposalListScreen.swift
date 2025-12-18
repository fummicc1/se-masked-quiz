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
  @Environment(\.srsScheduler) var srsScheduler
  @State private var proposals: AsyncProposals = .idle
  @State private var modalWebUrl: URL?
  @State private var offset: Int = 0
  @State private var shouldLoadNextPage: Bool = false
  @State private var showsSetting: Bool = false
  @State private var quizProgresses: [String: ProposalProgress] = [:]
  @State private var isLoadingProgress: Bool = false

  var body: some View {
    GeometryReader { proxy in
      NavigationStack {
        List {
          ForEach(proposals.content) { proposal in
            NavigationLink(value: proposal) {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  MarkdownText(proposal.title)
                    .font(.headline)
                  Text("#\(Int(proposal.proposalId) ?? 0)")
                    .font(.caption)
                }
                MarkdownText(proposal.status ?? "")
                  .font(.subheadline)
                MarkdownText(proposal.authors)
                  .font(.subheadline)
                MarkdownText(proposal.reviewManager ?? "")
                  .font(.subheadline)

                // 進捗表示
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
        .navigationTitle("Swift Evolution")
        .navigationDestination(for: SwiftEvolution.self) { proposal in
          ProposalQuizView(
            proposal: proposal,
            quizRepository: quizRepository,
            srsScheduler: srsScheduler
          )
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
          #elseif os(macOS)
            ToolbarItem(placement: .navigation) {
              Button {
                showsSetting = true
              } label: {
                Image(systemName: "gearshape")
              }
            }
          #endif
        }
      }
      .sheet(isPresented: $showsSetting) {
        SettingScreen()
      }
      .onChange(
        of: shouldLoadNextPage,
        { oldValue, newValue in
          if !oldValue, newValue {
            if proposals.isLoading {
              return
            }
            proposals.startLoading()
            Task {
              do {
                let newProposals = try await repository.fetch(offset: offset)
                var currentProposals = proposals.content
                currentProposals.append(contentsOf: newProposals)
                proposals = .loaded(currentProposals)
                offset = currentProposals.count
              } catch {
                proposals = .error(error)
              }
            }
          }
        }
      )
      .task {
        if !proposals.content.isEmpty || proposals.isLoading {
          return
        }
        do {
          proposals.startLoading()
          let proposals = try await repository.fetch(offset: offset)
          offset = proposals.count
          self.proposals = .loaded(proposals)

          // 進捗情報を読み込む
          await loadQuizProgresses()
        } catch {
          self.proposals = .error(error)
        }
      }
      #if os(iOS)
        .sheet(
          item: $modalWebUrl,
          content: { url in
            DefaultWebView(
              htmlContent: .url(url),
              onNavigate: { modalWebUrl = $0 },
              onMaskedWordTap: { _ in
              },
              isCorrect: .constant([:]),
              answers: .constant([:])
            )
          })
      #else
        .sheet(item: $modalWebUrl) { url in
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
        }
      #endif
    }
  }

  // MARK: - Private Methods

  /// クイズの進捗情報を読み込む
  private func loadQuizProgresses() async {
    isLoadingProgress = true
    defer { isLoadingProgress = false }

    do {
      // 全提案のスコアを取得
      let allScores = await quizRepository.getAllScores()

      // 全提案のクイズ数を取得
      let allQuizCounts = try await quizRepository.getAllQuizCounts()

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
