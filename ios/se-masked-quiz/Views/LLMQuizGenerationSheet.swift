//
//  LLMQuizGenerationSheet.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM Quiz Generation UI
//

import SwiftUI

struct LLMQuizGenerationSheet: View {
  let proposal: SwiftEvolution
  @ObservedObject var quizViewModel: QuizViewModel
  let llmService: any LLMService
  let onDismiss: () -> Void

  @State private var selectedDifficulty: QuizDifficulty = .intermediate
  @State private var quizCount: Int = 5

  private let modelId = "mlx-community/Qwen3-1.7B-8bit"

  var body: some View {
    NavigationStack {
      Form {
        // 難易度選択
        Section("難易度") {
          Picker("難易度", selection: $selectedDifficulty) {
            Text("初級").tag(QuizDifficulty.beginner)
            Text("中級").tag(QuizDifficulty.intermediate)
            Text("上級").tag(QuizDifficulty.advanced)
          }
          .pickerStyle(.segmented)
        }

        // クイズ数選択
        Section("クイズ数") {
          Stepper("\(quizCount)問", value: $quizCount, in: 1...10)
        }

        // 生成進捗表示
        if quizViewModel.isGeneratingQuizzes {
          Section {
            ProgressView(value: quizViewModel.quizGenerationProgress) {
              Text("クイズを生成中...")
            }
            .progressViewStyle(.linear)
          }
        }

        // エラー表示
        if let error = quizViewModel.quizGenerationError {
          Section {
            Text(error)
              .foregroundColor(.red)
              .font(.callout)
          }
        }

        // 生成ボタン
        Section {
          Button {
            Task {
              await quizViewModel.generateQuizzesWithLLM(
                content: proposal.content,
                difficulty: selectedDifficulty,
                count: quizCount,
                llmService: llmService,
                modelId: modelId
              )
              if quizViewModel.quizGenerationError == nil {
                onDismiss()
              }
            }
          } label: {
            HStack {
              Spacer()
              if quizViewModel.isGeneratingQuizzes {
                ProgressView()
                  .progressViewStyle(.circular)
                Text("生成中...")
              } else {
                Image(systemName: "wand.and.stars")
                Text("クイズを生成")
              }
              Spacer()
            }
          }
          .disabled(quizViewModel.isGeneratingQuizzes)
        }

        // 説明セクション
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Label("オンデバイスAIでクイズを生成", systemImage: "cpu")
              .font(.subheadline)
              .foregroundColor(.secondary)
            Text("デバイス上でLLMを実行してクイズを生成します。インターネット接続は不要です。")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .navigationTitle("LLMクイズ生成")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("閉じる") {
            onDismiss()
          }
          .disabled(quizViewModel.isGeneratingQuizzes)
        }
      }
      .interactiveDismissDisabled(quizViewModel.isGeneratingQuizzes)
    }
  }
}
