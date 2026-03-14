import SwiftUI

extension MasteryLevel {
  var color: Color {
    switch self {
    case .learning:
      return .red
    case .reviewing:
      return .orange
    case .familiar:
      return .blue
    case .mastered:
      return .green
    }
  }
}
