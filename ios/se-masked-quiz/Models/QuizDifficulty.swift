//
//  QuizDifficulty.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/12/19.
//


/// クイズ難易度
enum QuizDifficulty: String, Codable {
  case beginner = "初級"      // 基本的な用語・概念
  case intermediate = "中級"  // 提案の詳細理解
  case advanced = "上級"      // 複雑な概念・関連性
}