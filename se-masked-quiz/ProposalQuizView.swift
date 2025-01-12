//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {

  @State private var modalWebUrl: URL?
  @EnvironmentObject var quizViewModel: QuizViewModel
  @State private var isAppeared = false

  let proposal: SwiftEvolution

  init(proposal: SwiftEvolution) {
    self.proposal = proposal
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
        QuizSelectionsView()
      }
    }
    .navigationTitle(proposal.title)
    .onAppear {
      if isAppeared {
        return
      }
      isAppeared = true
      quizViewModel.startQuiz(for: proposal.proposalId)
    }
    .alert("クイズをリセット", isPresented: $quizViewModel.isShowingResetAlert) {
      Button("キャンセル", role: .cancel) {}
      Button("リセット", role: .destructive) {
        Task {
          await quizViewModel.resetQuiz(for: proposal.proposalId)
          quizViewModel.startQuiz(for: proposal.proposalId)
        }
      }
    } message: {
      Text("このプロポーザルのクイズの進捗をリセットしますか？\nこの操作は取り消せません。")
    }
  }
}
