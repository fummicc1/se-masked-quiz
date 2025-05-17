//
//  SettingScreen.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/02/02.
//

import SwiftUI
import AuthenticationServices

struct SettingScreen: View {
  var body: some View {
    NavigationStack {
      List {
        // Account Section
        Section("アカウント") {
          SignInWithAppleButton { request in
                  request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                  Task {
                    do {
                      guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential
                      else {
                        return
                      }
                      let response = try await userRepository.signIn(with: credential)
                      print(response)
                    } catch {
                      dump(error)
                    }
                  }
                }
                .listRowBackground(Color.clear)
        }

        // License Section
        Section("ライセンス") {
          NavigationLink {
            LicenseScreen()
          } label: {
            Text("ライセンス情報")
          }
        }

        // App Info Section
        Section("アプリ情報") {
          HStack {
            Text("バージョン")
            Spacer()
            Text(
              Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? ""
            )
            .foregroundColor(.gray)
          }
        }
      }
      .navigationTitle("設定")
    }
  }
}

#Preview {
  SettingScreen()
}
