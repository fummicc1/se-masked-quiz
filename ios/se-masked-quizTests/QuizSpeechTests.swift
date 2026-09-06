import Testing

@testable import se_masked_quiz

@MainActor
private final class SpeechLog {
  var spokenTexts: [String] = []
}

private func makeQuiz(index: Int, answer: String) -> Quiz {
  Quiz(
    id: "q\(index)",
    proposalId: "0001",
    maskIndex: index,
    answer: answer,
    wrongChoices: ["wrong1", "wrong2"]
  )
}

@MainActor
private func makeViewModel(quizzes: [Quiz], speech: SpeechServiceMock) async -> QuizViewModel {
  let repository = QuizRepositoryMock()
  await repository.setFetchQuizHandler { _ in quizzes }
  await repository.setGetScoreHandler { _ in nil }
  await repository.setSaveScoreHandler { _ in }
  await repository.setGetLLMQuizzesHandler { _ in [] }
  await repository.setHasLLMQuizzesHandler { _ in false }
  await repository.setGetLLMQuizScoreHandler { _ in nil }

  let viewModel = QuizViewModel(
    proposalId: "0001", quizRepository: repository, speechService: speech)
  await viewModel.configure()
  return viewModel
}

/// 読み上げ中の状態を観察したいテスト向けに、停止されるまで戻らない発話を模す
private func makeBlockingHandler(_ log: SpeechLog) -> (String, String) async -> Void {
  { text, _ in
    await MainActor.run { log.spokenTexts.append(text) }
    try? await Task.sleep(for: .seconds(60))
  }
}

private let paragraphContainingBlanks0And1: [ProposalSegment] = [
  .text("Actors provide "),
  .mask(index: 0),
  .text(" through "),
  .mask(index: 1),
  .text(" domains."),
]

/// 発話タスクは別タスクで進むため、固定時間ではなく条件が満たされるまで待つ
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
  for _ in 0..<200 {
    if condition() { return }
    try? await Task.sleep(for: .milliseconds(5))
  }
}

@Suite("クイズ中の読み上げ")
@MainActor
struct QuizSpeechTests {

  @Test("段落の読み上げを始めると読み上げ中になる")
  func startsParagraphSpeech() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.updateFocusedParagraph([.text("Actors provide safety.")])

    viewModel.toggleParagraphSpeech()

