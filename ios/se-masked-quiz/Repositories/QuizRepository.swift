//
//  QuizRepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/09.
//

import Foundation
import SwiftUI

// MARK: - Repository Protocol

/// @mockable
protocol QuizRepository: Actor {
  /// Save the score for a proposal (mask quiz)
  func saveScore(_ score: ProposalScore) async

  /// Get all saved scores (mask quiz)
  func getAllScores() async -> [String: ProposalScore]

  /// Get score for a specific proposal (mask quiz)
  func getScore(for proposalId: String) async -> ProposalScore?

  /// Fetch mask quiz for a specific proposal from Payload API
  func fetchQuiz(for proposalId: String) async throws -> [Quiz]

  /// Reset score for a specific proposal (mask quiz)
  func resetScore(for proposalId: String) async

  /// Get all quiz counts for all proposals
  func getAllQuizCounts() async throws -> [String: Int]

  // MARK: - LLM Quiz Management

  /// LLM生成クイズを保存
  func saveLLMQuizzes(_ quizzes: [LLMQuiz], for proposalId: String) async

  /// LLM生成クイズを取得
  func getLLMQuizzes(for proposalId: String) async -> [LLMQuiz]

  /// LLM生成クイズが存在するかチェック
  func hasLLMQuizzes(for proposalId: String) async -> Bool

  /// LLM生成クイズを削除
  func deleteLLMQuizzes(for proposalId: String) async

  /// LLMクイズスコアを保存
  func saveLLMQuizScore(_ score: LLMQuizScore) async

  /// LLMクイズスコアを取得
  func getLLMQuizScore(for proposalId: String) async -> LLMQuizScore?

  /// LLMクイズスコアをリセット
  func resetLLMQuizScore(for proposalId: String) async
}

// MARK: - Repository Implementation

