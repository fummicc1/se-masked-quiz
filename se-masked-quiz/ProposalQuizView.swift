//
//  ProposalQuizView.swift
//  se-masked-quiz
//
//  Created by Fumiya Tanaka on 2025/01/10.
//

import SwiftUI

struct ProposalQuizView: View {
    
    @State private var modalWebUrl: URL?
    @StateObject private var quizViewModel: QuizViewModel
    @State private var isAppeared = false
    @State private var contentOffsetY: CGFloat? = 0
    
    let proposal: SwiftEvolution
    
    init(
        quizViewModel: StateObject<QuizViewModel>,
        proposal: SwiftEvolution
    ) {
        self._quizViewModel = quizViewModel
        self.proposal = proposal
    }
    
    var body: some View {
        DefaultWebView(
            htmlContent: .string(proposal.content),
            onNavigate: { url in
                modalWebUrl = url
            },
            onMaskedWordTap: { maskIndex in
                print("Tapped mask index:", maskIndex)
                quizViewModel.showQuizSelections(index: maskIndex)
            },
            contentOffsetY: $contentOffsetY
        )
        .navigationTitle(proposal.title)
        .sheet(isPresented: $quizViewModel.currentQuiz.isNotNil()) {
            QuizSelectionsView(viewModel: _quizViewModel)
        }
        .onAppear {
            if isAppeared {
                return
            }
            isAppeared = true
            quizViewModel.startQuiz(for: proposal.proposalId)
        }
    }
}
