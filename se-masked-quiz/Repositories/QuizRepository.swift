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

protocol QuizRepository: Actor, EnvironmentKey {
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
}

// MARK: - Repository Implementation

actor QuizRepositoryImpl: QuizRepository {
  private let s3Client: S3Client
  private let quizBucket = "se-masked-quiz"
  private let userDefaults: UserDefaults

  private static let scoreKey = "proposal_scores"
  private var similarityMap: [String: [String]]

  init(
    cloudflareR2Endpoint: String,
    r2AccessKey: String,
    r2SecretKey: String,
    userDefaults: UserDefaults = .standard,
    similarityMap: [String: [String]] = [:]
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
    self.similarityMap = similarityMap
    Task {
      do {
        try await update { s in
          s.similarityMap = try await fetchSimilarityMap()
        }
      } catch {
        print("Failed to fetch frequent words or similarity map: \(error)")
      }
    }
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
    let input = GetObjectInput(bucket: quizBucket, key: "answers.json")
    let contents = try await s3Client.getObject(input: input)
    let binary = try? await contents.body?.readData()
    guard let binary else {
      throw QuizError.invalidResponse
    }

    let answers = try JSONDecoder().decode(QuizAnswers.self, from: binary)
    guard let proposalAnswers = answers.answers[proposalId] else {
      throw QuizError.proposalNotFound
    }

    // Sort answers by index to ensure correct order
    let sortedAnswers = proposalAnswers.sorted { $0.index < $1.index }

    self.similarityMap = try await fetchSimilarityMap()

    return sortedAnswers.map { answer in
      return Quiz(
        id: UUID().uuidString,
        proposalId: proposalId,
        index: answer.index,
        answer: answer.answer,
        choices: similarityMap[answer.answer]?.shuffled().prefix(3).map(\.self) ?? []
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

  /// - Returns: A dictionary mapping word lengths to arrays of words which are similar to the answer
  func fetchSimilarityMap() async throws -> [String: [String]] {
    guard similarityMap.isEmpty else {
      return similarityMap
    }
    let input = GetObjectInput(bucket: quizBucket, key: "similarity_map.json")
    let contents = try await s3Client.getObject(input: input)
    let binary = try? await contents.body?.readData()
    guard let binary else {
      throw QuizError.failedToFetchSimilarityMap
    }
    let similarityMap = try JSONDecoder().decode([String: [String]].self, from: binary)
    return similarityMap
  }

  // MARK: - Private Helpers

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
