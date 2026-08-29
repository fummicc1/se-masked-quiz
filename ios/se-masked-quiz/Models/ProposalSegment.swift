//
//  ProposalSegment.swift
//  se-masked-quiz
//
//  読み上げ対象の段落を構成する要素。空欄は位置だけを持ち、答えを運ばない。
//

import Foundation

enum ProposalSegment: Equatable, Sendable {
  case text(String)
  case mask(index: Int)
}

extension ProposalSegment: Decodable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case text
    case index
  }

  private enum Kind: String, Decodable {
    case text
    case mask
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .text:
      self = .text(try container.decode(String.self, forKey: .text))
    case .mask:
      self = .mask(index: try container.decode(Int.self, forKey: .index))
    }
  }
}
