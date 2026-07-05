import SwiftUI

struct LicenseScreen: View {
  @State private var evolutionLicenseText: String = ""
  @State private var testingLicenseText: String = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text(
          "本アプリケーションは、[Swift-Evolution](https://github.com/swiftlang/swift-evolution)にて公開されているプロポーザルを元にしています。"
        )
        Text("Swift-Evolutionのライセンスは上記リンクまたは下記を参照してください。")
        Text(evolutionLicenseText)
          .padding()
          .font(.system(.body, design: .monospaced))

        Text(
          "本アプリケーションは、[Swift Testing](https://github.com/swiftlang/swift-testing)にて公開されているプロポーザルも一部含んでいます（swift-evolutionリポジトリのproposals/testingサブディレクトリ経由で取得）。"
        )
        .padding(.top)
        Text("Swift Testingのライセンスは上記リンクまたは下記を参照してください。")
        Text(testingLicenseText)
          .padding()
          .font(.system(.body, design: .monospaced))
      }
      .padding()
    }
    .navigationTitle("ライセンス")
    .task {
      if let path = Bundle.main.path(forResource: "swift-evolution-license", ofType: "txt"),
        let content = try? String(contentsOfFile: path, encoding: .utf8)
      {
        evolutionLicenseText = content
      }
      if let path = Bundle.main.path(forResource: "swift-testing-license", ofType: "txt"),
        let content = try? String(contentsOfFile: path, encoding: .utf8)
      {
        testingLicenseText = content
      }
    }
  }
}

#Preview {
  NavigationStack {
    LicenseScreen()
  }
}
