//
//  SemanticColor.swift
//  se-masked-quiz
//
//  用途別の意味的カラー。ブランド関連（accent/streak）は AppColor のオレンジを、
//  それ以外（正解/不正解等）はライト/ダーク自動対応のシステムカラーをそのまま用いる。
//

import SwiftUI

/// ライト/ダークで異なる色を返す ShapeStyle。UIKit/AppKit非依存でマルチプラットフォーム対応する。
struct DynamicColor: ShapeStyle {
  let light: Color
  let dark: Color

  func resolve(in environment: EnvironmentValues) -> Color.Resolved {
    (environment.colorScheme == .dark ? dark : light).resolve(in: environment)
  }
}

enum SemanticColor {
  /// アクセントカラー。ダークモードでは視認性のため明るめのバリアントを使う
  static let accent = DynamicColor(light: AppColor.brand, dark: AppColor.brandLight)
  /// ストリーク（連続学習）を表す色。炎アイコン等に使用
  static let streak = DynamicColor(light: AppColor.brand, dark: AppColor.brandLight)
  /// 正解時の色
  static let correct = Color.green
  /// 不正解時の色
  static let incorrect = Color.red
  /// 警告・中間難易度を表す色
  static let warning = Color.orange
  /// 進行中の状態を表す色
  static let inProgress = Color.blue
  /// 未開始・無効な状態を表す色
  static let neutral = Color.secondary
}
