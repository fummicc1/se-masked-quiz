//
//  MarkdownText.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(
            try! AttributedString(markdown: text.data(using: .utf8)!)
        )
    }
}
