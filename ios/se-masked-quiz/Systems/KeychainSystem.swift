//
//  KeychainSystem.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/05/18.
//

import KeychainAccess

/// @mockable
public protocol KeyChainSystem: Sendable {
    func save(value: String, forKey key: String) async throws
    func getString(forKey key: String) async throws -> String?
    func delete(key: String) async throws
    func deleteAll() async throws
}