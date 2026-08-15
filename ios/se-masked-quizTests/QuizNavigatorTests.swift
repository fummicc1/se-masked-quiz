import Testing
@testable import se_masked_quiz

private func makeQuizzes(_ indices: [Int]) -> [Quiz] {
  indices.map {
    Quiz(
      id: "q\($0)",
      proposalId: "0001",
      index: $0,
      answer: "correct",
      choices: ["wrong1", "wrong2"]
    )
  }
}

@Suite("マスククイズの出題順")
struct QuizNavigatorTests {

  @Test("解答した次の問題へ進む")
  func advancesToNextQuestion() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 0, in: makeQuizzes([0, 1, 2, 3]), answered: [0: true])
    #expect(result == 1)
  }

  @Test("不正解でも解答済みとして扱い、その次へ進む")
  func treatsIncorrectAnswerAsAnswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 0, in: makeQuizzes([0, 1, 2]), answered: [0: false])
    #expect(result == 1)
  }

  @Test("すでに解答済みの問題は飛ばす")
  func skipsAnsweredQuestions() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 0, in: makeQuizzes([0, 1, 2, 3]), answered: [0: true, 1: true, 2: true])
    #expect(result == 3)
  }

  @Test("まだ何も解いていないときは最初の問題を返す")
  func returnsFirstQuestionWhenNothingAnswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: nil, in: makeQuizzes([0, 1, 2]), answered: [:])
    #expect(result == 0)
  }

  @Test("最後まで進んだら、飛ばした問題へ戻る")
  func wrapsAroundToSkippedQuestion() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 3, in: makeQuizzes([0, 1, 2, 3]), answered: [2: true, 3: true])
    #expect(result == 0)
  }

  @Test("途中から解き始めても残りの問題に到達できる")
  func reachesRemainingQuestionsWhenStartingMidway() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 3, in: makeQuizzes([0, 1, 2, 3, 4, 5]), answered: [3: true])
    #expect(result == 4)
  }

  @Test("問題番号が連続していなくても順番に進む")
  func advancesThroughNonContiguousIndices() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 3, in: makeQuizzes([3, 7, 10]), answered: [3: true])
    #expect(result == 7)
  }

  @Test("問題の並び順が番号順でなくても本文の順に進む")
  func followsDocumentOrderRegardlessOfArrayOrder() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 1, in: makeQuizzes([5, 1, 3]), answered: [1: true])
    #expect(result == 3)
  }

  @Test("問題が1つも無いときは次へ進まない")
  func returnsNilWhenNoQuestions() {
    let result = QuizNavigator.nextUnansweredMaskIndex(after: nil, in: [], answered: [:])
    #expect(result == nil)
  }

  @Test("全問解答済みのときは次へ進まない")
  func returnsNilWhenAllAnswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 2, in: makeQuizzes([0, 1, 2]), answered: [0: true, 1: true, 2: false])
    #expect(result == nil)
  }

  @Test("現在位置が存在しない番号でも未解答の問題へ進める")
  func wrapsWhenCurrentIndexIsUnknown() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 99, in: makeQuizzes([0, 1, 2]), answered: [:])
    #expect(result == 0)
  }

  @Test("現在位置が存在しない番号で全問解答済みなら進まない")
  func returnsNilWhenCurrentIndexIsUnknownAndAllAnswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 99, in: makeQuizzes([0, 1]), answered: [0: true, 1: true])
    #expect(result == nil)
  }

  @Test("問題が1つだけで未解答ならその問題を返す")
  func returnsOnlyQuestionWhenUnanswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: nil, in: makeQuizzes([0]), answered: [:])
    #expect(result == 0)
  }

  @Test("残り1問が現在表示中のときはその問題自身を返す")
  func returnsItselfWhenOnlyRemainingQuestionIsCurrent() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 1, in: makeQuizzes([0, 1]), answered: [0: true])
    #expect(result == 1)
  }

  @Test("最後の問題を解いた直後は次へ進まない")
  func returnsNilAfterAnsweringLastQuestion() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 1, in: makeQuizzes([0, 1]), answered: [0: true, 1: true])
    #expect(result == nil)
  }

  @Test("先頭の問題だけ未解答のとき末尾から先頭へ戻る")
  func wrapsFromLastToFirstUnanswered() {
    let result = QuizNavigator.nextUnansweredMaskIndex(
      after: 2, in: makeQuizzes([0, 1, 2]), answered: [1: true, 2: true])
    #expect(result == 0)
  }
}
