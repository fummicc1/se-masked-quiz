//
//  AsyncProposals.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/05.
//

enum AsyncProposals {
  case idle
  case loading([SwiftEvolution])
  case loaded([SwiftEvolution])
  case error(Error)

  var isLoading: Bool {
    switch self {
    case .loading: return true
    case .loaded: return false
    case .error: return false
    case .idle: return false
    }
  }

  var content: [SwiftEvolution] {
    switch self {
    case .loading(let proposals): return proposals
    case .loaded(let proposals): return proposals
    case .error: return []
    case .idle: return []
    }
  }

  mutating func startLoading() {
    self = .loading(content)
  }
}
