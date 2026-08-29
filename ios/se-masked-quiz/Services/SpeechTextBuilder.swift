//
//  SpeechTextBuilder.swift
//  se-masked-quiz
//
//  段落の構成要素から発話文字列を組み立てる。未解答の空欄の答えは出力に含めない。
//

import Foundation

enum SpeechTextBuilder {
  /// 未解答の空欄を読み上げるときの語
  static let blankPlaceholder = "blank"

  static func utterance(
    from segments: [ProposalSegment],
    answers: [Int: String],
    answeredIndices: Set<Int>
  ) -> String {
    let joined = segments.map { segment -> String in
      switch segment {
      case .text(let text):
        return text
      case .mask(let index):
        return " \(spokenWord(at: index, answers: answers, answeredIndices: answeredIndices)) "
      }
    }.joined()
    return joined.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  private static func spokenWord(
    at index: Int,
    answers: [Int: String],
    answeredIndices: Set<Int>
  ) -> String {
    guard answeredIndices.contains(index), let answer = answers[index], !answer.isEmpty else {
      return blankPlaceholder
    }
    return answer
  }
}
