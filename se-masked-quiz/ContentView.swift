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
    @State private var modalWebUrl: URL?
    
    var body: some View {
        GeometryReader { proxy in
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
                    DefaultWebView(
                        htmlContent: .string(hashable.content),
                        onNavigate: { url in
                            modalWebUrl = url
                        }
                    )
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
            .sheet(item: $modalWebUrl) { url in
                VStack(spacing: 0) {
                    HStack {
                        Text(url.absoluteString)
                        Spacer()
                        Button("Close") {
                            modalWebUrl = nil
                        }
                    }
                    .padding(8)
                    DefaultWebView(htmlContent: .url(url)) {
                        modalWebUrl = $0
                    }
                    .frame(
                        width: proxy.size.width * 0.8,
                        height: proxy.size.height * 0.8
                    )
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String {
        absoluteString
    }
}

#Preview {
    ContentView()
}
