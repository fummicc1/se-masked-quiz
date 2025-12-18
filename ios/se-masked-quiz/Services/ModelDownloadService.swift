//
//  ModelDownloadService.swift
//  se-masked-quiz
//
//  Created for Issue #12: Model Download Management
//

import Foundation
import SwiftUI
import CryptoKit
import os

// MARK: - ModelDownloadService Protocol

/// モデルダウンロードサービス
protocol ModelDownloadService: Actor {
  /// モデルをダウンロード
  /// - Parameters:
  ///   - modelName: モデル名 (例: "mlx-community/Gemma-2B-it-4bit")
  ///   - progressHandler: 進捗ハンドラー (0.0〜1.0)
  /// - Returns: ダウンロードしたモデルのローカルパス
  func downloadModel(
    named modelName: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws -> URL

  /// ダウンロードをキャンセル
  func cancelDownload() async

  /// モデルを削除
  /// - Parameter modelName: モデル名
  func deleteModel(named modelName: String) async throws

  /// モデルがダウンロード済みかどうか
  /// - Parameter modelName: モデル名
  /// - Returns: ダウンロード済みの場合true
  func isModelDownloaded(named modelName: String) async -> Bool

  /// 利用可能なストレージ容量をチェック
  /// - Returns: 利用可能なバイト数
  func getAvailableStorage() async throws -> Int64

  /// モデルのサイズを取得
  /// - Parameter modelName: モデル名
  /// - Returns: バイト数
  func getModelSize(named modelName: String) async throws -> Int64
}

// MARK: - ModelDownloadService Implementation

actor ModelDownloadServiceImpl: NSObject, ModelDownloadService, URLSessionDownloadDelegate {
  private var downloadTask: URLSessionDownloadTask?
  private var progressHandler: ((Double) -> Void)?
  private var downloadContinuation: CheckedContinuation<URL, Error>?
  private var currentModelName: String?  // ダウンロード中のモデル名を保持
  /// スレッドセーフな保存先URL（デリゲートからもアクセス可能）
  private let destinationURLLock = OSAllocatedUnfairLock<URL?>(initialState: nil)

  private static let modelsDirectory = "MLModels"
  private static let baseURL = "https://huggingface.co"

  // MARK: - Public Methods

  func downloadModel(
    named modelName: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws -> URL {
    // すでにダウンロード済みの場合は、ローカルパスを返す
    if let localURL = try? getLocalModelURL(for: modelName), FileManager.default.fileExists(atPath: localURL.path) {
      return localURL
    }

    // ストレージ容量チェック
    let estimatedSize = try await getModelSize(named: modelName)
    let availableStorage = try await getAvailableStorage()
    let requiredStorage = Int64(Double(estimatedSize) * 1.5)  // 1.5倍の余裕を要求

    guard availableStorage >= requiredStorage else {
      throw ModelDownloadError.insufficientStorage(
        required: requiredStorage,
        available: availableStorage
      )
    }

    self.progressHandler = progressHandler
    self.currentModelName = modelName  // モデル名を保持

    // 保存先ディレクトリを事前に作成し、URLを保持
    let localURL = try getLocalModelURL(for: modelName)
    destinationURLLock.withLock { $0 = localURL }

    // ダウンロードURLを構築
    let downloadURL = buildDownloadURL(for: modelName)

    return try await withCheckedThrowingContinuation { continuation in
      self.downloadContinuation = continuation

      let configuration = URLSessionConfiguration.default
      configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
      let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

      downloadTask = session.downloadTask(with: downloadURL)
      downloadTask?.resume()
    }
  }

  func cancelDownload() async {
    downloadTask?.cancel()
    downloadTask = nil
    currentModelName = nil
    destinationURLLock.withLock { $0 = nil }
    downloadContinuation?.resume(throwing: ModelDownloadError.cancelled)
    downloadContinuation = nil
  }

  func deleteModel(named modelName: String) async throws {
    let localURL = try getLocalModelURL(for: modelName)
    if FileManager.default.fileExists(atPath: localURL.path) {
      try FileManager.default.removeItem(at: localURL)
    }
  }

  func isModelDownloaded(named modelName: String) async -> Bool {
    guard let localURL = try? getLocalModelURL(for: modelName) else {
      return false
    }

    let fileManager = FileManager.default
    let path = localURL.path

    guard fileManager.fileExists(atPath: path) else {
      return false
    }

    // ファイルサイズが0より大きいか確認（破損ファイル対策）
    if let attributes = try? fileManager.attributesOfItem(atPath: path),
       let fileSize = attributes[.size] as? Int64,
       fileSize > 0 {
      return true
    }

    return false
  }

  func getAvailableStorage() async throws -> Int64 {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw ModelDownloadError.fileSystemError(NSError(domain: "ModelDownload", code: -1))
    }

    let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentsURL.path)
    guard let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
      throw ModelDownloadError.fileSystemError(NSError(domain: "ModelDownload", code: -2))
    }

