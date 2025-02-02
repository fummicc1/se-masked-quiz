//
//  SettingScreen.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/02/02.
//

import SwiftUI

struct SettingScreen: View {
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("アカウント") {
                    // Sign in with Apple button will be implemented later
                    Text("Appleでサインイン")
                        .foregroundColor(.gray)
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
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                            .foregroundColor(.gray)
                    }
                    
                    NavigationLink {
                        // Privacy Policy screen will be implemented later
                        Text("プライバシーポリシー")
                    } label: {
                        Text("プライバシーポリシー")
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
