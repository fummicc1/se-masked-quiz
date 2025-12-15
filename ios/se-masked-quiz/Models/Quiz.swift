import Foundation

// Issue #12: クイズ難易度
enum QuizDifficulty: String, Codable {
  case beginner = "初級"      // 基本的な用語・概念
  case intermediate = "中級"  // 提案の詳細理解
  case advanced = "上級"      // 複雑な概念・関連性
}

// Issue #12: クイズのソース（R2または LLM生成）
enum QuizSource: String, Codable {
  case r2 = "r2"                  // R2から取得した既存クイズ
  case llmGenerated = "llm"       // LLMで生成されたクイズ
}

struct Quiz: Codable, Identifiable {
  var id: String
  var proposalId: String
  var index: Int
  var answer: String
  var choices: [String]  // 誤答の選択肢3つ
  var allChoices: [String]

  // Issue #12: LLM生成クイズ対応
  var question: String?          // LLM生成クイズの質問文
  var explanation: String?       // 解説（LLM生成時のみ）
  var source: QuizSource         // クイズのソース
  var generatedAt: Date?         // 生成日時
  var complexityScore: Double?   // 0.0〜1.0

  // 後方互換性のためのcomputed property
  var isLLMGenerated: Bool {
    source == .llmGenerated
  }

  init(
    id: String,
    proposalId: String,
    index: Int,
    answer: String,
    choices: [String],
    question: String? = nil,
    explanation: String? = nil,
    source: QuizSource = .r2,
    generatedAt: Date? = nil,
    complexityScore: Double? = nil
  ) {
    self.id = id
    self.proposalId = proposalId
    self.index = index
    self.answer = answer
    self.choices = choices
    allChoices = (choices + [answer]).shuffled()
    self.question = question
    self.explanation = explanation
    self.source = source
    self.generatedAt = source == .llmGenerated ? (generatedAt ?? Date()) : generatedAt
    self.complexityScore = complexityScore
  }

  // Issue #12: 後方互換性のためのイニシャライザ
  init(
    id: String,
    proposalId: String,
    index: Int,
    answer: String,
    choices: [String],
    isLLMGenerated: Bool,
    generatedAt: Date? = nil,
    complexityScore: Double? = nil
  ) {
    self.init(
      id: id,
      proposalId: proposalId,
      index: index,
      answer: answer,
      choices: choices,
      question: nil,
      explanation: nil,
      source: isLLMGenerated ? .llmGenerated : .r2,
      generatedAt: generatedAt,
      complexityScore: complexityScore
    )
  }

  // CodingKeys for migration support
  private enum CodingKeys: String, CodingKey {
    case id, proposalId, index, answer, choices, allChoices
    case question, explanation, source, generatedAt, complexityScore
    case isLLMGenerated  // 後方互換性
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    proposalId = try container.decode(String.self, forKey: .proposalId)
    index = try container.decode(Int.self, forKey: .index)
    answer = try container.decode(String.self, forKey: .answer)
    choices = try container.decode([String].self, forKey: .choices)
    allChoices = try container.decode([String].self, forKey: .allChoices)
    question = try container.decodeIfPresent(String.self, forKey: .question)
    explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
    complexityScore = try container.decodeIfPresent(Double.self, forKey: .complexityScore)

    // sourceまたはisLLMGeneratedのいずれかをサポート（後方互換性）
    if let source = try container.decodeIfPresent(QuizSource.self, forKey: .source) {
      self.source = source
    } else if let isLLM = try container.decodeIfPresent(Bool.self, forKey: .isLLMGenerated) {
      self.source = isLLM ? .llmGenerated : .r2
    } else {
      self.source = .r2
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(proposalId, forKey: .proposalId)
    try container.encode(index, forKey: .index)
    try container.encode(answer, forKey: .answer)
    try container.encode(choices, forKey: .choices)
    try container.encode(allChoices, forKey: .allChoices)
    try container.encodeIfPresent(question, forKey: .question)
    try container.encodeIfPresent(explanation, forKey: .explanation)
    try container.encode(source, forKey: .source)
    try container.encodeIfPresent(generatedAt, forKey: .generatedAt)
    try container.encodeIfPresent(complexityScore, forKey: .complexityScore)
  }
}

struct QuestionResult: Codable, Equatable {
  let index: Int
  let isCorrect: Bool
  let answer: String
  let userAnswer: String
}

struct ProposalScore: Codable {
  let proposalId: String
  let questionResults: [QuestionResult]
  let timestamp: Date

  var correctCount: Int {
    questionResults.filter { $0.isCorrect }.count
  }

  var totalCount: Int {
    questionResults.count
  }

  var percentage: Double {
    guard totalCount > 0 else { return 0 }
    return Double(correctCount) / Double(totalCount) * 100
  }

  init(proposalId: String, questionResults: [QuestionResult], timestamp: Date = Date()) {
    self.proposalId = proposalId
    self.questionResults = questionResults
    self.timestamp = timestamp
  }
}
