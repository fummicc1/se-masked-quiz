//
//  EnvSample.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

#if CI
  enum Env {
    /// Strapi REST のベース（例: `https://your-cms.example.com/api`）。末尾スラッシュは任意。
    static var strapiBaseURL: String {
      ""
    }

    /// Strapi の API トークン（Settings → API Tokens）。
    static var strapiApiToken: String {
      ""
    }
    static var cloudflareR2Endpoint: String {
      ""
    }

    static var cloudflareR2AccessKey: String {
      ""
    }

    static var cloudflareR2SecretKey: String {
      ""
    }
  }
#endif
