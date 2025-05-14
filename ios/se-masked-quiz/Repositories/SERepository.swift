//
//  SERepository.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import Foundation
import SwiftUI

struct SERepository: Sendable {
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
