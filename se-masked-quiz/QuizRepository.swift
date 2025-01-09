//
//  QuizRepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/09.
//

import Foundation
import SwiftUI

struct QuizRepository {
    private let cloudflareR2Endpoint: String

    init(cloudflareR2Endpoint: String) {
        self.cloudflareR2Endpoint = cloudflareR2Endpoint
    }

    func fetchQuiz(for proposalId: String) async throws -> Quiz {
        let url = URL(string: "\(cloudflareR2Endpoint)/quizzes/\(proposalId).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Quiz.self, from: data)
    }
}

extension QuizRepository: EnvironmentKey {
    static var defaultValue: QuizRepository {
        QuizRepository(cloudflareR2Endpoint: Env.cloudflareR2Endpoint)
    }
}

extension EnvironmentValues {
    var quizRepository: QuizRepository {
        get { self[QuizRepository.self] }
        set { self[QuizRepository.self] = newValue }
    }
}