    return freeSpace
  }

  func getModelSize(named modelName: String) async throws -> Int64 {
    // Qwen3 1.7B 4-bit quantized model のサイズ（約850MB）
    // 実際のサイズは HEAD リクエストで取得すべきだが、ここでは固定値を返す
    return 850_000_000  // 850MB
  }

  // MARK: - Private Methods

  private func buildDownloadURL(for modelName: String) -> URL {
    // Hugging Face のダウンロードURL構築
    // 例: https://huggingface.co/mlx-community/Gemma-2B-it-4bit/resolve/main/model.safetensors
    let urlString = "\(Self.baseURL)/\(modelName)/resolve/main/model.safetensors"
    return URL(string: urlString)!
  }

  private func getLocalModelURL(for modelName: String) throws -> URL {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw ModelDownloadError.fileSystemError(NSError(domain: "ModelDownload", code: -1))
    }

    let modelsDir = documentsURL.appendingPathComponent(Self.modelsDirectory)
    if !fileManager.fileExists(atPath: modelsDir.path) {
      try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
    }

    // モデル名からファイル名を生成（スラッシュをアンダースコアに置換）
    let fileName = modelName.replacingOccurrences(of: "/", with: "_") + ".safetensors"
    return modelsDir.appendingPathComponent(fileName)
  }

  private func verifyChecksum(fileURL: URL, expectedHash: String) throws -> Bool {
    let data = try Data(contentsOf: fileURL)
    let hash = SHA256.hash(data: data)
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
    return hashString == expectedHash
  }

  // MARK: - URLSessionDownloadDelegate

  nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    // 重要: URLSessionは、このメソッドが戻ると一時ファイルを削除する
    // そのため、ファイルの移動は同期的に行う必要がある
    guard let destination = destinationURLLock.withLock({ $0 }) else {
      Task {
        await handleDownloadError(
          ModelDownloadError.networkError(
            NSError(domain: "ModelDownload", code: -4, userInfo: [NSLocalizedDescriptionKey: "Destination URL is nil"])
          )
        )
      }
      return
    }

    let fileManager = FileManager.default
    let parentDir = destination.deletingLastPathComponent()

    do {
      // ディレクトリが存在しない場合は作成（再起動後にディレクトリが消えている可能性に対応）
      if !fileManager.fileExists(atPath: parentDir.path) {
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
      }

      // 既存ファイルがあれば削除
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.removeItem(at: destination)
      }

      // 同期的にファイルを移動
      try fileManager.moveItem(at: location, to: destination)

      // 検証: ファイルが実際に存在するか確認
      guard fileManager.fileExists(atPath: destination.path) else {
        Task {
          await handleDownloadError(
            ModelDownloadError.fileSystemError(
              NSError(domain: "ModelDownload", code: -5, userInfo: [NSLocalizedDescriptionKey: "ファイル移動後の検証に失敗しました"])
            )
          )
        }
        return
      }

      // 成功を通知
      Task {
        await handleDownloadSuccess(destination)
      }
    } catch {
      Task {
        await handleDownloadError(ModelDownloadError.fileSystemError(error))
      }
    }
  }

  nonisolated func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    if let error = error {
      Task {
        await handleDownloadError(ModelDownloadError.networkError(error))
      }
    }
  }

  nonisolated func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    Task {
      await notifyProgress(progress)
    }
  }

  private func handleDownloadSuccess(_ url: URL) async {
    currentModelName = nil
    destinationURLLock.withLock { $0 = nil }
    downloadContinuation?.resume(returning: url)
    downloadContinuation = nil
  }

  private func handleDownloadError(_ error: Error) async {
    currentModelName = nil
    destinationURLLock.withLock { $0 = nil }
    downloadContinuation?.resume(throwing: error)
    downloadContinuation = nil
  }

  private func notifyProgress(_ progress: Double) async {
    progressHandler?(progress)
  }
}

// MARK: - Errors

enum ModelDownloadError: Error, LocalizedError {
  case networkError(Error)
  case insufficientStorage(required: Int64, available: Int64)
  case checksumMismatch
  case cancelled
  case fileSystemError(Error)

  var errorDescription: String? {
    switch self {
    case .networkError(let error):
      return "ネットワークエラー: \(error.localizedDescription)"
    case .insufficientStorage(let required, let available):
      let requiredGB = Double(required) / 1_000_000_000
      let availableGB = Double(available) / 1_000_000_000
      return "ストレージ容量が不足しています。必要: \(String(format: "%.1f", requiredGB))GB、利用可能: \(String(format: "%.1f", availableGB))GB"
    case .checksumMismatch:
      return "ファイルの検証に失敗しました。もう一度ダウンロードしてください。"
    case .cancelled:
      return "ダウンロードがキャンセルされました"
    case .fileSystemError(let error):
      return "ファイルシステムエラー: \(error.localizedDescription)"
    }
  }
}

// MARK: - Environment

extension ModelDownloadServiceImpl {
  static var defaultValue: any ModelDownloadService {
    ModelDownloadServiceImpl()
  }
}

private struct ModelDownloadServiceKey: EnvironmentKey {
  static var defaultValue: any ModelDownloadService {
    ModelDownloadServiceImpl.defaultValue
  }
}

extension EnvironmentValues {
  var modelDownloadService: any ModelDownloadService {
    get { self[ModelDownloadServiceKey.self] }
    set { self[ModelDownloadServiceKey.self] = newValue }
  }
}
