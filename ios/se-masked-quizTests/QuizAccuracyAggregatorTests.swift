import Foundation
import Testing

@testable import se_masked_quiz

@Suite("QuizAccuracyAggregator Tests")
struct QuizAccuracyAggregatorTests {

  private func score(proposalId: String, correct: Int, incorrect: Int) -> ProposalScore {
    let correctResults = (0..<correct).map {
      QuestionResult(index: $0, isCorrect: true, answer: "a", userAnswer: "a")
    }
    let incorrectResults = (0..<incorrect).map {
      QuestionResult(index: correct + $0, isCorrect: false, answer: "a", userAnswer: "b")
    }
    return ProposalScore(proposalId: proposalId, questionResults: correctResults + incorrectResults)
  }

  @Test("未回答なら正答率はnil")
  func emptyReturnsNil() {
    let sut = QuizAccuracyAggregator()
    let result = sut.aggregate(scoresByTrack: [[:], [:]])
    #expect(result.totalAnswered == 0)
    #expect(result.totalCorrect == 0)
    #expect(result.accuracyPercentage == nil)
  }

  @Test("単一トラックの正答率を計算する")
  func singleTrack() {
    let sut = QuizAccuracyAggregator()
    let scores = ["SE-0001": score(proposalId: "SE-0001", correct: 3, incorrect: 1)]
    let result = sut.aggregate(scoresByTrack: [scores])
    #expect(result.totalAnswered == 4)
    #expect(result.totalCorrect == 3)
    #expect(result.accuracyPercentage == 75.0)
  }

  @Test("SE/ST両トラックを横断して集計する")
  func mixedTracks() {
    let sut = QuizAccuracyAggregator()
    let seScores = ["0001": score(proposalId: "0001", correct: 2, incorrect: 2)]
    let stScores = ["0001": score(proposalId: "0001", correct: 4, incorrect: 0)]
    let result = sut.aggregate(scoresByTrack: [seScores, stScores])
    #expect(result.totalAnswered == 8)
    #expect(result.totalCorrect == 6)
    #expect(result.accuracyPercentage == 75.0)
  }
}
