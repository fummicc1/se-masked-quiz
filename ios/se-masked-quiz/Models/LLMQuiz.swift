//
//  LLMQuiz.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM-generated Quiz Domain Model
//

import Foundation

/// LLM生成クイズのドメインモデル
/// R2からのマスク穴埋めクイズ（Quiz）とは異なり、
/// 質問文と解説を持つ独立した質問応答形式のクイズ
struct LLMQuiz: Codable, Identifiable, Equatable {
  let id: String
  let proposalId: String
  let question: String
  let correctAnswer: String
  let wrongAnswers: [String]
  let explanation: String
  let conceptTested: String
  let difficulty: QuizDifficulty
  let generatedAt: Date

  /// シャッフル済み選択肢（生成時に一度だけシャッフル）
  let allChoices: [String]

  init(
    id: String = UUID().uuidString,
    proposalId: String,
    question: String,
    correctAnswer: String,
    wrongAnswers: [String],
    explanation: String,
    conceptTested: String,
    difficulty: QuizDifficulty,
    generatedAt: Date = Date()
  ) {
    self.id = id
    self.proposalId = proposalId
    self.question = question
    self.correctAnswer = correctAnswer
    self.wrongAnswers = wrongAnswers
    self.explanation = explanation
    self.conceptTested = conceptTested
    self.difficulty = difficulty
    self.generatedAt = generatedAt
    self.allChoices = ([correctAnswer] + wrongAnswers).shuffled()
  }

  // 既存UserDefaultsデータとの互換性: allChoicesキーが存在しない場合はシャッフル生成
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    proposalId = try container.decode(String.self, forKey: .proposalId)
    question = try container.decode(String.self, forKey: .question)
    correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
    wrongAnswers = try container.decode([String].self, forKey: .wrongAnswers)
    explanation = try container.decode(String.self, forKey: .explanation)
    conceptTested = try container.decode(String.self, forKey: .conceptTested)
    difficulty = try container.decode(QuizDifficulty.self, forKey: .difficulty)
    generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    allChoices = try container.decodeIfPresent([String].self, forKey: .allChoices)
      ?? ([correctAnswer] + wrongAnswers).shuffled()
  }
}

/// LLMクイズの回答結果
struct LLMQuizResult: Codable, Equatable {
  let quizId: String
  let isCorrect: Bool
  let correctAnswer: String
  let userAnswer: String
  let answeredAt: Date

  init(
    quizId: String,
    isCorrect: Bool,
    correctAnswer: String,
    userAnswer: String,
    answeredAt: Date = Date()
  ) {
    self.quizId = quizId
    self.isCorrect = isCorrect
    self.correctAnswer = correctAnswer
    self.userAnswer = userAnswer
    self.answeredAt = answeredAt
  }
}

/// LLMクイズのスコア（提案単位）
struct LLMQuizScore: Codable {
  let proposalId: String
  let results: [LLMQuizResult]
  let lastUpdated: Date

  var correctCount: Int {
    results.filter(\.isCorrect).count
  }

  var totalCount: Int {
    results.count
  }

  var percentage: Double {
    guard totalCount > 0 else { return 0 }
    return Double(correctCount) / Double(totalCount) * 100
  }

  init(
    proposalId: String,
    results: [LLMQuizResult],
    lastUpdated: Date = Date()
  ) {
    self.proposalId = proposalId
    self.results = results
    self.lastUpdated = lastUpdated
  }
}
