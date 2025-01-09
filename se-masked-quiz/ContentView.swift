//
//  ContentView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/01.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.seRepository) var repository
    @Environment(\.quizRepository) var quizRepository
    @StateObject private var quizViewModel: QuizViewModel
    @State private var proposals: AsyncProposals = .idle
    @State private var modalWebUrl: URL?
    @State private var offset: Int = 0
    @State private var shouldLoadNextPage: Bool = false
    
    init() {
        let viewModel = QuizViewModel(quizRepository: QuizRepository.defaultValue)
        _quizViewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                ScrollViewReader { scrollProxy in
                    List {
                        ForEach(proposals.content) { proposal in
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
                            .onAppear {
                                guard let proposalIndex = proposals.content.firstIndex(of: proposal) else {
                                    return
                                }
                                shouldLoadNextPage = proposalIndex >= proposals.content.count - 5
                            }
                        }
                    }
                }
                .navigationTitle("Swift Evolution")
                .navigationDestination(for: SwiftEvolution.self) { proposal in
                    let shouldLoadQuiz = quizViewModel.currentQuiz?.proposalId != proposal.proposalId
                    if shouldLoadQuiz {
                        quizViewModel.startQuiz(for: proposal.proposalId)
                    }
                    return DefaultWebView(
                        htmlContent: .string(proposal.content),
                        onNavigate: { url in
                            modalWebUrl = url
                        },
                        onMaskedWordTap: { maskIndex in
                            print("Tapped mask index:", maskIndex)
                            quizViewModel.showQuizSelections(index: maskIndex)
                        }
                    )
                    .navigationTitle(proposal.title)
                    .sheet(isPresented: $quizViewModel.isShowingQuiz) {
                        QuizView(viewModel: quizViewModel)
                    }
                }
            }
            .onChange(of: shouldLoadNextPage, { oldValue, newValue in
                if !oldValue, newValue {
                    if proposals.isLoading {
                        return
                    }
                    proposals.startLoading()
                    Task {
                        do {
                            let newProposals = try await repository.fetch(offset: offset)
                            var currentProposals = proposals.content
                            currentProposals.append(contentsOf: newProposals)
                            proposals = .loaded(currentProposals)
                            offset = currentProposals.count
                        } catch {
                            proposals = .error(error)
                        }
                    }
                }
            })
            .task {
                if !proposals.content.isEmpty || proposals.isLoading {
                    return
                }
                do {
                    proposals.startLoading()
                    let proposals = try await repository.fetch(offset: offset)
                    offset = proposals.count
                    self.proposals = .loaded(proposals)
                } catch {
                    self.proposals = .error(error)
                }
            }
            #if os(iOS)
            .sheet(item: $modalWebUrl, content: { url in
                DefaultWebView(
                    htmlContent: .url(url),
                    onNavigate: { modalWebUrl = $0 },
                    onMaskedWordTap: { _ in
                    }
                )
            })
            #else
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
                    DefaultWebView(
                        htmlContent: .url(url),
                        onNavigate: { modalWebUrl = $0 },
                        onMaskedWordTap: { _ in
                        }
                    )
                    .frame(
                        width: proxy.size.width * 0.8,
                        height: proxy.size.height * 0.8
                    )
                }
            }
            #endif
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
