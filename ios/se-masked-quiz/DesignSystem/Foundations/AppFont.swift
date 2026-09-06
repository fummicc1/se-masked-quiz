//
//  AppFont.swift
//  se-masked-quiz
//
//  標準Text Styleをベースにした意味的なフォントスケール。
//  すべて標準Text Style経由のためDynamic Typeに自動対応する。
//

import SwiftUI

enum AppFont {
  static let largeTitle = Font.largeTitle.weight(.bold)
  /// セクション見出し・強調数値
  static let title = Font.title2.weight(.bold)
  static let headline = Font.headline
  static let body = Font.body
  static let subheadline = Font.subheadline
  static let callout = Font.callout
  /// キャプション
  static let caption = Font.caption
  /// 最小キャプション
  static let caption2 = Font.caption2
  /// ライセンス表記等の等幅テキスト
  static let monospaced = Font.system(.body, design: .monospaced)
}
