//
//  AppColor.swift
//  se-masked-quiz
//
//  Swift公式ブランドカラー（#F05138）を基調にしたプリミティブカラーパレット。
//  意味づけされた色（正解/不正解等）は SemanticColor で定義し、ここでは値のみを持つ。
//

import SwiftUI

enum AppColor {
  /// Swift公式ブランドカラー（logo色）。https://forums.swift.org/t/official-swift-colour/13178
  static let brand = Color(hex: 0xF05138)
  static let brandLight = Color(hex: 0xF6B6A2)
  static let brandDark = Color(hex: 0xA8321F)
}

extension Color {
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >> 8) & 0xFF) / 255
    let b = Double(hex & 0xFF) / 255
    self.init(red: r, green: g, blue: b)
  }
}
