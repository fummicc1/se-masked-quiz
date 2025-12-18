import Foundation

/// クイズ難易度
enum QuizDifficulty: String, Codable {
  case beginner = "初級"      // 基本的な用語・概念
  case intermediate = "中級"  // 提案の詳細理解
  case advanced = "上級"      // 複雑な概念・関連性
}

/// R2からのマスク穴埋めクイズのドメインモデル
/// HTML内のマスクされた単語を当てる形式のクイズ
/// LLM生成クイズ（LLMQuiz）とは異なるドメインモデル
struct Quiz: Codable, Identifiable {
  var id: String
  var proposalId: String
  var index: Int  // HTML内のマスク位置
  var answer: String
  var choices: [String]  // 誤答の選択肢
  var allChoices: [String]  // 全選択肢（シャッフル済み）

  init(
    id: String,
    proposalId: String,
    index: Int,
    answer: String,
    choices: [String]
  ) {
    self.id = id
    self.proposalId = proposalId
    self.index = index
    self.answer = answer
    self.choices = choices
    allChoices = (choices + [answer]).shuffled()
  }
}

/// マスククイズの回答結果
struct QuestionResult: Codable, Equatable {
  let index: Int
  let isCorrect: Bool
  let answer: String
  let userAnswer: String
}

/// マスククイズのスコア（提案単位）
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
