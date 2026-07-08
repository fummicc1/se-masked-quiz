import Foundation
import Testing

@testable import se_masked_quiz

@Suite("StreakRepository Tests")
struct StreakRepositoryTests {

  // MARK: - Helpers

  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func makeSUT() -> StreakRepositoryImpl {
    let suiteName = "streak-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return StreakRepositoryImpl(userDefaults: defaults, calendar: utcCalendar)
  }

  private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: year, month: month, day: d, hour: 12))!
  }

  // MARK: - Tests

  @Test("初回学習でストリークが1になる")
  func firstActivity() async {
    let sut = makeSUT()
    let result = await sut.recordActivity(on: day(2026, 1, 1))
    #expect(result.record.currentStreak == 1)
    #expect(result.record.longestStreak == 1)
    #expect(result.record.totalActiveDays == 1)
    #expect(result.isFirstActivityToday == true)
  }

  @Test("同日に複数回回答してもストリークは増えない")
  func sameDayNoOp() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    let second = await sut.recordActivity(on: day(2026, 1, 1))
    #expect(second.record.currentStreak == 1)
    #expect(second.record.totalActiveDays == 1)
    #expect(second.didIncrement == false)
    #expect(second.isFirstActivityToday == false)
  }

  @Test("連続した日でストリークが増える")
  func consecutiveDays() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    _ = await sut.recordActivity(on: day(2026, 1, 2))
    let third = await sut.recordActivity(on: day(2026, 1, 3))
    #expect(third.record.currentStreak == 3)
    #expect(third.record.longestStreak == 3)
    #expect(third.record.totalActiveDays == 3)
    #expect(third.didIncrement == true)
  }

  @Test("1日以上空くとストリークがリセットされ、最長は維持される")
  func gapResetsButKeepsLongest() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    _ = await sut.recordActivity(on: day(2026, 1, 2))
    let afterGap = await sut.recordActivity(on: day(2026, 1, 5))
    #expect(afterGap.record.currentStreak == 1)
    #expect(afterGap.record.longestStreak == 2)
    #expect(afterGap.record.totalActiveDays == 3)
    #expect(afterGap.didIncrement == false)
  }

  @Test("isActive / isAtRisk の判定")
  func activeAndRisk() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    let record = await sut.getStreak()
    let cal = utcCalendar

    #expect(record.isActive(on: day(2026, 1, 1), calendar: cal) == true)
    #expect(record.isActive(on: day(2026, 1, 2), calendar: cal) == false)
    // 昨日まで継続・今日未学習 → リスク
    #expect(record.isAtRisk(on: day(2026, 1, 2), calendar: cal) == true)
    // 今日学習済み → リスクではない
    #expect(record.isAtRisk(on: day(2026, 1, 1), calendar: cal) == false)
    // 2日以上空いた → すでに途切れているのでリスク扱いしない
    #expect(record.isAtRisk(on: day(2026, 1, 3), calendar: cal) == false)
  }

  @Test("reset で空に戻る")
  func resetClears() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    await sut.reset()
    let record = await sut.getStreak()
    #expect(record == .empty)
  }

  // MARK: - activeDays

  @Test("学習するとactiveDaysに日付が追加される")
  func activeDaysAppended() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    let result = await sut.recordActivity(on: day(2026, 1, 2))
    #expect(result.record.activeDays.count == 2)
    #expect(
      result.record.activeDays.contains { utcCalendar.isDate($0, inSameDayAs: day(2026, 1, 1)) })
    #expect(
      result.record.activeDays.contains { utcCalendar.isDate($0, inSameDayAs: day(2026, 1, 2)) })
  }

  @Test("同日に複数回記録してもactiveDaysに重複しない")
  func noDuplicateActiveDaysForSameDay() async {
    let sut = makeSUT()
    _ = await sut.recordActivity(on: day(2026, 1, 1))
    let second = await sut.recordActivity(on: day(2026, 1, 1))
    #expect(second.record.activeDays.count == 1)
  }

  @Test("180日を超える古い活動日はトリムされる")
  func trimsOldActiveDays() async {
    let suiteName = "streak-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let oldDay = day(2025, 1, 1)
    let seedRecord = StreakRecord(
      currentStreak: 1, longestStreak: 1, lastActiveDay: oldDay, totalActiveDays: 1,
      activeDays: [oldDay])
    let encoded = try! JSONEncoder().encode(seedRecord)
    defaults.set(encoded, forKey: "streak_record")

    let sut = StreakRepositoryImpl(userDefaults: defaults, calendar: utcCalendar)
    let today = day(2026, 7, 25)
    let result = await sut.recordActivity(on: today)

    #expect(
      !result.record.activeDays.contains { utcCalendar.isDate($0, inSameDayAs: oldDay) })
    #expect(
      result.record.activeDays.contains { utcCalendar.isDate($0, inSameDayAs: today) })
  }

  @Test("activeDaysキーの無い旧データも安全にデコードできる")
  func decodesLegacyDataWithoutActiveDays() throws {
    struct LegacyStreakRecord: Codable {
      var currentStreak: Int
      var longestStreak: Int
      var lastActiveDay: Date?
      var totalActiveDays: Int
    }
    let legacy = LegacyStreakRecord(
      currentStreak: 3, longestStreak: 5, lastActiveDay: day(2026, 1, 1), totalActiveDays: 10)
    let data = try JSONEncoder().encode(legacy)
    let record = try JSONDecoder().decode(StreakRecord.self, from: data)
    #expect(record.currentStreak == 3)
    #expect(record.longestStreak == 5)
    #expect(record.totalActiveDays == 10)
    #expect(record.activeDays == [])
  }
}
