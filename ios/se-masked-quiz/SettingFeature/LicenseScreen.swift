import SwiftUI

struct LicenseScreen: View {
  @State private var licenseText: String = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text(
          "本アプリケーションは、[Swift-Evolution](https://github.com/swiftlang/swift-evolution)にて公開されているプロポーザルを元にしています。"
        )
        Text("Swift-Evolutionのライセンスは上記リンクまたは下記を参照してください。")
        Text(licenseText)
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
        licenseText = content
      }
    }
  }
}

#Preview {
  NavigationStack {
    LicenseScreen()
  }
}
