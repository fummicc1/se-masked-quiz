import AuthenticationServices
import Moya
import MoyaAPIClient

// Error
public enum UserRepositoryError: LocalizedError {
  case invalidToken
}

// API Request
enum UserAPITarget: APITarget {
  var baseURL: URL {
    URL(string: "\(Env.serverBaseURL)/api")!
  }

  var path: String {
    switch self {
    case .signIn:
      return "/auth/apple/sign-in"
    }
  }

  var method: Moya.Method {
    switch self {
    case .signIn:
      return .post
    }
  }

  var task: Moya.Task {
    switch self {
    case .signIn(let withCredential):
      guard let idToken = withCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
        return .requestPlain
      }
      let body = [
        "idToken": idToken,
        "displayName": withCredential.fullName?.displayName
      ]
      return .requestJSONEncodable(body)
    }
  }

  var headers: [String : String]? {
    [ "Authorization": "Bearer \(Env.serverApiKey)" ]
  }

  case signIn(withCredential: ASAuthorizationAppleIDCredential)
}


public struct UserSignInResponse: Codable {
  let id: String
  let email: String?
  let displayName: String?
  let accessToken: String
  let refreshToken: String
  let isNewUser: Bool
}

// Repository
/// @mockable
public actor UserRepository {
  
  private let apiClient: APIClient<UserAPITarget>
  
  init(apiClient: APIClient<UserAPITarget> = .init()) {
    self.apiClient = apiClient
  }
  
  public func signIn(
    with credential: ASAuthorizationAppleIDCredential
  ) async throws -> UserSignInResponse {
    guard credential.identityToken
      .flatMap({ String(data: $0, encoding: .utf8) }) != nil else {
      throw UserRepositoryError.invalidToken
    }
    let response: UserSignInResponse = try await apiClient
      .send(with: .signIn(withCredential: credential))
    let accessToken = response.accessToken
    let refreshToken = response.refreshToken
    // Save tokens to Keychain
    
  }
}

extension PersonNameComponents {
  fileprivate var displayName: String {
    let formatter = PersonNameComponentsFormatter()
    formatter.style = .default // Family Name + Given Name
    return formatter.string(from: self)
  }
}

public let userRepository = UserRepository()
