//
//  EnvSample.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

#if CI
  enum Env {
    /// Payload CMS サーバーのベースURL
    static var serverBaseURL: String {
      ""
    }

    /// Payload CMS Users API キー
    static var serverApiKey: String {
      ""
    }
  }
#endif
