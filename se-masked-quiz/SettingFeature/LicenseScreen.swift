import SwiftUI

struct LicenseScreen: View {
    @State private var licenseText: String = ""
    
    var body: some View {
        ScrollView {
            Text(licenseText)
                .padding()
                .font(.system(.body, design: .monospaced))
        }
        .navigationTitle("ライセンス")
        .task {
            if let path = Bundle.main.path(forResource: "swift-evolution-license", ofType: "txt"),
               let content = try? String(contentsOfFile: path, encoding: .utf8) {
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