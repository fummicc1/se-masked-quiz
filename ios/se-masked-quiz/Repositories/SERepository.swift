//
//  SERepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation
import SwiftUI

struct SERepository: Sendable {
  func fetch(offset: Int, query: String? = nil) async throws -> [SwiftEvolution] {
    let microCmsReadOnlyApiKey = Env.microCmsReadOnlyApiKey
    let microCmsApiEndpoint = Env.microCmsApiEndpoint

    var components = URLComponents()
    components.scheme = "https"
    components.host = "\(microCmsApiEndpoint).microcms.io"
    components.path = "/api/v1/proposals"

    var queryItems = [URLQueryItem(name: "offset", value: "\(offset)")]
    if let query, !query.isEmpty {
      queryItems.append(URLQueryItem(name: "q", value: query))
    }
    components.queryItems = queryItems

    guard let requestURL = components.url else {
      throw URLError(.badURL)
    }

    var request = URLRequest(url: requestURL)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(microCmsReadOnlyApiKey, forHTTPHeaderField: "X-MICROCMS-API-KEY")
    let (data, _) = try await URLSession.shared.data(for: request)
    let decoder = JSONDecoder()
    let response = try decoder.decode(FetchResponse.self, from: data)
    return response.contents
  }

  struct FetchResponse: Codable {
    var contents: [SwiftEvolution]
  }
}

extension SERepository: EnvironmentKey {
  static var defaultValue: Self {
    SERepository()
  }
}

extension EnvironmentValues {
  var seRepository: SERepository {
    get { self[SERepository.self] }
    set { self[SERepository.self] = newValue }
  }
}
