//
//  LLMModelConfig.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM Model Configuration
//

import Foundation

/// 利用可能なLLMモデルの選択肢
enum LLMModelOption: String, CaseIterable, Codable, Identifiable {
  case small
  case medium

  var id: String { rawValue }

  /// Hugging Face モデルID
  var modelId: String {
    switch self {
    case .small:
      return "mlx-community/Qwen3.5-0.8B-MLX-4bit"
    case .medium:
      return "mlx-community/Qwen3.5-2B-MLX-4bit"
    }
  }

  /// UI表示用のモデル名
  var displayName: String {
    switch self {
    case .small:
      return "Qwen3.5 0.8B (4-bit)"
    case .medium:
      return "Qwen3.5 2B (4-bit)"
    }
  }

  /// モデルの推定サイズ（バイト）
  var estimatedSizeBytes: Int64 {
    switch self {
    case .small:
      return 625_000_000
    case .medium:
      return 1_600_000_000
    }
  }

  /// クイズ生成数の上限（小規模モデルほど出力長が制限される）
  var maxQuizCount: Int {
    switch self {
    case .small:
      return 3
    case .medium:
      return 5
    }
  }

  /// モデル性能の簡易説明
  var capabilityDescription: String {
    switch self {
    case .small:
      return "軽量・高速。基本的なクイズ生成に最適"
    case .medium:
      return "高精度。より複雑な問題を正確に理解"
    }
  }
}

/// オンデバイスLLMモデルの設定を集約
enum LLMModelConfig {
  private static let selectedModelKey = "selectedLLMModel"

  /// ユーザーが選択中のモデル
  static var selectedModel: LLMModelOption {
    get {
      guard let raw = UserDefaults.standard.string(forKey: selectedModelKey),
            let option = LLMModelOption(rawValue: raw)
      else {
        return .small
      }
      return option
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: selectedModelKey)
    }
  }

  /// 選択中モデルのHugging Face モデルID
  static var modelId: String { selectedModel.modelId }

  /// UI表示用のモデル名
  static var displayName: String { selectedModel.displayName }

  /// モデルの推定サイズ（バイト）
  static var estimatedSizeBytes: Int64 { selectedModel.estimatedSizeBytes }

  /// サンプリング温度
  static let temperature: Float = 0.3

  /// 最大生成トークン数
  static let maxTokens: Int = 2048

  /// クイズ生成数の上限
  static var maxQuizCount: Int { selectedModel.maxQuizCount }
}
