//
//  LoginView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/24.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
  @EnvironmentObject var authService: AuthenticationService
  @Environment(\.dismiss) var dismiss
  
  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      
      VStack(spacing: 16) {
        Image(systemName: "swift")
          .font(.system(size: 80))
          .foregroundColor(.orange)
        
        Text("SE Masked Quiz")
          .font(.largeTitle)
          .fontWeight(.bold)
        
        Text("Sign in to track your progress")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      VStack(spacing: 16) {
        SignInWithAppleButton(
          onRequest: { request in
            request.requestedScopes = [.email]
          },
          onCompletion: { result in
            switch result {
            case .success(_):
              // Handled in AuthenticationService
              break
            case .failure(let error):
              authService.error = .signInFailed(error.localizedDescription)
            }
          }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        
        Button("Continue without signing in") {
          dismiss()
        }
        .font(.footnote)
        .foregroundColor(.secondary)
      }
      .padding(.horizontal, 32)
      
      Spacer()
    }
    .padding()
    .alert(
      "Authentication Error",
      isPresented: Binding(
        get: { authService.error != nil },
        set: { _ in authService.error = nil }
      )
    ) {
      Button("OK") {
        authService.error = nil
      }
    } message: {
      if let error = authService.error {
        Text(error.localizedDescription)
      }
    }
    .overlay {
      if authService.isLoading {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(Color.black.opacity(0.3))
      }
    }
  }
}