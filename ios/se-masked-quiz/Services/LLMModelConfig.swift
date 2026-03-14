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

  /// サンプリング温度（0.8Bモデルで構造化出力を安定させるため低めに設定）
  static let temperature: Float = 0.3

  /// 最大生成トークン数
  static let maxTokens: Int = 2048

  /// クイズ生成数の上限（小規模モデルの出力長制約）
  static let maxQuizCount: Int = 3
}
