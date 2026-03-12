//
//  LLMModelConfig.swift
//  se-masked-quiz
//
//  Created for Issue #12: LLM Model Configuration
//

import Foundation

/// オンデバイスLLMモデルの設定を集約
enum LLMModelConfig {
  /// Hugging Face モデルID
  static let modelId = "mlx-community/Qwen3.5-0.8B-MLX-4bit"

  /// UI表示用のモデル名
  static let displayName = "Qwen3.5 0.8B (4-bit)"

  /// モデルの推定サイズ（バイト）
  static let estimatedSizeBytes: Int64 = 625_000_000

  /// サンプリング温度
  static let temperature: Float = 1.0

  /// 最大生成トークン数
  static let maxTokens: Int = 1024
}
