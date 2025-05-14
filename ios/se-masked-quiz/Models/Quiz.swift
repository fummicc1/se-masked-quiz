import Foundation

struct Quiz: Codable, Identifiable {
  var id: String
  var proposalId: String
  var index: Int
  var answer: String
  var choices: [String]  // 誤答の選択肢3つ
  var allChoices: [String]

  init(id: String, proposalId: String, index: Int, answer: String, choices: [String]) {
    self.id = id
    self.proposalId = proposalId
    self.index = index
    self.answer = answer
    self.choices = choices
    allChoices = (choices + [answer]).shuffled()
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
