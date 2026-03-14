//
//  LLMService.swift
//  se-masked-quiz
//
//  Created for Issue #12: Local LLM Quiz Generation
//

import Foundation
import SwiftUI

#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon
#endif

// MARK: - LLMService Protocol

/// ローカルLLMサービス（モデルDL・ロード・推論を一本化）
protocol LLMService: Actor {
  /// モデルを読み込み
  /// - Parameter modelId: Hugging FaceモデルID
  func loadModel(id modelId: String) async throws

  /// モデルをアンロード
  func unloadModel() async

  /// モデルが読み込まれているか
  var isModelLoaded: Bool { get async }

  /// クイズを生成
  func generateQuizzes(
    from content: String,
    proposalId: String,
    difficulty: QuizDifficulty,
    count: Int
  ) async throws -> [LLMQuiz]

  // MARK: - Download Management

  /// モデルをダウンロード（DL完了後にcontainerを保持）
  func downloadModel(
    named modelName: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws

  /// ダウンロードをキャンセル
  func cancelDownload() async

  /// モデルを削除
  func deleteModel(named modelName: String) async throws

  /// モデルがダウンロード済みかどうか
  func isModelDownloaded(named modelName: String) async -> Bool

  /// 利用可能なストレージ容量をチェック
  func getAvailableStorage() async throws -> Int64

  /// モデルのサイズを取得
  func getModelSize(named modelName: String) async throws -> Int64
}

// MARK: - LLMService Implementation

actor LLMServiceImpl: LLMService {
  #if canImport(MLXLLM)
  private var modelContainer: ModelContainer?
  #endif

  private var modelLoaded: Bool = false
  private var currentModelId: String?
  private var currentDownloadTask: Task<Void, Error>?

  private let maxTokens: Int = LLMModelConfig.maxTokens
  private let temperature: Float = LLMModelConfig.temperature
  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  // MARK: - Model Loading

  var isModelLoaded: Bool {
    get async { modelLoaded }
  }

  func loadModel(id modelId: String) async throws {
    #if canImport(MLXLLM)
    // DL済みでcontainerを既に持っていればスキップ
    if modelContainer != nil && currentModelId == modelId {
      modelLoaded = true
      return
    }

    let configuration = ModelConfiguration(id: modelId)

    do {
      modelContainer = try await LLMModelFactory.shared.loadContainer(
        configuration: configuration,
        progressHandler: { progress in
          print("Model loading: \(Int(progress.fractionCompleted * 100))%")
        }
      )
      currentModelId = modelId
      modelLoaded = true
    } catch {
      throw LLMServiceError.mlxError(error)
    }
    #else
    currentModelId = modelId
    modelLoaded = true
    #endif
  }

  func unloadModel() async {
    #if canImport(MLXLLM)
    modelContainer = nil
    #endif
    modelLoaded = false
    currentModelId = nil
  }

  // MARK: - Download Management

  func downloadModel(
    named modelName: String,
    progressHandler: @escaping (Double) -> Void
  ) async throws {
    let estimatedSize = try await getModelSize(named: modelName)
    let availableStorage = try await getAvailableStorage()
    let requiredStorage = Int64(Double(estimatedSize) * 1.5)

    guard availableStorage >= requiredStorage else {
      throw LLMServiceError.insufficientStorage(
        required: requiredStorage,
        available: availableStorage
      )
    }

    #if canImport(MLXLLM)
    let task = Task<Void, Error> {
      let configuration = ModelConfiguration(id: modelName)
      let container = try await LLMModelFactory.shared.loadContainer(
        configuration: configuration,
        progressHandler: { progress in
          progressHandler(progress.fractionCompleted)
        }
      )
      // DL完了後にcontainerを保持（loadModelでの再ロード不要に）
      self.modelContainer = container
      self.currentModelId = modelName
      self.modelLoaded = true
    }
    currentDownloadTask = task

    do {
      try await task.value
      currentDownloadTask = nil
      setDownloadFlag(true, for: modelName)
    } catch {
      currentDownloadTask = nil
      if Task.isCancelled {
        throw LLMServiceError.cancelled
      }
      throw LLMServiceError.networkError(error)
    }
    #else
    throw LLMServiceError.mlxUnavailable
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
    await unloadModel()
    setDownloadFlag(false, for: modelName)
  }

  func isModelDownloaded(named modelName: String) async -> Bool {
    if getDownloadFlag(for: modelName) {
      return true
    }

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
      setDownloadFlag(true, for: modelName)
    }

    return exists
  }

  func getAvailableStorage() async throws -> Int64 {
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw LLMServiceError.fileSystemError(NSError(domain: "LLMService", code: -1))
    }

    let systemAttributes = try fileManager.attributesOfFileSystem(forPath: documentsURL.path)
    guard let freeSpace = systemAttributes[.systemFreeSize] as? Int64 else {
      throw LLMServiceError.fileSystemError(NSError(domain: "LLMService", code: -2))
    }

