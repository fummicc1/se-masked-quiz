//
//  ModelDownloadView.swift
//  se-masked-quiz
//
//  Created for Issue #12: Model Download UI
//

import SwiftUI

struct ModelDownloadView: View {
  @Environment(\.llmService) var llmService
  @State private var selectedModel: LLMModelOption = LLMModelConfig.selectedModel
  @State private var downloadStates: [LLMModelOption: DownloadState] = [:]
  @State private var downloadProgress: Progress?
  @State private var downloadingModel: LLMModelOption?
  @State private var availableStorage: Int64 = 0
  @State private var errorMessage: String?

  var body: some View {
    List {
      // モデル選択セクション
      Section {
        ForEach(LLMModelOption.allCases) { model in
          modelRow(for: model)
        }
      } header: {
        Text("モデル選択")
      } footer: {
        Text("モデルのサイズが大きいほど、より複雑な問題の意図を正確に理解し、質の高いクイズを生成できます。ただし、ダウンロードサイズとメモリ使用量が増加します。")
      }

      // ダウンロード進捗
      if let downloading = downloadingModel {
        Section("ダウンロード中: \(downloading.displayName)") {
          if let progress = downloadProgress, !progress.isIndeterminate {
            ProgressView(value: progress.fractionCompleted)
              .progressViewStyle(.linear)
          } else {
            ProgressView()
              .progressViewStyle(.linear)
          }
          HStack {
            if let progress = downloadProgress, progress.totalUnitCount > 0 {
              Text("\(formatBytes(progress.completedUnitCount)) / \(formatBytes(progress.totalUnitCount))")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text("ダウンロード中...")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Button("キャンセル", role: .destructive) {
              cancelDownload()
            }
            .font(.caption)
          }
        }
      }

      // ストレージ情報
      Section("ストレージ") {
        HStack {
          Text("利用可能容量")
            .foregroundColor(.secondary)
          Spacer()
          Text(formatBytes(availableStorage))
            .fontWeight(.medium)
        }
      }

      // エラー表示
      if let errorMessage {
        Section {
          HStack {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundColor(.red)
            Text(errorMessage)
              .font(.caption)
              .foregroundColor(.red)
          }
        }
      }

      // Tips
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Label("オンデバイスAI", systemImage: "cpu")
            .font(.subheadline)
            .fontWeight(.semibold)
          Text("すべてのAI処理はデバイス上で実行されます。データがクラウドに送信されることはありません。")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .navigationTitle("モデル管理")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task {
      await loadInitialState()
    }
  }

  // MARK: - Model Row

  @ViewBuilder
  private func modelRow(for model: LLMModelOption) -> some View {
    let state = downloadStates[model] ?? .idle
    let isSelected = selectedModel == model

    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(model.displayName)
              .font(.body)
              .fontWeight(isSelected ? .semibold : .regular)
            if isSelected {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.accentColor)
                .font(.caption)
            }
          }
          Text(model.capabilityDescription)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Spacer()
        Text(formatBytes(model.estimatedSizeBytes))
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // アクションボタン（.borderlessでセルタップとの重複を防止）
      HStack(spacing: 12) {
        switch state {
        case .idle:
          Button {
            startDownload(model: model)
          } label: {
            Label("ダウンロード", systemImage: "arrow.down.circle")
              .font(.caption)
          }
          .buttonStyle(.borderless)
          .disabled(downloadingModel != nil)

        case .downloading:
          ProgressView()
            .controlSize(.small)
          Text("ダウンロード中...")
            .font(.caption)
            .foregroundColor(.secondary)

        case .downloaded:
          if !isSelected {
            Button {
              selectModel(model)
            } label: {
              Label("使用する", systemImage: "checkmark")
                .font(.caption)
            }
            .buttonStyle(.borderless)
          } else {
            Text("使用中")
              .font(.caption)
              .foregroundColor(.green)
          }

          Spacer()

          Button(role: .destructive) {
            deleteModel(model)
          } label: {
            Label("削除", systemImage: "trash")
              .font(.caption)
          }
          .buttonStyle(.borderless)
        }
      }
    }
    .padding(.vertical, 4)
  }

  // MARK: - Actions

  private func selectModel(_ model: LLMModelOption) {
    selectedModel = model
    LLMModelConfig.selectedModel = model
  }

  private func startDownload(model: LLMModelOption) {
    let requiredStorage = Int64(Double(model.estimatedSizeBytes) * 1.5)
    guard availableStorage >= requiredStorage else {
      errorMessage = "ストレージ容量が不足しています（必要: \(formatBytes(requiredStorage))）"
      return
    }

    downloadingModel = model
    downloadStates[model] = .downloading
    downloadProgress = nil
    errorMessage = nil

    Task {
      do {
        try await llmService.downloadModel(named: model.modelId) { progress in
          Task { @MainActor in
            downloadProgress = progress
          }
        }
        downloadStates[model] = .downloaded
        downloadingModel = nil
        downloadProgress = nil

        // 初回DLなら自動選択
        selectModel(model)
        await refreshAvailableStorage()
      } catch {
        downloadStates[model] = .idle
        downloadingModel = nil
        downloadProgress = nil
        errorMessage = error.localizedDescription
      }
    }
  }

  private func cancelDownload() {
    guard let model = downloadingModel else { return }
    Task {
      await llmService.cancelDownload()
      downloadStates[model] = .idle
      downloadingModel = nil
      downloadProgress = nil
    }
  }

  private func deleteModel(_ model: LLMModelOption) {
    Task {
      do {
        try await llmService.deleteModel(named: model.modelId)
        downloadStates[model] = .idle

        // 削除したモデルが選択中なら、DL済みの別モデルに切り替え
        if selectedModel == model {
          let fallback = LLMModelOption.allCases.first {
            $0 != model && downloadStates[$0] == .downloaded
          }
          if let fallback {
            selectModel(fallback)
          }
        }
        await refreshAvailableStorage()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  // MARK: - Data Loading

  private func loadInitialState() async {
    await refreshAvailableStorage()

    for model in LLMModelOption.allCases {
      let isDownloaded = await llmService.isModelDownloaded(named: model.modelId)
      downloadStates[model] = isDownloaded ? .downloaded : .idle
    }
  }

  private func refreshAvailableStorage() async {
    do {
      availableStorage = try await llmService.getAvailableStorage()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: - Helpers

  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useGB, .useMB]
    return formatter.string(fromByteCount: bytes)
  }
}

// MARK: - Download State

extension ModelDownloadView {
  enum DownloadState {
    case idle
    case downloading
    case downloaded
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ModelDownloadView()
  }
}
