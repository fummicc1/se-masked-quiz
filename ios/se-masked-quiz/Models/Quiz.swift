import Foundation

/// R2からのマスク穴埋めクイズのドメインモデル
/// HTML内のマスクされた単語を当てる形式のクイズ
/// LLM生成クイズ（LLMQuiz）とは異なるドメインモデル
struct Quiz: Codable, Identifiable {
  var id: String
  var proposalId: String
  var maskIndex: Int
  var answer: String
  var wrongChoices: [String]
  var allChoices: [String]  // 全選択肢（シャッフル済み）

  init(
    id: String,
    proposalId: String,
    maskIndex: Int,
    answer: String,
    wrongChoices: [String]
  ) {
    self.id = id
    self.proposalId = proposalId
    self.maskIndex = maskIndex
    self.answer = answer
    self.wrongChoices = wrongChoices
    allChoices = (wrongChoices + [answer]).shuffled()
  }
}

struct QuestionResult: Codable, Equatable {
  let index: Int
  let isCorrect: Bool
  let answer: String
  let userAnswer: String
}

struct ProposalScore: Codable {
  let proposalId: String
  let questionResults: [QuestionResult]
  let timestamp: Date

  var correctCount: Int {
    questionResults.filter { $0.isCorrect }.count
  }

  var totalCount: Int {
    questionResults.count
  }

  var percentage: Double {
    guard totalCount > 0 else { return 0 }
    return Double(correctCount) / Double(totalCount) * 100
  }

  init(proposalId: String, questionResults: [QuestionResult], timestamp: Date = Date()) {
    self.proposalId = proposalId
    self.questionResults = questionResults
    self.timestamp = timestamp
  }
}
