//
//  EnvSample.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

#if CI
enum Env {
    static var microCmsApiKey: String {
        ""
    }

    static var microCmsApiEndpoint: String {
        ""
    }
}
#endif
