import Testing
@testable import se_masked_quiz

@Suite("ProposalProgress Tests")
struct ProposalProgressTests {

  // MARK: - 進捗率計算テスト

  @Test("進捗率計算 - 正常系: 10問中5問回答")
  func testProgressRate_Normal() {
    // Given: 10問中5問回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )

    // Then: 進捗率が50%
    #expect(progress.progressRate == 0.5)
    #expect(progress.progressPercentage == 50.0)
  }

  @Test("進捗率計算 - エッジケース: totalCountが0")
  func testProgressRate_ZeroTotal() {
    // Given: 全問題数が0
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 0,
      totalCount: 0,
      correctCount: 0
    )

    // Then: 進捗率は0
    #expect(progress.progressRate == 0.0)
    #expect(progress.progressPercentage == 0.0)
  }

  @Test("進捗率計算 - 完了: 全問回答")
  func testProgressRate_Completed() {
    // Given: 10問全問回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 10,
      totalCount: 10,
      correctCount: 8
    )

    // Then: 進捗率が100%
    #expect(progress.progressRate == 1.0)
    #expect(progress.progressPercentage == 100.0)
  }

  // MARK: - 正解率計算テスト

  @Test("正解率計算 - 正常系: 5問回答中4問正解")
  func testAccuracyPercentage_Normal() {
    // Given: 5問回答中4問正解
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )

    // Then: 正解率が80%
    #expect(progress.accuracyPercentage == 80.0)
  }

  @Test("正解率計算 - エッジケース: answeredCountが0")
  func testAccuracyPercentage_ZeroAnswered() {
    // Given: 回答数が0
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 0,
      totalCount: 10,
      correctCount: 0
    )

    // Then: 正解率は0
    #expect(progress.accuracyPercentage == 0.0)
  }

  @Test("正解率計算 - 完璧: 全問正解")
  func testAccuracyPercentage_Perfect() {
    // Given: 5問全問正解
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 5
    )

    // Then: 正解率が100%
    #expect(progress.accuracyPercentage == 100.0)
  }

  @Test("正解率計算 - 最悪: 全問不正解")
  func testAccuracyPercentage_AllWrong() {
    // Given: 5問全問不正解
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 0
    )

    // Then: 正解率が0%
    #expect(progress.accuracyPercentage == 0.0)
  }

  // MARK: - 進捗状態テスト

  @Test("進捗状態 - 未開始: 0問回答")
  func testStatus_NotStarted() {
    // Given: 0問回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 0,
      totalCount: 10,
      correctCount: 0
    )

    // Then: 未開始状態
    #expect(progress.status == .notStarted)
  }

  @Test("進捗状態 - 進行中: 一部回答")
  func testStatus_InProgress() {
    // Given: 5問回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )

    // Then: 進行中状態
    #expect(progress.status == .inProgress)
  }

  @Test("進捗状態 - 進行中: 1問のみ回答")
  func testStatus_InProgress_OneAnswer() {
    // Given: 1問のみ回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 1,
      totalCount: 10,
      correctCount: 1
    )

    // Then: 進行中状態
    #expect(progress.status == .inProgress)
  }

  @Test("進捗状態 - 完了: 全問回答")
  func testStatus_Completed() {
    // Given: 10問全問回答
    let progress = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 10,
      totalCount: 10,
      correctCount: 8
    )

    // Then: 完了状態
    #expect(progress.status == .completed)
  }

  // MARK: - Equatableテスト

  @Test("Equatable - 同じ値のインスタンスは等しい")
  func testEquatable_Equal() {
    // Given: 同じ値を持つ2つのインスタンス
    let progress1 = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )
    let progress2 = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )

    // Then: 等しい
    #expect(progress1 == progress2)
  }

  @Test("Equatable - 異なる値のインスタンスは等しくない")
  func testEquatable_NotEqual() {
    // Given: 異なる値を持つ2つのインスタンス
    let progress1 = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 5,
      totalCount: 10,
      correctCount: 4
    )
    let progress2 = ProposalProgress(
      proposalId: "SE-0001",
      answeredCount: 6,
      totalCount: 10,
      correctCount: 5
    )

    // Then: 等しくない
    #expect(progress1 != progress2)
  }
}