actor QuizRepositoryImpl: QuizRepository {
  private let userDefaults: UserDefaults

  // MARK: - Cache
  private var answersCache: [String: [QuizAnswer]]?
  private var answersCacheTimestamp: Date?
  private let cacheExpirationInterval: TimeInterval = 43200  // 12時間

  private static let scoreKey = "proposal_scores"
  private static let llmQuizzesKey = "llm_quizzes"
  private static let llmQuizScoresKey = "llm_quiz_scores"

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  // MARK: - Mask Quiz Score Management

  func saveScore(_ score: ProposalScore) async {
    var scores = await getAllScores()
    scores[score.proposalId] = score

    if let encoded = try? JSONEncoder().encode(scores) {
      userDefaults.set(encoded, forKey: Self.scoreKey)
    }
  }

  func getAllScores() async -> [String: ProposalScore] {
    guard let data = userDefaults.data(forKey: Self.scoreKey),
      let scores = try? JSONDecoder().decode([String: ProposalScore].self, from: data)
    else {
      return [:]
    }
    return scores
  }

  func getScore(for proposalId: String) async -> ProposalScore? {
    return await getAllScores()[proposalId]
  }

  // MARK: - Mask Quiz Management

  func fetchQuiz(for proposalId: String) async throws -> [Quiz] {
    let allAnswers = try await fetchAllAnswers()

    guard let proposalAnswers = allAnswers[proposalId] else {
      throw QuizError.proposalNotFound
    }

    let sortedAnswers = proposalAnswers.sorted { $0.index < $1.index }

    return sortedAnswers.map { answer in
      return Quiz(
        id: UUID().uuidString,
        proposalId: proposalId,
        index: answer.index,
        answer: answer.answer,
        choices: answer.options
      )
    }
  }

  func resetScore(for proposalId: String) async {
    var scores = await getAllScores()
    scores.removeValue(forKey: proposalId)

    if let encoded = try? JSONEncoder().encode(scores) {
      userDefaults.set(encoded, forKey: Self.scoreKey)
    }
  }

  func getAllQuizCounts() async throws -> [String: Int] {
    let allAnswers = try await fetchAllAnswers()
    return allAnswers.mapValues { $0.count }
  }

  // MARK: - LLM Quiz Management

  func saveLLMQuizzes(_ quizzes: [LLMQuiz], for proposalId: String) async {
    var allLLMQuizzes = await getAllLLMQuizzes()
    allLLMQuizzes[proposalId] = quizzes

    if let encoded = try? JSONEncoder().encode(allLLMQuizzes) {
      userDefaults.set(encoded, forKey: Self.llmQuizzesKey)
    }
  }

  func getLLMQuizzes(for proposalId: String) async -> [LLMQuiz] {
    let allLLMQuizzes = await getAllLLMQuizzes()
    return allLLMQuizzes[proposalId] ?? []
  }

  func hasLLMQuizzes(for proposalId: String) async -> Bool {
    let llmQuizzes = await getLLMQuizzes(for: proposalId)
    return !llmQuizzes.isEmpty
  }

  func deleteLLMQuizzes(for proposalId: String) async {
    var allLLMQuizzes = await getAllLLMQuizzes()
    allLLMQuizzes.removeValue(forKey: proposalId)

    if let encoded = try? JSONEncoder().encode(allLLMQuizzes) {
      userDefaults.set(encoded, forKey: Self.llmQuizzesKey)
    }

    // スコアも削除
    await resetLLMQuizScore(for: proposalId)
  }

  // MARK: - LLM Quiz Score Management

  func saveLLMQuizScore(_ score: LLMQuizScore) async {
    var scores = await getAllLLMQuizScores()
    scores[score.proposalId] = score

    if let encoded = try? JSONEncoder().encode(scores) {
      userDefaults.set(encoded, forKey: Self.llmQuizScoresKey)
    }
  }

  func getLLMQuizScore(for proposalId: String) async -> LLMQuizScore? {
    let scores = await getAllLLMQuizScores()
    return scores[proposalId]
  }

  func resetLLMQuizScore(for proposalId: String) async {
    var scores = await getAllLLMQuizScores()
    scores.removeValue(forKey: proposalId)

    if let encoded = try? JSONEncoder().encode(scores) {
      userDefaults.set(encoded, forKey: Self.llmQuizScoresKey)
    }
  }

  // MARK: - Private Helpers

  private func fetchAllAnswers() async throws -> [String: [QuizAnswer]] {
    if let cache = answersCache,
      let timestamp = answersCacheTimestamp,
      Date().timeIntervalSince(timestamp) < cacheExpirationInterval
    {
      return cache
    }

    let baseURL = Env.serverBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = URL(string: "\(baseURL)/api/quiz-answers?limit=1000") else {
      throw QuizError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("users API-Key \(Env.serverApiKey)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw QuizError.invalidResponse
    }

    let decoded = try JSONDecoder().decode(PayloadListResponse<PayloadQuizAnswer>.self, from: data)

    var result: [String: [QuizAnswer]] = [:]
    for doc in decoded.docs {
      result[doc.proposalId] = doc.answers
    }

    answersCache = result
    answersCacheTimestamp = Date()

    return result
  }

  private func getAllLLMQuizzes() async -> [String: [LLMQuiz]] {
    guard let data = userDefaults.data(forKey: Self.llmQuizzesKey),
      let quizzes = try? JSONDecoder().decode([String: [LLMQuiz]].self, from: data)
    else {
      return [:]
    }
    return quizzes
  }

  private func getAllLLMQuizScores() async -> [String: LLMQuizScore] {
    guard let data = userDefaults.data(forKey: Self.llmQuizScoresKey),
      let scores = try? JSONDecoder().decode([String: LLMQuizScore].self, from: data)
    else {
      return [:]
    }
    return scores
  }
}

// MARK: - Models

struct QuizAnswer: Codable, Sendable {
  var index: Int
  var answer: String
  var options: [String]
}

struct PayloadQuizAnswer: Decodable, Sendable {
  let id: Int
  let proposalId: String
  let answers: [QuizAnswer]
}

// MARK: - Errors

enum QuizError: Error {
  case invalidResponse
  case failedToFetchSimilarityMap
  case proposalNotFound
}

// MARK: - Environment

extension QuizRepositoryImpl: EnvironmentKey {
  static var defaultValue: any QuizRepository {
    QuizRepositoryImpl()
  }
}

extension EnvironmentValues {
  var quizRepository: any QuizRepository {
    get { self[QuizRepositoryImpl.self] }
    set { self[QuizRepositoryImpl.self] = newValue }
  }
}

extension UserDefaults: @retroactive @unchecked Sendable {}
