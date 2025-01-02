//
//  ContentView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

struct ContentView: View {

    @Environment(\.seRepository) var repository
    @State private var proposals: [SwiftEvolution] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(proposals) { proposal in
                    NavigationLink(value: proposal) {
                        VStack(alignment: .leading) {
                            HStack {
                                MarkdownText(proposal.title)
                                    .font(.headline)
                                Text("#\(Int(proposal.proposalId) ?? 0)")
                                    .font(.caption)
                            }
                            MarkdownText(proposal.status ?? "")
                                .font(.subheadline)
                            MarkdownText(proposal.authors)
                                .font(.subheadline)
                            MarkdownText(proposal.reviewManager ?? "")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Swift Evolution")
            .navigationDestination(for: SwiftEvolution.self) { hashable in
                DefaultWebView(htmlContent: hashable.content)
                    .navigationTitle(hashable.title)
            }
        }
        .task {
            do {
                proposals = try await repository.fetch()
            } catch {
                assertionFailure(String(describing: error))
            }
        }
    }
}

#Preview {
    ContentView()
}
