//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {

  @Environment(\.llmService) var llmService

  @State private var modalWebUrl: URL?
  @StateObject var quizViewModel: QuizViewModel
  @State private var isAppeared = false
  @State private var showsLLMGenerationSheet = false
  @State private var showsLLMQuizView = false
  @State private var showsModelRequiredAlert = false
  @State private var isModelAvailable = false

  let proposal: SwiftEvolution

  init(
    proposal: SwiftEvolution,
    quizRepository: any QuizRepository
  ) {
    self.proposal = proposal
    _quizViewModel = StateObject(
      wrappedValue: QuizViewModel(
        proposalId: proposal.proposalId,
        quizRepository: quizRepository
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
          if quizViewModel.hasLLMQuizzes {
            showsLLMQuizView = true
          } else if isModelAvailable {
            showsLLMGenerationSheet = true
          } else {
            showsModelRequiredAlert = true
          }
        } label: {
          Image(systemName: "wand.and.stars")
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
}
