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
  private var wordCandidates = [Int: [String]]()
  private let userDefaults: UserDefaults

  private static let scoreKey = "proposal_scores"

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
    Task {
      do {
        func update(run: (isolated QuizRepositoryImpl) async throws -> Void) async throws {
          try await run(self)
        }
        try await update { s in
          s.wordCandidates = try await fetchFrequentWords()
        }
      } catch {
        print("Failed to fetch frequent words: \(error)")
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

    return sortedAnswers.map { answer in
      return Quiz(
        id: UUID().uuidString,
        proposalId: proposalId,
        index: answer.index,
        answer: answer.answer,
        choices: generateRandomChoices(excluding: answer.answer)
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

  // MARK: - Private Helpers

  private func generateRandomChoices(excluding answer: String) -> [String] {
    let candidates = wordCandidates[answer.count] ?? []
    return Array(candidates.shuffled().prefix(3))
  }

  private func fetchFrequentWords() async throws -> [Int: [String]] {
    let input = GetObjectInput(bucket: quizBucket, key: "word_freq_hist.json")
    let contents = try await s3Client.getObject(input: input)
    guard let binary = try await contents.body?.readData() else {
      throw QuizError.invalidResponse
    }

    let wordFrequencies = try JSONDecoder().decode([WordFrequency].self, from: binary)
    return Dictionary(grouping: wordFrequencies.map(\.word)) { $0.count }
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
