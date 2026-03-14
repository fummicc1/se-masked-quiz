//
//  ModelDownloadService.swift
//  se-masked-quiz
//
//  Created for Issue #12: Model Download Management
//

import Foundation
import SwiftUI

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

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

/// MLX Swift LMのダウンロード機構をラップするサービス
actor ModelDownloadServiceImpl: ModelDownloadService {
  private var currentDownloadTask: Task<URL, Error>?

  // MARK: - Public Methods

  func downloadModel(
    named modelName: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws -> URL {
    // ストレージ容量チェック
    let estimatedSize = try await getModelSize(named: modelName)
    let availableStorage = try await getAvailableStorage()
    let requiredStorage = Int64(Double(estimatedSize) * 1.5)

    guard availableStorage >= requiredStorage else {
      throw ModelDownloadError.insufficientStorage(
        required: requiredStorage,
        available: availableStorage
      )
    }

    #if canImport(MLXLLM)
    let task = Task<URL, Error> {
      let configuration = ModelConfiguration(id: modelName)
      _ = try await LLMModelFactory.shared.loadContainer(
        configuration: configuration,
        progressHandler: { progress in
          progressHandler(progress.fractionCompleted)
        }
      )
      return Self.hubCacheDirectory(for: modelName)
    }
    currentDownloadTask = task

    do {
      let result = try await task.value
      currentDownloadTask = nil
      Self.setDownloadFlag(true, for: modelName)
      return result
    } catch {
      currentDownloadTask = nil
      if Task.isCancelled {
        throw ModelDownloadError.cancelled
      }
      throw ModelDownloadError.networkError(error)
    }
    #else
    throw ModelDownloadError.mlxUnavailable
    #endif
  }

  func cancelDownload() async {
    currentDownloadTask?.cancel()
    currentDownloadTask = nil
  }

  func deleteModel(named modelName: String) async throws {
    let modelDir = Self.hubCacheDirectory(for: modelName)
    if FileManager.default.fileExists(atPath: modelDir.path) {
      try FileManager.default.removeItem(at: modelDir)
    }
    Self.setDownloadFlag(false, for: modelName)
  }

  func isModelDownloaded(named modelName: String) async -> Bool {
    // UserDefaultsフラグを優先（ファイルシステムのパス不一致を回避）
    if Self.getDownloadFlag(for: modelName) {
      return true
    }

    // フォールバック: ファイルシステムで確認
    let snapshotsDir = Self.hubCacheDirectory(for: modelName)
      .appendingPathComponent("snapshots")

    guard let snapshots = try? FileManager.default
      .contentsOfDirectory(atPath: snapshotsDir.path)
      .filter({ !$0.hasPrefix(".") }),
      let snapshot = snapshots.first
    else {
      return false
    }

    let configPath = snapshotsDir
      .appendingPathComponent(snapshot)
      .appendingPathComponent("config.json")
    let exists = FileManager.default.fileExists(atPath: configPath.path)

    if exists {
      Self.setDownloadFlag(true, for: modelName)
    }

    return exists
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
    return LLMModelConfig.estimatedSizeBytes
  }

  // MARK: - Private Methods

  private static func downloadFlagKey(for modelName: String) -> String {
    "modelDownloaded_\(modelName)"
  }

  private static func setDownloadFlag(_ value: Bool, for modelName: String) {
    let key = downloadFlagKey(for: modelName)
    if value {
      UserDefaults.standard.set(true, forKey: key)
    } else {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }

  private static func getDownloadFlag(for modelName: String) -> Bool {
    UserDefaults.standard.bool(forKey: downloadFlagKey(for: modelName))
  }

  /// HuggingFace Hubのローカルキャッシュディレクトリを取得
  private static func hubCacheDirectory(for modelName: String) -> URL {
    let cacheBase = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let hubDir = cacheBase
      .appendingPathComponent("huggingface")
      .appendingPathComponent("hub")
    let sanitizedName = "models--" + modelName.replacingOccurrences(of: "/", with: "--")
    return hubDir.appendingPathComponent(sanitizedName)
  }
}

// MARK: - Errors

enum ModelDownloadError: Error, LocalizedError {
  case networkError(Error)
  case insufficientStorage(required: Int64, available: Int64)
  case cancelled
  case fileSystemError(Error)
  case mlxUnavailable

  var errorDescription: String? {
    switch self {
    case .networkError(let error):
      return "ネットワークエラー: \(error.localizedDescription)"
    case .insufficientStorage(let required, let available):
      let requiredGB = Double(required) / 1_000_000_000
      let availableGB = Double(available) / 1_000_000_000
      return "ストレージ容量が不足しています。必要: \(String(format: "%.1f", requiredGB))GB、利用可能: \(String(format: "%.1f", availableGB))GB"
    case .cancelled:
      return "ダウンロードがキャンセルされました"
    case .fileSystemError(let error):
      return "ファイルシステムエラー: \(error.localizedDescription)"
    case .mlxUnavailable:
      return "このデバイスではMLXが利用できません"
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
