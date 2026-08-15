//
//  QuizNavigator.swift
//  se-masked-quiz
//
//  マスククイズを解き進める順序を決める純粋ロジック。
//

import Foundation

enum QuizNavigator {
  static func nextUnansweredMaskIndex(
    after current: Int?,
    in quizzes: [Quiz],
    answered: [Int: Bool]
  ) -> Int? {
    let unanswered = quizzes.map(\.index).sorted().filter { answered[$0] == nil }
    guard !unanswered.isEmpty else { return nil }
    guard let current else { return unanswered.first }
    return unanswered.first { $0 > current } ?? unanswered.first
  }
}
