//
//  SwiftEvolution.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation

struct SwiftEvolution: Sendable, Codable, Identifiable, Hashable {
    var id: String
    var proposalId: String
    var title: String
    // Markdown format
    var reviewManager: String?
    // Markdown format
    var status: String?
    // Markdown format
    var authors: String
    // HTML format
    var content: String
}
