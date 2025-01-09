//
//  QuizRepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/09.
//

import Foundation
import SwiftUI
import AWSS3
import AWSSDKIdentity

actor QuizRepository {
    
    private let s3Client: S3Client
    private let quizBucket = "se-masked-quiz"
    private var wordCandidates = [Int: [String]]()

    init(cloudflareR2Endpoint: String, r2AccessKey: String, r2SecretKey: String) {
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
        Task {
            do {
                func update(run: (isolated QuizRepository) async throws -> ()) async throws {
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

    private struct QuizAnswers: Codable {
        var answers: [String: [QuizAnswer]]
        
        struct QuizAnswer: Codable {
            var index: Int
            var answer: String
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.answers = try container.decode([String : [QuizRepository.QuizAnswers.QuizAnswer]].self)
        }
    }
    
    private struct WordFrequency: Codable {
        let word: String
        let frequency: Int
    }
    
    private func fetchFrequentWords() async throws -> [Int: [String]] {
        let input = GetObjectInput(bucket: quizBucket, key: "word_freq_hist.json")
        let contents = try await s3Client.getObject(input: input)
        guard let binary = try await contents.body?.readData() else {
            throw URLError(.badServerResponse)
        }
        
        let wordFrequencies = try JSONDecoder().decode([WordFrequency].self, from: binary)
        
        // Group words by character count
        return Dictionary(grouping: wordFrequencies.map(\.word)) { $0.count }
    }

    func fetchQuiz(for proposalId: String) async throws -> [Quiz] {
        let input = GetObjectInput(bucket: quizBucket, key: "answers.json")
        let contents = try await s3Client.getObject(input: input)
        let binary = try? await contents.body?.readData()
        guard let binary else {
            throw URLError(.badServerResponse)
        }
        
        let answers = try JSONDecoder().decode(QuizAnswers.self, from: binary)
        guard let proposalAnswers = answers.answers[proposalId] else {
            throw URLError(.resourceUnavailable)
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

    private func generateRandomChoices(excluding answer: String) -> [String] {
        let candidates = wordCandidates[answer.count] ?? []
        return Array(candidates.shuffled().prefix(3))
    }
}

extension QuizRepository: EnvironmentKey {
    static var defaultValue: QuizRepository {
        QuizRepository(
            cloudflareR2Endpoint: Env.cloudflareR2Endpoint,
            r2AccessKey: Env.cloudflareR2AccessKey,
            r2SecretKey: Env.cloudflareR2SecretKey
        )
    }
}

extension EnvironmentValues {
    var quizRepository: QuizRepository {
        get { self[QuizRepository.self] }
        set { self[QuizRepository.self] = newValue }
    }
}
