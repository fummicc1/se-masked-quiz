//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {

  @State private var modalWebUrl: URL?
  @StateObject var quizViewModel: QuizViewModel
  @State private var isAppeared = false
  @State private var showsReviewDashboard = false

  let proposal: SwiftEvolution

  init(
    proposal: SwiftEvolution,
    quizRepository: any QuizRepository,
    srsScheduler: any SRSScheduler
  ) {
    self.proposal = proposal
    _quizViewModel = StateObject(
      wrappedValue: QuizViewModel(
        proposalId: proposal.proposalId,
        quizRepository: quizRepository,
        srsScheduler: srsScheduler
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      if let currentScore = quizViewModel.currentScore {
        HStack {
          Text("現在のスコア: \(Int(currentScore.percentage))%")
            .font(.headline)
          Text("(\(currentScore.correctCount)/\(currentScore.totalCount)問正解)")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
          Button(action: {
            quizViewModel.isShowingResetAlert = true
          }) {
            Image(systemName: "arrow.counterclockwise")
              .foregroundColor(.red)
          }
        }
        .padding()
      }

      DefaultWebView(
        htmlContent: .string(proposal.content),
        onNavigate: { url in
          modalWebUrl = url
        },
        onMaskedWordTap: { maskIndex in
          print("Tapped mask index:", maskIndex)
          quizViewModel.showQuizSelections(index: maskIndex)
        },
        isCorrect: $quizViewModel.isCorrect,
        answers: $quizViewModel.answers
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
      ToolbarItem(placement: .primaryAction) {
        Button {
          showsReviewDashboard = true
        } label: {
          Image(systemName: "chart.bar.xaxis")
        }
      }
    }
    .sheet(isPresented: $showsReviewDashboard) {
      NavigationStack {
        ReviewDashboardView(proposalId: proposal.proposalId)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("閉じる") {
                showsReviewDashboard = false
              }
            }
          }
      }
    }
    .task {
      await quizViewModel.configure()
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
}
