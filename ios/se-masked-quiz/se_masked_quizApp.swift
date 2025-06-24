//
//  se_masked_quizApp.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

@main
struct se_masked_quizApp: App {
  @StateObject private var authService = AuthenticationService()
  
  var body: some Scene {
    WindowGroup {
      ProposalListScreen()
        .environmentObject(authService)
    }
  }
}
