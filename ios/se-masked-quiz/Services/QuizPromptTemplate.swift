//
//  QuizPromptTemplate.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM Quiz Generation Prompts
//  Optimized for Qwen3.5-0.8B (4-bit)
//

import Foundation

// MARK: - QuizPromptTemplate

/// クイズ生成用のプロンプトテンプレート
/// Qwen3.5-0.8B (4-bit) 向けに最適化
struct QuizPromptTemplate {

  // MARK: - System Prompt

  /// システムプロンプト（LLMの役割定義）
  /// 小規模モデル向けに簡潔化
  static let systemPrompt = """
  You are a Swift quiz generator. Create multiple-choice questions about Swift Evolution proposals.
  Output ONLY valid JSON. No explanations outside JSON.
  """

  // MARK: - Quiz Generation Prompt

  /// クイズ生成プロンプトを構築
  /// - Parameters:
  ///   - content: Swift Evolution提案のコンテンツ
  ///   - difficulty: 難易度
  ///   - count: 生成するクイズ数
  /// - Returns: 構築されたプロンプト
  static func buildQuizGenerationPrompt(
    content: String,
    difficulty: QuizDifficulty,
    count: Int
  ) -> String {
    let clampedCount = min(count, LLMModelConfig.maxQuizCount)
    // コンテンツを最大800文字に制限（生成トークン枠を確保）
    let truncatedContent = String(content.prefix(800))
    let difficultyLevel = difficultyInstruction(for: difficulty)

    return """
    Create exactly \(clampedCount) multiple-choice quiz questions about the Swift proposal below.
    Difficulty: \(difficultyLevel)

    Proposal:
    \(truncatedContent)

    You MUST output ONLY a single JSON object. No markdown, no explanation, no HTML.
    Keep each answer under 5 words. Keep explanations under 20 words.

    Exact format:
    {"quizzes":[{"question":"...","correctAnswer":"...","wrongAnswers":["...","...","..."],"explanation":"...","conceptTested":"..."}]}
    """
  }

  // MARK: - Difficulty Instructions

  /// 難易度別の指示（簡潔版）
  private static func difficultyInstruction(for difficulty: QuizDifficulty) -> String {
    switch difficulty {
    case .beginner:
      return "Easy - basic terms and syntax"
    case .intermediate:
      return "Medium - understand usage and purpose"
    case .advanced:
      return "Hard - complex interactions and edge cases"
    }
  }

  // MARK: - Response Parsing

  /// LLMの応答からクイズを抽出
  struct QuizGenerationResponse: Codable {
    let quizzes: [GeneratedQuizItem]

    struct GeneratedQuizItem: Codable {
      let question: String
      let correctAnswer: String
      let wrongAnswers: [String]
      let explanation: String
      let conceptTested: String
    }
  }

  /// JSON応答をパース
  /// - Parameter jsonString: LLMからのJSON応答
  /// - Returns: パースされたクイズ生成応答
  /// - Throws: デコードエラー
  static func parseResponse(_ jsonString: String) throws -> QuizGenerationResponse {
    let cleaned = cleanJSONString(jsonString)

    guard let data = cleaned.data(using: .utf8) else {
      throw QuizPromptError.invalidJSON("Failed to convert string to data")
    }

    // camelCase → snake_case の順に試行（LLMの出力形式が不定のため）
    for strategy in [JSONDecoder.KeyDecodingStrategy.useDefaultKeys, .convertFromSnakeCase] {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = strategy

      if let result = try? decoder.decode(QuizGenerationResponse.self, from: data) {
        return result
      }

      let repaired = tryRepairJSON(cleaned)
      if let repairedData = repaired.data(using: .utf8),
         let result = try? decoder.decode(QuizGenerationResponse.self, from: repairedData) {
        return result
      }
    }

    // 両方失敗した場合、エラー詳細を出力
    let decoder = JSONDecoder()
    do {
      return try decoder.decode(QuizGenerationResponse.self, from: data)
    } catch {
      throw QuizPromptError.decodingFailed(error)
    }
  }

  /// JSON文字列をクリーンアップ
  private static func cleanJSONString(_ input: String) -> String {
    // JSONブロックを抽出（```jsonタグで囲まれている場合）
    if let jsonStart = input.range(of: "```json"),
       let jsonEnd = input.range(of: "```", range: jsonStart.upperBound..<input.endIndex) {
      return String(input[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // ```タグのみの場合
    if let jsonStart = input.range(of: "```"),
       let jsonEnd = input.range(of: "```", range: jsonStart.upperBound..<input.endIndex) {
      let extracted = String(input[jsonStart.upperBound..<jsonEnd.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if extracted.hasPrefix("{") {
        return extracted
      }
    }

    // 最初の{から最後の}までを抽出
    if let firstBrace = input.firstIndex(of: "{"),
       let lastBrace = input.lastIndex(of: "}") {
      return String(input[firstBrace...lastBrace])
    }

    return input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// 壊れたJSONの修復を試行
  private static func tryRepairJSON(_ input: String) -> String {
    var json = input

    // 末尾のカンマを修正
    json = json.replacingOccurrences(of: ",]", with: "]")
    json = json.replacingOccurrences(of: ",}", with: "}")

    // 閉じ括弧が不足している場合は追加
    let openBraces = json.filter { $0 == "{" }.count
    let closeBraces = json.filter { $0 == "}" }.count
    let openBrackets = json.filter { $0 == "[" }.count
    let closeBrackets = json.filter { $0 == "]" }.count

    if openBrackets > closeBrackets {
      json += String(repeating: "]", count: openBrackets - closeBrackets)
    }
    if openBraces > closeBraces {
      json += String(repeating: "}", count: openBraces - closeBraces)
    }

    return json
  }

  // MARK: - Quiz Validation

  /// 生成されたクイズを検証
  /// - Parameter item: 生成されたクイズアイテム
  /// - Returns: 検証が成功した場合true
  static func validate(_ item: QuizGenerationResponse.GeneratedQuizItem) -> Bool {
    // 質問が空でないか
    guard !item.question.isEmpty else { return false }

    // 正解が空でないか
    guard !item.correctAnswer.isEmpty else { return false }

    // 誤答が3つあるか（2つ以上あれば許容）
    guard item.wrongAnswers.count >= 2 else { return false }

    // すべての誤答が空でないか
    guard item.wrongAnswers.allSatisfy({ !$0.isEmpty }) else { return false }

    // 正解と誤答が重複していないか
    let allAnswers = [item.correctAnswer] + item.wrongAnswers
    guard Set(allAnswers).count == allAnswers.count else { return false }

    return true
  }
}

// MARK: - Errors

enum QuizPromptError: Error, LocalizedError {
  case invalidJSON(String)
  case decodingFailed(Error)
  case validationFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidJSON(let message):
      return "無効なJSON形式: \(message)"
    case .decodingFailed(let error):
      return "JSONデコードに失敗: \(error.localizedDescription)"
    case .validationFailed(let message):
      return "クイズの検証に失敗: \(message)"
    }
  }
}
