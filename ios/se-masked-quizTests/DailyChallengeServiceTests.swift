import Foundation
import Testing

@testable import se_masked_quiz

@Suite("DailyChallengeService Tests")
struct DailyChallengeServiceTests {

  // MARK: - Helpers

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: d, hour: 12))!
  }

  // MARK: - Tests

  @Test("同じ日付なら必ず同じ提案が選ばれる")
  func deterministic() {
    let sut = DailyChallengeService()
    let ids = ["0001", "0002", "0003", "0004", "0005"]
    let first = sut.todaysProposalId(from: ids, date: day(2026, 1, 1), calendar: utcCalendar)
    let second = sut.todaysProposalId(from: ids, date: day(2026, 1, 1), calendar: utcCalendar)
    #expect(first != nil)
    #expect(first == second)
  }

  @Test("空配列なら nil")
  func emptyReturnsNil() {
    let sut = DailyChallengeService()
    #expect(sut.todaysProposalId(from: [], date: day(2026, 1, 1), calendar: utcCalendar) == nil)
  }

  @Test("連続する日で順番にローテーションし、件数を超えると先頭に戻る")
  func rotation() {
    let sut = DailyChallengeService()
    let ids = ["0001", "0002", "0003"]
    let d0 = sut.todaysProposalId(from: ids, date: day(2026, 1, 1), calendar: utcCalendar)
    let d1 = sut.todaysProposalId(from: ids, date: day(2026, 1, 2), calendar: utcCalendar)
    let d2 = sut.todaysProposalId(from: ids, date: day(2026, 1, 3), calendar: utcCalendar)
    let d3 = sut.todaysProposalId(from: ids, date: day(2026, 1, 4), calendar: utcCalendar)
    #expect(Set([d0, d1, d2]).count == 3)  // 3日とも別の提案
    #expect(d3 == d0)  // 4日目は1日目に戻る
  }

  @Test("入力順に依存しない（内部でソートして選ぶ）")
  func orderIndependent() {
    let sut = DailyChallengeService()
    let shuffled = sut.todaysProposalId(
      from: ["0003", "0001", "0002"], date: day(2026, 1, 1), calendar: utcCalendar)
    let sorted = sut.todaysProposalId(
      from: ["0001", "0002", "0003"], date: day(2026, 1, 1), calendar: utcCalendar)
    #expect(shuffled == sorted)
  }
}
