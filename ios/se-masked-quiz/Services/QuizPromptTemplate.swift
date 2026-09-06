//
//  QuizPromptTemplate.swift
//  se-masked-quiz
//
// LLM生成クイズ用プロンプトテンプレート
//

import Foundation

// MARK: - QuizPromptTemplate

/// クイズ生成用のプロンプトテンプレート。選択中モデル（small/medium）のいずれでも動作する簡潔な指示にしている。
struct QuizPromptTemplate {

  // MARK: - System Prompt

  /// システムプロンプト（LLMの役割定義）。出力トークン数を抑えるため簡潔にしている。
  static let systemPrompt = """
  You are a Swift quiz generator. Create multiple-choice questions about Swift Evolution proposals.
  Output ONLY valid JSON. No explanations outside JSON.
  """

  // MARK: - Quiz Generation Prompt

  static func stripHTML(_ html: String) -> String {
    guard !html.isEmpty else { return html }
    // NSAttributedStringよりも軽量な正規表現ベースの除去
    return html
      .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// クイズ生成プロンプトを構築
  /// - Parameters:
  ///   - content: Swift Evolution提案のコンテンツ（HTML可）
  ///   - difficulty: 難易度
  ///   - count: 生成するクイズ数
  /// - Returns: 構築されたプロンプト
  static func buildQuizGenerationPrompt(
    content: String,
    difficulty: QuizDifficulty,
    count: Int
  ) -> String {
    let clampedCount = min(count, LLMModelConfig.maxQuizCount)
    let plainContent = stripHTML(content)
    // コンテンツを最大800文字に制限（生成トークン枠を確保）
    let truncatedContent = String(plainContent.prefix(800))
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

  private static func cleanJSONString(_ input: String) -> String {
    if let jsonStart = input.range(of: "```json"),
       let jsonEnd = input.range(of: "```", range: jsonStart.upperBound..<input.endIndex) {
      return String(input[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let jsonStart = input.range(of: "```"),
       let jsonEnd = input.range(of: "```", range: jsonStart.upperBound..<input.endIndex) {
      let extracted = String(input[jsonStart.upperBound..<jsonEnd.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if extracted.hasPrefix("{") {
        return extracted
      }
    }

    if let firstBrace = input.firstIndex(of: "{"),
       let lastBrace = input.lastIndex(of: "}") {
      return String(input[firstBrace...lastBrace])
    }

    return input.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func tryRepairJSON(_ input: String) -> String {
    var json = input

    json = json.replacingOccurrences(of: ",]", with: "]")
    json = json.replacingOccurrences(of: ",}", with: "}")

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

  static func validate(_ item: QuizGenerationResponse.GeneratedQuizItem) -> Bool {
    guard !item.question.isEmpty else { return false }

    guard !item.correctAnswer.isEmpty else { return false }

    // 誤答が3つあるか（2つ以上あれば許容）
    guard item.wrongAnswers.count >= 2 else { return false }

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