    return freeSpace
  }

  func getModelSize(named modelName: String) async throws -> Int64 {
    let option = LLMModelOption.allCases.first { $0.modelId == modelName }
    return option?.estimatedSizeBytes ?? LLMModelConfig.estimatedSizeBytes
  }

  // MARK: - Quiz Generation

  func generateQuizzes(
    from content: String,
    proposalId: String,
    difficulty: QuizDifficulty,
    count: Int
  ) async throws -> [LLMQuiz] {
    guard modelLoaded else {
      throw LLMServiceError.modelNotLoaded
    }

    guard !content.isEmpty else {
      throw LLMServiceError.invalidInput("Content is empty")
    }

    guard count > 0 else {
      throw LLMServiceError.invalidInput("Count must be greater than 0")
    }

    let prompt = QuizPromptTemplate.buildQuizGenerationPrompt(
      content: content,
      difficulty: difficulty,
      count: count
    )

    let generatedText = try await generateText(prompt: prompt)
    let response = try QuizPromptTemplate.parseResponse(generatedText)

    var quizzes: [LLMQuiz] = []
    for item in response.quizzes {
      guard QuizPromptTemplate.validate(item) else {
        continue
      }

      let quiz = LLMQuiz(
        proposalId: proposalId,
        question: item.question,
        correctAnswer: item.correctAnswer,
        wrongAnswers: item.wrongAnswers,
        explanation: item.explanation,
        conceptTested: item.conceptTested,
        difficulty: difficulty
      )
      quizzes.append(quiz)
    }

    return quizzes
  }

  // MARK: - Private: Text Generation

  private func generateText(prompt: String) async throws -> String {
    #if canImport(MLXLLM)
    guard let container = modelContainer else {
      throw LLMServiceError.modelNotLoaded
    }

    let result = try await container.perform { context in
      let input = UserInput(
        prompt: UserInput.Prompt.chat([
          .system(QuizPromptTemplate.systemPrompt),
          .user(prompt)
        ]),
        processing: .init()
      )
      let lmInput = try await context.processor.prepare(input: input)

      let generateParams = GenerateParameters(
        maxTokens: self.maxTokens,
        temperature: self.temperature
      )

      let output = try MLXLMCommon.generate(
        input: lmInput,
        parameters: generateParams,
        context: context
      ) { tokens in
        if tokens.count >= self.maxTokens {
          return .stop
        }
        return .more
      }

      return output.output
    }

    return result
    #else
    return stubQuizResponse(count: 3)
    #endif
  }

  private func stubQuizResponse(count: Int) -> String {
    let quizzes = (0..<count).map { index in
      """
      {
        "question": "stub quiz \(index + 1)",
        "correctAnswer": "correct",
        "wrongAnswers": ["wrong1", "wrong2", "wrong3"],
        "explanation": "stub response for non-MLX environment",
        "conceptTested": "test"
      }
      """
    }.joined(separator: ",\n")

    return """
    {
      "quizzes": [
        \(quizzes)
      ]
    }
    """
  }

  // MARK: - Private: UserDefaults / Hub Cache

  private static func downloadFlagKey(for modelName: String) -> String {
    "modelDownloaded_\(modelName)"
  }

  private func setDownloadFlag(_ value: Bool, for modelName: String) {
    let key = Self.downloadFlagKey(for: modelName)
    if value {
      userDefaults.set(true, forKey: key)
    } else {
      userDefaults.removeObject(forKey: key)
    }
  }

  private func getDownloadFlag(for modelName: String) -> Bool {
    userDefaults.bool(forKey: Self.downloadFlagKey(for: modelName))
  }

  private static func hubCacheDirectory(for modelName: String) -> URL {
    let cacheBase = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask
    )[0]
    let hubDir = cacheBase
      .appendingPathComponent("huggingface")
      .appendingPathComponent("hub")
    let sanitizedName = "models--" + modelName.replacingOccurrences(of: "/", with: "--")
    return hubDir.appendingPathComponent(sanitizedName)
  }
}

// MARK: - Errors

enum LLMServiceError: Error, LocalizedError {
  case modelNotLoaded
  case modelNotFound(path: URL)
  case invalidInput(String)
  case generationFailed(String)
  case mlxError(Error)
  case insufficientStorage(required: Int64, available: Int64)
  case cancelled
  case networkError(Error)
  case fileSystemError(Error)
  case mlxUnavailable

  var errorDescription: String? {
    switch self {
    case .modelNotLoaded:
      return "モデルが読み込まれていません。先にloadModel()を呼び出してください。"
    case .modelNotFound(let path):
      return "モデルファイルが見つかりません: \(path.path)"
    case .invalidInput(let message):
      return "無効な入力: \(message)"
    case .generationFailed(let message):
      return "クイズ生成に失敗しました: \(message)"
    case .mlxError(let error):
      return "MLXエラー: \(error.localizedDescription)"
    case .insufficientStorage(let required, let available):
      let requiredGB = Double(required) / 1_000_000_000
      let availableGB = Double(available) / 1_000_000_000
      return "ストレージ容量が不足しています。必要: \(String(format: "%.1f", requiredGB))GB、利用可能: \(String(format: "%.1f", availableGB))GB"
    case .cancelled:
      return "ダウンロードがキャンセルされました"
    case .networkError(let error):
      return "ネットワークエラー: \(error.localizedDescription)"
    case .fileSystemError(let error):
      return "ファイルシステムエラー: \(error.localizedDescription)"
    case .mlxUnavailable:
      return "このデバイスではMLXが利用できません"
    }
  }
}

// MARK: - Environment

extension LLMServiceImpl {
  static var defaultValue: any LLMService {
    LLMServiceImpl(userDefaults: .standard)
  }
}

private struct LLMServiceKey: EnvironmentKey {
  static var defaultValue: any LLMService {
    LLMServiceImpl.defaultValue
  }
}

extension EnvironmentValues {
  var llmService: any LLMService {
    get { self[LLMServiceKey.self] }
    set { self[LLMServiceKey.self] = newValue }
  }
}
