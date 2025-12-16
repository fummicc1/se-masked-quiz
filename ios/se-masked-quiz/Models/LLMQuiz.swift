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

  /// すべての選択肢（シャッフル済み）
  var allChoices: [String] {
    ([correctAnswer] + wrongAnswers).shuffled()
  }

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
