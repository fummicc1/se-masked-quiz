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
  /// Save the score for a proposal
  func saveScore(_ score: ProposalScore) async

  /// Get all saved scores
  func getAllScores() async -> [String: ProposalScore]

  /// Get score for a specific proposal
  func getScore(for proposalId: String) async -> ProposalScore?

  /// Fetch quiz for a specific proposal
  func fetchQuiz(for proposalId: String) async throws -> [Quiz]

  /// Reset score for a specific proposal
  func resetScore(for proposalId: String) async

  /// Get all quiz counts for all proposals
  /// - Returns: Dictionary mapping proposal IDs to their quiz counts
  func getAllQuizCounts() async throws -> [String: Int]

  // Issue #12: LLM生成クイズ管理
  /// LLM生成クイズを保存
  /// - Parameters:
  ///   - quizzes: 保存するクイズの配列
  ///   - proposalId: 提案ID
  func saveLLMGeneratedQuizzes(_ quizzes: [Quiz], for proposalId: String) async

  /// LLM生成クイズを取得
  /// - Parameter proposalId: 提案ID
  /// - Returns: LLM生成クイズの配列（存在しない場合は空配列）
  func getLLMGeneratedQuizzes(for proposalId: String) async -> [Quiz]

  /// R2とLLM生成クイズを統合して取得
  /// - Parameter proposalId: 提案ID
  /// - Returns: R2クイズとLLM生成クイズを合わせた配列
  func fetchAllQuizzes(for proposalId: String) async throws -> [Quiz]

  /// LLM生成クイズが存在するかチェック
  /// - Parameter proposalId: 提案ID
  /// - Returns: LLM生成クイズが存在する場合true
  func hasLLMGeneratedQuizzes(for proposalId: String) async -> Bool

  /// LLM生成クイズを削除
  /// - Parameter proposalId: 提案ID
  func deleteLLMGeneratedQuizzes(for proposalId: String) async
}

// MARK: - Repository Implementation

actor QuizRepositoryImpl: QuizRepository {
  private let s3Client: S3Client
  private let quizBucket = "se-masked-quiz"
  private let userDefaults: UserDefaults

  // MARK: - Cache
  private var answersCache: QuizAnswers?
  private var answersCacheTimestamp: Date?
  private let cacheExpirationInterval: TimeInterval = 43200  // 12時間（answers.jsonは1日1回更新）

  private static let scoreKey = "proposal_scores"
  private static let llmQuizzesKey = "llm_generated_quizzes"  // Issue #12: LLM生成クイズ用のキー

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

  // MARK: - Score Management

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

  // MARK: - Quiz Management

  func fetchQuiz(for proposalId: String) async throws -> [Quiz] {
    // 共通メソッドでanswers.jsonを取得（キャッシュ利用）
    let answers = try await fetchAnswersJson()

    guard let proposalAnswers = answers.answers[proposalId] else {
      throw QuizError.proposalNotFound
    }

    // Sort answers by index to ensure correct order
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
    // 共通メソッドでanswers.jsonを取得（キャッシュ利用）
    let answers = try await fetchAnswersJson()

    // クイズ数マップを生成
    let quizCounts = answers.answers.mapValues { $0.count }

    return quizCounts
  }

  // MARK: - LLM Generated Quiz Management (Issue #12)

  func saveLLMGeneratedQuizzes(_ quizzes: [Quiz], for proposalId: String) async {
    var allLLMQuizzes = await getAllLLMGeneratedQuizzes()
    allLLMQuizzes[proposalId] = quizzes

    if let encoded = try? JSONEncoder().encode(allLLMQuizzes) {
      userDefaults.set(encoded, forKey: Self.llmQuizzesKey)
    }
  }

  func getLLMGeneratedQuizzes(for proposalId: String) async -> [Quiz] {
    let allLLMQuizzes = await getAllLLMGeneratedQuizzes()
    return allLLMQuizzes[proposalId] ?? []
  }

  func fetchAllQuizzes(for proposalId: String) async throws -> [Quiz] {
    // R2からのクイズを取得
    let r2Quizzes = try await fetchQuiz(for: proposalId)

    // LLM生成クイズを取得
    let llmQuizzes = await getLLMGeneratedQuizzes(for: proposalId)

    // 統合して返す（R2クイズが先、LLM生成クイズが後）
    var allQuizzes = r2Quizzes

    // LLM生成クイズのindexを調整（R2クイズの最大index + 1から開始）
    let maxR2Index = r2Quizzes.map { $0.index }.max() ?? -1
    let adjustedLLMQuizzes = llmQuizzes.enumerated().map { offset, quiz in
      var adjustedQuiz = quiz
      adjustedQuiz.index = maxR2Index + 1 + offset
      return adjustedQuiz
    }

    allQuizzes.append(contentsOf: adjustedLLMQuizzes)
    return allQuizzes
  }

  func hasLLMGeneratedQuizzes(for proposalId: String) async -> Bool {
    let llmQuizzes = await getLLMGeneratedQuizzes(for: proposalId)
    return !llmQuizzes.isEmpty
  }

  func deleteLLMGeneratedQuizzes(for proposalId: String) async {
    var allLLMQuizzes = await getAllLLMGeneratedQuizzes()
    allLLMQuizzes.removeValue(forKey: proposalId)

    if let encoded = try? JSONEncoder().encode(allLLMQuizzes) {
      userDefaults.set(encoded, forKey: Self.llmQuizzesKey)
    }
  }

  // MARK: - Private Helpers

  /// Fetch answers.json from R2 with caching
  /// - Returns: Decoded QuizAnswers object
  private func fetchAnswersJson() async throws -> QuizAnswers {
    // キャッシュチェック
    if let cache = answersCache,
      let timestamp = answersCacheTimestamp,
      Date().timeIntervalSince(timestamp) < cacheExpirationInterval
    {
      return cache
    }

    // R2から取得
    let input = GetObjectInput(bucket: quizBucket, key: "answers.json")
    let contents = try await s3Client.getObject(input: input)
    let binary = try? await contents.body?.readData()
    guard let binary else {
      throw QuizError.invalidResponse
    }

    // JSONデコード
    let answers = try JSONDecoder().decode(QuizAnswers.self, from: binary)

    // キャッシュ更新
    answersCache = answers
    answersCacheTimestamp = Date()

    return answers
  }

  /// Get all LLM-generated quizzes from UserDefaults
  /// - Returns: Dictionary mapping proposal IDs to their LLM-generated quizzes
  private func getAllLLMGeneratedQuizzes() async -> [String: [Quiz]] {
    guard let data = userDefaults.data(forKey: Self.llmQuizzesKey),
      let quizzes = try? JSONDecoder().decode([String: [Quiz]].self, from: data)
    else {
      return [:]
    }
    return quizzes
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
