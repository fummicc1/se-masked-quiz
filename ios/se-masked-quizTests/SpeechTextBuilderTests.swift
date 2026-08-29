import Testing

@testable import se_masked_quiz

/// "Actors provide ＿＿＿ through ＿＿＿ domains." に相当する段落
private let standardSegments: [ProposalSegment] = [
  .text("Actors provide "),
  .mask(index: 3),
  .text(" through "),
  .mask(index: 5),
  .text(" domains."),
]

private let standardAnswers: [Int: String] = [3: "data race safety", 5: "isolation"]

@Suite("読み上げ文の組み立て")
struct SpeechTextBuilderTests {

  @Test("未解答の空欄は blank と読み上げる")
  func speaksUnansweredBlankAsBlank() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: standardAnswers, answeredIndices: [])
    #expect(result == "Actors provide blank through blank domains.")
  }

  @Test("解答済みの空欄は答えの語で読み上げる")
  func speaksAnsweredBlankWithItsAnswer() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: standardAnswers, answeredIndices: [3, 5])
    #expect(result == "Actors provide data race safety through isolation domains.")
  }

  @Test("解答済みと未解答が混ざっても正しく組み立てる")
  func mixesAnsweredAndUnansweredBlanks() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: standardAnswers, answeredIndices: [5])
    #expect(result == "Actors provide blank through isolation domains.")
  }

  @Test("空欄のない段落はそのまま読み上げる")
  func speaksParagraphWithoutBlanks() {
    let result = SpeechTextBuilder.utterance(
      from: [.text("Swift 6 enables strict concurrency.")], answers: [:], answeredIndices: [])
    #expect(result == "Swift 6 enables strict concurrency.")
  }

  @Test("空欄だけの段落も読み上げられる")
  func speaksParagraphOfOnlyBlank() {
    let result = SpeechTextBuilder.utterance(
      from: [.mask(index: 0)], answers: [0: "isolation"], answeredIndices: [])
    #expect(result == "blank")
  }

  @Test("未解答の答えは読み上げ文に決して含まれない")
  func neverRevealsUnansweredAnswers() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: standardAnswers, answeredIndices: [])
    #expect(!result.contains("data race safety"))
    #expect(!result.contains("isolation"))
  }

  @Test("解答済みの空欄だけが答えを明かす")
  func revealsOnlyAnsweredAnswers() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: standardAnswers, answeredIndices: [5])
    #expect(result.contains("isolation"))
    #expect(!result.contains("data race safety"))
  }

  @Test("解答済みなのに答えが見つからないときは blank に戻す")
  func fallsBackToBlankWhenAnswerIsMissing() {
    let result = SpeechTextBuilder.utterance(
      from: standardSegments, answers: [:], answeredIndices: [3, 5])
    #expect(result == "Actors provide blank through blank domains.")
  }

  @Test("知らない番号の空欄も blank として扱う")
  func treatsUnknownBlankAsBlank() {
    let result = SpeechTextBuilder.utterance(
      from: [.mask(index: 999)], answers: [:], answeredIndices: [])
    #expect(result == "blank")
  }

  @Test("読み上げるものが無いときは空文字を返す")
  func returnsEmptyForNoSegments() {
    #expect(SpeechTextBuilder.utterance(from: [], answers: [:], answeredIndices: []).isEmpty)
  }

  @Test("空白だけの段落は空文字を返す")
  func returnsEmptyForWhitespaceOnly() {
    let result = SpeechTextBuilder.utterance(
      from: [.text("  \n\t  ")], answers: [:], answeredIndices: [])
    #expect(result.isEmpty)
  }

  @Test("改行と連続空白は1つの空白にまとめる")
  func collapsesRepeatedWhitespace() {
    let result = SpeechTextBuilder.utterance(
      from: [.text("Actors\n\n   provide  safety")], answers: [:], answeredIndices: [])
    #expect(result == "Actors provide safety")
  }

  @Test("前後の空白は取り除く")
  func trimsSurroundingWhitespace() {
    let result = SpeechTextBuilder.utterance(
      from: [.text("  isolation  ")], answers: [:], answeredIndices: [])
    #expect(result == "isolation")
  }

  @Test("空欄が連続しても語が繋がらない")
  func separatesAdjacentBlanks() {
    let result = SpeechTextBuilder.utterance(
      from: [.mask(index: 0), .mask(index: 1)], answers: [:], answeredIndices: [])
    #expect(result == "blank blank")
  }

  @Test("空欄の直前に空白が無くても語が繋がらない")
  func separatesBlankFromPrecedingWord() {
    let result = SpeechTextBuilder.utterance(
      from: [.text("provide"), .mask(index: 0)], answers: [:], answeredIndices: [])
    #expect(result == "provide blank")
  }
}
