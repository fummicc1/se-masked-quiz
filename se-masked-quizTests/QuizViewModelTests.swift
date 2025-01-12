import XCTest
@testable import se_masked_quiz

@MainActor
final class QuizViewModelTests: XCTestCase {
    var sut: QuizViewModel!
    var mockRepository: MockQuizRepository!
    
    override func setUp() async throws {
        mockRepository = MockQuizRepository()
        sut = QuizViewModel(quizRepository: mockRepository)
    }
    
    override func tearDown() async throws {
        await mockRepository.clearAll()
        sut = nil
        mockRepository = nil
    }
    
    func testStartQuiz_WhenSuccessful_LoadsQuizAndScore() async throws {
        // Given
        let proposalId = "0001"
        let quizzes = [
            Quiz(id: "1", proposalId: proposalId, index: 0, answer: "Swift", choices: ["Java", "Kotlin", "Rust"]),
            Quiz(id: "2", proposalId: proposalId, index: 1, answer: "async", choices: ["sync", "await", "concurrent"])
        ]
        await mockRepository.setQuizzes(quizzes, for: proposalId)
        
        let existingResults = [
            QuestionResult(index: 0, isCorrect: true, answer: "Swift", userAnswer: "Swift"),
            QuestionResult(index: 1, isCorrect: false, answer: "async", userAnswer: "sync")
        ]
        let existingScore = ProposalScore(proposalId: proposalId, questionResults: existingResults)
        await mockRepository.saveScore(existingScore)
        
        // When
        sut.startQuiz(for: proposalId)
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.allQuiz.count, 2)
        XCTAssertEqual(sut.currentScore?.proposalId, proposalId)
        XCTAssertEqual(sut.currentScore?.correctCount, 1)
        XCTAssertEqual(sut.currentScore?.totalCount, 2)
        
        // Verify restored answers
        XCTAssertEqual(sut.selectedAnswer[0], "Swift")
        XCTAssertEqual(sut.selectedAnswer[1], "sync")
        XCTAssertEqual(sut.isCorrect[0], true)
        XCTAssertEqual(sut.isCorrect[1], false)
    }

    func testStartQuiz_WhenError_HandlesFailure() async throws {
        // Given
        let proposalId = "0001"
        await mockRepository.clearAll()
        try await updateQuizRepository(of: mockRepository) {
            $0.shouldThrowError = true
        }
        
        // When
        sut.startQuiz(for: proposalId)
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(sut.allQuiz.isEmpty)
        XCTAssertNil(sut.currentScore)
    }
    
    func testSelectAnswer_WhenCorrect_UpdatesScoreAndSaves() async throws {
        // Given
        let proposalId = "0001"
        let quiz = Quiz(id: "1", proposalId: proposalId, index: 0, answer: "Swift", choices: ["Java", "Kotlin", "Rust"])
        await mockRepository.setQuizzes([quiz], for: proposalId)
        sut.startQuiz(for: proposalId)
        
        // Wait for quiz to load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        sut.showQuizSelections(index: 0)
        sut.selectAnswer("Swift")
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.currentScore?.correctCount, 1)
        XCTAssertEqual(sut.currentScore?.totalCount, 1)
        XCTAssertEqual(sut.currentScore?.percentage, 100)
        
        // Verify score was saved with correct question result
        let savedScore = await mockRepository.getScore(for: proposalId)
        XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, true)
        XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Swift")
    }
    
    func testSelectAnswer_WhenIncorrect_UpdatesScoreAndSaves() async throws {
        // Given
        let proposalId = "0001"
        let quiz = Quiz(id: "1", proposalId: proposalId, index: 0, answer: "Swift", choices: ["Java", "Kotlin", "Rust"])
        await mockRepository.setQuizzes([quiz], for: proposalId)
        sut.startQuiz(for: proposalId)
        
        // Wait for quiz to load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        sut.showQuizSelections(index: 0)
        sut.selectAnswer("Java")
        
        // Then
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(sut.currentScore?.correctCount, 0)
        XCTAssertEqual(sut.currentScore?.totalCount, 1)
        XCTAssertEqual(sut.currentScore?.percentage, 0)
        
        // Verify score was saved with incorrect question result
        let savedScore = await mockRepository.getScore(for: proposalId)
        XCTAssertEqual(savedScore?.questionResults.first?.isCorrect, false)
        XCTAssertEqual(savedScore?.questionResults.first?.userAnswer, "Java")
    }
    
    func testDismissQuiz_ClearsCurrentQuiz() async throws {
        // Given
        let proposalId = "0001"
        let quiz = Quiz(id: "1", proposalId: proposalId, index: 0, answer: "Swift", choices: ["Java", "Kotlin", "Rust"])
        await mockRepository.setQuizzes([quiz], for: proposalId)
        sut.startQuiz(for: proposalId)
        
        // Wait for quiz to load
        try await Task.sleep(nanoseconds: 100_000_000)
        
        sut.showQuizSelections(index: 0)
        XCTAssertNotNil(sut.currentQuiz)
        
        // When
        sut.dismissQuiz()
        
        // Then
        XCTAssertNil(sut.currentQuiz)
        XCTAssertFalse(sut.isShowingQuiz)
    }
} 

fileprivate func updateQuizRepository<R: QuizRepository>(of repository: R, call: (isolated R) async throws -> Void) async throws {
    try await call(repository)
}
