//
//  ModelDownloadView.swift
//  se-masked-quiz
//
//  Created for Issue #12: Model Download UI
//

import SwiftUI

struct ModelDownloadView: View {
  @Environment(\.modelDownloadService) var downloadService
  @State private var downloadState: DownloadState = .idle
  @State private var downloadProgress: Double = 0.0
  @State private var availableStorage: Int64 = 0
  @State private var modelSize: Int64 = 0
  @State private var errorMessage: String?

  private let modelName = "robbiemu/MobileLLM-R1-950M-MLX"

  var body: some View {
    VStack(spacing: 20) {
      headerSection
      storageInfoSection
      downloadButtonSection
      progressSection
      errorSection

      Spacer()
    }
    .padding()
    .navigationTitle("モデルダウンロード")
    .task {
      await loadStorageInfo()
    }
  }

  // MARK: - Sections

  private var headerSection: some View {
    VStack(spacing: 8) {
      Image(systemName: "arrow.down.circle.fill")
        .font(.system(size: 60))
        .foregroundColor(.blue)

      Text("LLMモデル")
        .font(.headline)

      Text("MobileLLM 950M")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
  }

  private var storageInfoSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("モデルサイズ:")
          .foregroundColor(.secondary)
        Spacer()
        Text(formatBytes(modelSize))
          .fontWeight(.medium)
      }

      HStack {
        Text("利用可能容量:")
          .foregroundColor(.secondary)
        Spacer()
        Text(formatBytes(availableStorage))
          .fontWeight(.medium)
          .foregroundColor(hasEnoughStorage ? .green : .red)
      }

      if !hasEnoughStorage && downloadState == .idle {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          Text("ストレージ容量が不足しています")
            .font(.caption)
            .foregroundColor(.orange)
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  private var downloadButtonSection: some View {
    Group {
      switch downloadState {
      case .idle:
        Button(action: startDownload) {
          Label("ダウンロード開始", systemImage: "arrow.down.circle")
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasEnoughStorage ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!hasEnoughStorage)

      case .downloading:
        Button(action: cancelDownload) {
          Label("キャンセル", systemImage: "xmark.circle")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }

      case .downloaded:
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          Text("ダウンロード済み")
            .foregroundColor(.green)
            .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)

        Button(action: deleteModel) {
          Label("モデルを削除", systemImage: "trash")
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
        }
      }
    }
  }

  private var progressSection: some View {
    Group {
      if case .downloading = downloadState {
        VStack(spacing: 8) {
          ProgressView(value: downloadProgress)
            .progressViewStyle(.linear)

          Text("\(Int(downloadProgress * 100))% 完了")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(formatBytes(Int64(Double(modelSize) * downloadProgress)) + " / " + formatBytes(modelSize))
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
  }

  private var errorSection: some View {
    Group {
      if let errorMessage = errorMessage {
        HStack {
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(.red)
          Text(errorMessage)
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
      }
    }
  }

  // MARK: - Computed Properties

  private var hasEnoughStorage: Bool {
    let requiredStorage = Int64(Double(modelSize) * 1.5)
    return availableStorage >= requiredStorage
  }

  // MARK: - Actions

  private func startDownload() {
    downloadState = .downloading
    errorMessage = nil

    Task {
      do {
        _ = try await downloadService.downloadModel(named: modelName) { progress in
          Task { @MainActor in
            downloadProgress = progress
          }
        }
        downloadState = .downloaded
        downloadProgress = 1.0
      } catch {
        downloadState = .idle
        downloadProgress = 0.0
        errorMessage = error.localizedDescription
      }
    }
  }

  private func cancelDownload() {
    Task {
      await downloadService.cancelDownload()
      downloadState = .idle
      downloadProgress = 0.0
    }
  }

  private func deleteModel() {
    Task {
      do {
        try await downloadService.deleteModel(named: modelName)
        downloadState = .idle
        downloadProgress = 0.0
        await loadStorageInfo()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func loadStorageInfo() async {
    do {
      availableStorage = try await downloadService.getAvailableStorage()
      modelSize = try await downloadService.getModelSize(named: modelName)

      // モデルがすでにダウンロード済みかチェック
      let isDownloaded = await downloadService.isModelDownloaded(named: modelName)
      if isDownloaded {
        downloadState = .downloaded
        downloadProgress = 1.0
      }
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

enum DownloadState {
  case idle
  case downloading
  case downloaded
}

// MARK: - Preview

#Preview {
  NavigationStack {
    ModelDownloadView()
  }
}
