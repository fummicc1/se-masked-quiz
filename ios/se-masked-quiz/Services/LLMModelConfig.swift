//
//  LLMModelConfig.swift
//  se-masked-quiz
//
// オンデバイスLLMモデルの選択肢と設定
//

import Foundation

enum LLMModelOption: String, CaseIterable, Codable, Identifiable {
  case small
  case medium

  var id: String { rawValue }

  var modelId: String {
    switch self {
    case .small:
      return "mlx-community/Qwen3.5-0.8B-MLX-4bit"
    case .medium:
      return "mlx-community/Qwen3.5-2B-MLX-4bit"
    }
  }

  var displayName: String {
    switch self {
    case .small:
      return "Qwen3.5 0.8B (4-bit)"
    case .medium:
      return "Qwen3.5 2B (4-bit)"
    }
  }

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

  var capabilityDescription: String {
    switch self {
    case .small:
      return "軽量・高速。基本的なクイズ生成に最適"
    case .medium:
      return "高精度。より複雑な問題を正確に理解"
    }
  }
}

enum LLMModelConfig {
  private static let selectedModelKey = "selectedLLMModel"

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

  static var modelId: String { selectedModel.modelId }

  static var displayName: String { selectedModel.displayName }

  static var estimatedSizeBytes: Int64 { selectedModel.estimatedSizeBytes }

  static let temperature: Float = 0.3

  static let maxTokens: Int = 2048

  static var maxQuizCount: Int { selectedModel.maxQuizCount }
}
