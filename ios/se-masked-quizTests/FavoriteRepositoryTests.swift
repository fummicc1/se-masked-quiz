import Foundation
import Testing

@testable import se_masked_quiz

@Suite("FavoriteRepository Tests")
struct FavoriteRepositoryTests {

  // MARK: - Helpers

  private func makeSUT() -> FavoriteRepositoryImpl {
    let suiteName = "favorite-test-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return FavoriteRepositoryImpl(userDefaults: defaults)
  }

  // MARK: - Tests

  @Test("トグルするとお気に入りに追加される")
  func toggleAdds() async {
    let sut = makeSUT()
    let result = await sut.toggle(proposalId: "0001", track: .swiftEvolution)
    #expect(result == true)
    let isFavorite = await sut.isFavorite(proposalId: "0001", track: .swiftEvolution)
    #expect(isFavorite == true)
  }

  @Test("再度トグルすると解除される")
  func toggleTwiceRemoves() async {
    let sut = makeSUT()
    _ = await sut.toggle(proposalId: "0001", track: .swiftEvolution)
    let result = await sut.toggle(proposalId: "0001", track: .swiftEvolution)
    #expect(result == false)
    let isFavorite = await sut.isFavorite(proposalId: "0001", track: .swiftEvolution)
    #expect(isFavorite == false)
  }

  @Test("未登録の提案はisFavoriteがfalse")
  func isFavoriteDefaultsFalse() async {
    let sut = makeSUT()
    let isFavorite = await sut.isFavorite(proposalId: "9999", track: .swiftEvolution)
    #expect(isFavorite == false)
  }

  @Test("getAllFavoritesが全エントリを返す")
  func getAllFavoritesReturnsEntries() async {
    let sut = makeSUT()
    _ = await sut.toggle(proposalId: "0001", track: .swiftEvolution)
    _ = await sut.toggle(proposalId: "0002", track: .swiftEvolution)
    let all = await sut.getAllFavorites()
    #expect(all.count == 2)
    #expect(Set(all.map(\.proposalId)) == ["0001", "0002"])
  }

  @Test("SE/STで同一proposalIdをそれぞれトグルしても独立して動作する")
  func seAndStAreIndependent() async {
    let sut = makeSUT()
    _ = await sut.toggle(proposalId: "0001", track: .swiftEvolution)
    let stFavoriteBefore = await sut.isFavorite(proposalId: "0001", track: .swiftTesting)
    #expect(stFavoriteBefore == false)

    _ = await sut.toggle(proposalId: "0001", track: .swiftTesting)
    let seFavorite = await sut.isFavorite(proposalId: "0001", track: .swiftEvolution)
    let stFavoriteAfter = await sut.isFavorite(proposalId: "0001", track: .swiftTesting)
    #expect(seFavorite == true)
    #expect(stFavoriteAfter == true)

    let all = await sut.getAllFavorites()
    #expect(all.count == 2)
  }
}
