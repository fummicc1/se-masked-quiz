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

/// ローカルLLMサービス
protocol LLMService: Actor {
  /// モデルを読み込み
  /// - Parameter modelId: Hugging FaceモデルID
  func loadModel(id modelId: String) async throws

  /// モデルをアンロード
  func unloadModel() async

  /// モデルが読み込まれているか
  var isModelLoaded: Bool { get async }

  /// クイズを生成
  /// - Parameters:
  ///   - content: Swift Evolution提案のコンテンツ
  ///   - proposalId: 提案ID
  ///   - difficulty: クイズ難易度
  ///   - count: 生成するクイズ数
  /// - Returns: 生成されたLLMクイズの配列
  func generateQuizzes(
    from content: String,
    proposalId: String,
    difficulty: QuizDifficulty,
    count: Int
  ) async throws -> [LLMQuiz]
}

// MARK: - LLMService Implementation

actor LLMServiceImpl: LLMService {
  #if canImport(MLXLLM)
  private var modelContainer: ModelContainer?
  #endif

  private var modelLoaded: Bool = false
  private var currentModelId: String?

  // 生成パラメータ
  private let maxTokens: Int = 1024
  private let temperature: Float = 0.7

  // MARK: - Public Methods

  var isModelLoaded: Bool {
    get async { modelLoaded }
  }

  func loadModel(id modelId: String) async throws {
    #if canImport(MLXLLM)
    // MLX Swift LMでモデルをロード
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
    // MLXが利用できない場合はスタブ実装
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

    // プロンプトを構築
    let prompt = QuizPromptTemplate.buildQuizGenerationPrompt(
      content: content,
      difficulty: difficulty,
      count: count
    )

    // LLMでテキスト生成
    let generatedText = try await generateText(prompt: prompt)

    // JSON応答をパース
    let response = try QuizPromptTemplate.parseResponse(generatedText)

    // 検証とLLMQuizオブジェクトへの変換
    var quizzes: [LLMQuiz] = []
    for item in response.quizzes {
      guard QuizPromptTemplate.validate(item) else {
        continue  // 無効なクイズはスキップ
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

  // MARK: - Private Methods

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
        maxTokens: maxTokens,
        temperature: temperature
      )

      let output = try MLXLMCommon.generate(
        input: lmInput,
        parameters: generateParams,
        context: context
      ) { tokens in
        if tokens.count >= maxTokens {
          return .stop
        }
        return .more
      }

      return output.output
    }

    return result
    #else
    // MLXが利用できない場合はスタブ応答を返す
    return stubQuizResponse(count: 3)
    #endif
  }

  /// MLXが利用できない場合のスタブ応答
  private func stubQuizResponse(count: Int) -> String {
    let quizzes = (0..<count).map { index in
      """
      {
        "question": "スタブクイズ \(index + 1): このクイズはテスト用です",
        "correctAnswer": "正解",
        "wrongAnswers": ["誤答1", "誤答2", "誤答3"],
        "explanation": "これはMLXが利用できない環境でのスタブ応答です",
        "conceptTested": "テスト"
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
}

// MARK: - Errors

enum LLMServiceError: Error, LocalizedError {
  case modelNotLoaded
  case modelNotFound(path: URL)
  case invalidInput(String)
  case generationFailed(String)
  case mlxError(Error)

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
    }
  }
}

// MARK: - Environment

extension LLMServiceImpl {
  static var defaultValue: any LLMService {
    LLMServiceImpl()
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
