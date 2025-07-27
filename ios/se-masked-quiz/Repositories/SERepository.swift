//
//  SERepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation
import SwiftUI

/// @mockable
protocol SERepository {
  func fetch(offset: Int) async throws -> [SwiftEvolution]
}

struct SERepositoryImpl: SERepository, Sendable {
  func fetch(offset: Int) async throws -> [SwiftEvolution] {
    let microCmsApiKey = Env.microCmsApiKey
    let microCmsApiEndpoint = Env.microCmsApiEndpoint
    let requestURL = URL(
      string: "https://\(microCmsApiEndpoint).microcms.io/api/v1/proposals?offset=\(offset)")!
    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(microCmsApiKey, forHTTPHeaderField: "X-MICROCMS-API-KEY")
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    let response = try decoder.decode(FetchResponse.self, from: data)
    return response.contents
  }

  struct FetchResponse: Codable {
    var contents: [SwiftEvolution]
  }
}

enum SERepositoryDependencyKey: EnvironmentKey {
  static var defaultValue: any SERepository {
    SERepositoryImpl()
  }
}

extension EnvironmentValues {
  var seRepository: any SERepository {
    get { self[SERepositoryDependencyKey.self] }
    set { self[SERepositoryDependencyKey.self] = newValue }
  }
}
