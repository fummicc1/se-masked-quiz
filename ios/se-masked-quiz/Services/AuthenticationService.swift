//
//  AuthenticationService.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/24.
//

import AuthenticationServices
import Foundation
import SwiftUI

@MainActor
class AuthenticationService: NSObject, ObservableObject {
  @Published var isAuthenticated = false
  @Published var currentUser: AuthUser?
  @Published var isLoading = false
  @Published var error: AuthError?
  
  private let serverURL = Env.serverURL
  var authToken: String? {
    get { UserDefaults.standard.string(forKey: "authToken") }
    set { UserDefaults.standard.set(newValue, forKey: "authToken") }
  }
  
  override init() {
    super.init()
    checkAuthenticationStatus()
  }
  
  func checkAuthenticationStatus() {
    guard let token = authToken else {
      isAuthenticated = false
      return
    }
    
    Task {
      await verifyToken(token)
    }
  }
  
  func signInWithApple() async {
    isLoading = true
    error = nil
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.email]

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
    isLoading = false
  }
  
  func signOut() {
    authToken = nil
    currentUser = nil
    isAuthenticated = false
  }
  
  private func verifyToken(_ token: String) async {
    do {
      var request = URLRequest(url: URL(string: "\(serverURL)/auth/verify")!)
      request.httpMethod = "POST"
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      
      let (data, response) = try await URLSession.shared.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        throw AuthError.invalidToken
      }
      
      let result = try JSONDecoder().decode(VerifyResponse.self, from: data)
      
      await MainActor.run {
        self.currentUser = AuthUser(id: result.userId, email: result.email)
        self.isAuthenticated = true
      }
    } catch {
      await MainActor.run {
        self.authToken = nil
        self.isAuthenticated = false
        self.error = .verificationFailed(error.localizedDescription)
      }
    }
  }
  
  private func authenticate(with credential: ASAuthorizationAppleIDCredential) async {
    guard let identityTokenData = credential.identityToken,
          let identityToken = String(data: identityTokenData, encoding: .utf8) else {
      await MainActor.run {
        self.error = .invalidCredentials
        self.isLoading = false
      }
      return
    }
    
    let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    
    let requestBody = AppleSignInRequest(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      user: credential.email != nil ? AppleSignInRequest.User(
        email: credential.email,
        name: credential.fullName != nil ? AppleSignInRequest.User.Name(
          firstName: credential.fullName?.givenName,
          lastName: credential.fullName?.familyName
        ) : nil
      ) : nil
    )
    
    do {
      var request = URLRequest(url: URL(string: "\(serverURL)/auth/apple")!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(requestBody)
      
      let (data, response) = try await URLSession.shared.data(for: request)
      
      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        throw AuthError.serverError
      }
      
      let result = try JSONDecoder().decode(AppleSignInResponse.self, from: data)
      
      await MainActor.run {
        self.authToken = result.token
        self.currentUser = AuthUser(
          id: result.user.id,
          email: result.user.email
        )
        self.isAuthenticated = true
        self.isLoading = false
      }
    } catch {
      await MainActor.run {
        self.error = .authenticationFailed(error.localizedDescription)
        self.isLoading = false
      }
    }
  }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationService: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      return
    }
    
    Task {
      await authenticate(with: appleIDCredential)
    }
  }
  
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    self.error = .signInFailed(error.localizedDescription)
    isLoading = false
  }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let window = UIApplication.shared.windows.first else {
      fatalError("No window found")
    }
    return window
  }
}

// MARK: - Models
struct AuthUser: Codable {
  let id: String
  let email: String?
}

enum AuthError: LocalizedError {
  case signInFailed(String)
  case invalidCredentials
  case invalidToken
  case serverError
  case authenticationFailed(String)
  case verificationFailed(String)
  
  var errorDescription: String? {
    switch self {
    case .signInFailed(let message):
      return "Sign in failed: \(message)"
    case .invalidCredentials:
      return "Invalid credentials received from Apple"
    case .invalidToken:
      return "Invalid authentication token"
    case .serverError:
      return "Server error occurred"
    case .authenticationFailed(let message):
      return "Authentication failed: \(message)"
    case .verificationFailed(let message):
      return "Token verification failed: \(message)"
    }
  }
}

// MARK: - Request/Response Models
struct AppleSignInRequest: Codable {
  let identityToken: String
  let authorizationCode: String?
  let user: User?
  
  struct User: Codable {
    let email: String?
    let name: Name?
    
    struct Name: Codable {
      let firstName: String?
      let lastName: String?
    }
  }
}

struct AppleSignInResponse: Codable {
  let success: Bool
  let token: String
  let user: UserInfo
  
  struct UserInfo: Codable {
    let id: String
    let email: String?
    let emailVerified: Bool?
    let isPrivateEmail: Bool?
  }
}

struct VerifyResponse: Codable {
  let success: Bool
  let userId: String
  let email: String?
}
