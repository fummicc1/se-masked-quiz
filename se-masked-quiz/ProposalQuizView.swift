//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {
    
    @State private var modalWebUrl: URL?
    @EnvironmentObject var quizViewModel: QuizViewModel
    @State private var isAppeared = false
    @State private var webView: DefaultWebView?

    let proposal: SwiftEvolution
    
    init(proposal: SwiftEvolution) {
        self.proposal = proposal
    }
    
    var body: some View {
        VStack {
            if let webView {
                webView
            }
        }
        .navigationTitle(proposal.title)
        .sheet(isPresented: $quizViewModel.currentQuiz.isNotNil()) {
            QuizSelectionsView()
                .presentationDetents([.medium])
        }
        .onAppear {
            makeWebViewIfNeeded()
            if isAppeared {
                return
            }
            isAppeared = true
            quizViewModel.startQuiz(for: proposal.proposalId)
        }
    }

    private func makeWebViewIfNeeded() {
        if webView == nil {
            webView = DefaultWebView(
                htmlContent: .string(proposal.content),
                onNavigate: { url in
                    modalWebUrl = url
                },
                onMaskedWordTap: { maskIndex in
                    print("Tapped mask index:", maskIndex)
                    quizViewModel.showQuizSelections(index: maskIndex)
                }
            )
        }
    }
}