    #expect(viewModel.speakingTarget == .paragraph)
    await waitUntil { !log.spokenTexts.isEmpty }
    #expect(log.spokenTexts == ["Actors provide safety."])
  }

  @Test("答えの発音を始めると答えの用語が読み上げられる")
  func startsTermSpeechWithAnswer() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")

    viewModel.toggleTermSpeech()

    #expect(viewModel.speakingTarget == .term)
    await waitUntil { !log.spokenTexts.isEmpty }
    #expect(log.spokenTexts == ["isolation"])
  }

  @Test("読み上げが終わると読み上げ中の表示が消える")
  func clearsSpeakingStateWhenFinished() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.updateFocusedParagraph([.text("Actors provide safety.")])

    viewModel.toggleParagraphSpeech()
    await waitUntil { viewModel.speakingTarget == nil }

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("解答すると答えの発音を始められる")
  func enablesTermSpeechAfterAnswering() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)

    #expect(viewModel.canSpeakTerm == false)
    viewModel.selectAnswer("isolation")
    #expect(viewModel.canSpeakTerm)
  }

  @Test("不正解でも答えの発音を始められる")
  func enablesTermSpeechAfterWrongAnswer() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)

    viewModel.selectAnswer("wrong1")

    #expect(viewModel.canSpeakTerm)
  }

  @Test("同じボタンをもう一度押すと読み上げが止まる")
  func stopsWhenSameButtonPressedAgain() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.updateFocusedParagraph([.text("Actors provide safety.")])

    viewModel.toggleParagraphSpeech()
    viewModel.toggleParagraphSpeech()

    #expect(viewModel.speakingTarget == nil)
    #expect(speech.stopCallCount >= 1)
  }

  @Test("別の読み上げを始めると前の読み上げが止まる")
  func switchesToAnotherSpeech() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.updateFocusedParagraph([.text("Actors provide safety.")])

    viewModel.toggleParagraphSpeech()
    viewModel.toggleTermSpeech()

    #expect(viewModel.speakingTarget == .term)
  }

  @Test("解答していないときは答えの発音を始められない")
  func doesNotSpeakTermBeforeAnswering() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)

    viewModel.toggleTermSpeech()

    #expect(viewModel.canSpeakTerm == false)
    #expect(viewModel.speakingTarget == nil)
    #expect(speech.speakCallCount == 0)
  }

  @Test("段落が取れていないときは読み上げを始められない")
  func doesNotSpeakParagraphWithoutSegments() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)

    viewModel.toggleParagraphSpeech()

    #expect(viewModel.canSpeakParagraph == false)
    #expect(viewModel.speakingTarget == nil)
    #expect(speech.speakCallCount == 0)
  }

  @Test("壊れた段落データを受け取っても読み上げを始めない")
  func doesNotSpeakAfterEmptyParagraphUpdate() async {
    let speech = SpeechServiceMock()
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.updateFocusedParagraph([.text("Actors provide safety.")])
    viewModel.updateFocusedParagraph([])

    viewModel.toggleParagraphSpeech()

    #expect(viewModel.canSpeakParagraph == false)
    #expect(speech.speakCallCount == 0)
  }

  @Test("次の問題へ進むと読み上げが止まる")
  func stopsWhenMovingToNextQuestion() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.toggleTermSpeech()

    viewModel.goToNextUnansweredQuiz()

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("クイズを閉じると読み上げが止まる")
  func stopsWhenQuizDismissed() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.toggleTermSpeech()

    viewModel.dismissQuiz()

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("別の空欄を開くと読み上げが止まる")
  func stopsWhenAnotherBlankOpened() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.toggleTermSpeech()

    viewModel.showQuizSelections(maskIndex: 1)

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("同じ段落の次の空欄へ進んでも読み上げが続く")
  func keepsSpeakingWhenAdvancingWithinSameParagraph() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.updateFocusedParagraph(paragraphContainingBlanks0And1)
    viewModel.toggleParagraphSpeech()
    let stopsBeforeMove = speech.stopCallCount

    viewModel.goToNextUnansweredQuiz()

    #expect(viewModel.currentQuiz?.maskIndex == 1)
    #expect(viewModel.speakingTarget == .paragraph)
    #expect(speech.stopCallCount == stopsBeforeMove)
  }

  @Test("同じ段落の別の空欄をタップしても読み上げが続く")
  func keepsSpeakingWhenTappingBlankInSameParagraph() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.updateFocusedParagraph(paragraphContainingBlanks0And1)
    viewModel.toggleParagraphSpeech()

    viewModel.showQuizSelections(maskIndex: 1)

    #expect(viewModel.currentQuiz?.maskIndex == 1)
    #expect(viewModel.speakingTarget == .paragraph)
  }

  @Test("別の段落の空欄へ移ると読み上げが止まる")
  func stopsWhenMovingToAnotherParagraph() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.updateFocusedParagraph([
      .text("Actors provide "), .mask(index: 0), .text(" domains."),
    ])
    viewModel.toggleParagraphSpeech()

    viewModel.showQuizSelections(maskIndex: 1)

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("答えの発音は同じ段落内を移動しても止まる")
  func stopsTermSpeechEvenWithinSameParagraph() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation"), makeQuiz(index: 1, answer: "actor")],
      speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.selectAnswer("isolation")
    viewModel.updateFocusedParagraph(paragraphContainingBlanks0And1)
    viewModel.toggleTermSpeech()

    viewModel.goToNextUnansweredQuiz()

    #expect(viewModel.speakingTarget == nil)
  }

  @Test("段落の読み上げに未解答の答えが渡らない")
  func neverSpeaksUnansweredAnswer() async {
    let speech = SpeechServiceMock()
    let log = SpeechLog()
    speech.speakHandler = makeBlockingHandler(log)
    let viewModel = await makeViewModel(
      quizzes: [makeQuiz(index: 0, answer: "isolation")], speech: speech)
    viewModel.showQuizSelections(maskIndex: 0)
    viewModel.updateFocusedParagraph([
      .text("Actors provide "), .mask(index: 0), .text(" domains."),
    ])

    viewModel.toggleParagraphSpeech()
    await waitUntil { !log.spokenTexts.isEmpty }

    #expect(log.spokenTexts == ["Actors provide blank domains."])
    #expect(log.spokenTexts.allSatisfy { !$0.contains("isolation") })
  }
}
