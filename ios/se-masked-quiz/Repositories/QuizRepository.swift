//
//  QuizRepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/09.
//

import AWSS3
import AWSSDKIdentity
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

  /// Fetch mask quiz for a specific proposal from R2
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
  private let s3Client: S3Client
  private let quizBucket = "se-masked-quiz"
  private let userDefaults: UserDefaults

  // MARK: - Cache
  private var answersCache: QuizAnswers?
  private var answersCacheTimestamp: Date?
  private let cacheExpirationInterval: TimeInterval = 43200  // 12時間

  private static let scoreKey = "proposal_scores"
  private static let llmQuizzesKey = "llm_quizzes"
  private static let llmQuizScoresKey = "llm_quiz_scores"

  init(
    cloudflareR2Endpoint: String,
    r2AccessKey: String,
    r2SecretKey: String,
    userDefaults: UserDefaults = .standard
  ) {
    let identity = AWSCredentialIdentity(
      accessKey: r2AccessKey,
      secret: r2SecretKey
    )
    let identityResolver = try! StaticAWSCredentialIdentityResolver(identity)
    self.s3Client = .init(
      config: try! .init(
        awsCredentialIdentityResolver: identityResolver,
        region: "auto",
        endpoint: cloudflareR2Endpoint
      )
    )
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
    let answers = try await fetchAnswersJson()

    guard let proposalAnswers = answers.answers[proposalId] else {
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
    let answers = try await fetchAnswersJson()
    return answers.answers.mapValues { $0.count }
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

  private func fetchAnswersJson() async throws -> QuizAnswers {
    if let cache = answersCache,
      let timestamp = answersCacheTimestamp,
      Date().timeIntervalSince(timestamp) < cacheExpirationInterval
    {
      return cache
    }

    let input = GetObjectInput(bucket: quizBucket, key: "answers.json")
    let contents = try await s3Client.getObject(input: input)
    let binary = try? await contents.body?.readData()
    guard let binary else {
      throw QuizError.invalidResponse
    }

    let answers = try JSONDecoder().decode(QuizAnswers.self, from: binary)

    answersCache = answers
    answersCacheTimestamp = Date()

    return answers
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

  private func update(run: (isolated QuizRepositoryImpl) async throws -> Void) async throws {
    try await run(self)
  }
}

// MARK: - Models

extension QuizRepositoryImpl {
  fileprivate struct QuizAnswers: Codable {
    var answers: [String: [QuizAnswer]]

    struct QuizAnswer: Codable {
      var index: Int
      var answer: String
      var options: [String]
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      self.answers = try container.decode([String: [QuizAnswer]].self)
    }
  }

  fileprivate struct WordFrequency: Codable {
    let word: String
    let frequency: Int
  }
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
    QuizRepositoryImpl(
      cloudflareR2Endpoint: Env.cloudflareR2Endpoint,
      r2AccessKey: Env.cloudflareR2AccessKey,
      r2SecretKey: Env.cloudflareR2SecretKey
    )
  }
}

extension EnvironmentValues {
  var quizRepository: any QuizRepository {
    get { self[QuizRepositoryImpl.self] }
    set { self[QuizRepositoryImpl.self] = newValue }
  }
}

extension UserDefaults: @retroactive @unchecked Sendable {}
