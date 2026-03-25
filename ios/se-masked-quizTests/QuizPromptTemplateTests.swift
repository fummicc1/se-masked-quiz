import XCTest

@testable import se_masked_quiz

final class QuizPromptTemplateTests: XCTestCase {

  // MARK: - parseResponse Tests

  func testParseResponse_ValidCamelCaseJSON() throws {
    let json = """
    {
      "quizzes": [
        {
          "question": "What does SE-0001 propose?",
          "correctAnswer": "Package Manager",
          "wrongAnswers": ["Concurrency", "Macros", "Generics"],
          "explanation": "SE-0001 introduces the Swift Package Manager",
          "conceptTested": "Package Management"
        }
      ]
    }
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
    XCTAssertEqual(response.quizzes[0].question, "What does SE-0001 propose?")
    XCTAssertEqual(response.quizzes[0].correctAnswer, "Package Manager")
    XCTAssertEqual(response.quizzes[0].wrongAnswers.count, 3)
  }

  func testParseResponse_ValidSnakeCaseJSON() throws {
    let json = """
    {
      "quizzes": [
        {
          "question": "What is async/await?",
          "correct_answer": "Concurrency primitive",
          "wrong_answers": ["UI framework", "Database", "Network"],
          "explanation": "async/await enables structured concurrency",
          "concept_tested": "Concurrency"
        }
      ]
    }
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
    XCTAssertEqual(response.quizzes[0].correctAnswer, "Concurrency primitive")
  }

  func testParseResponse_WrappedInMarkdownCodeBlock() throws {
    let json = """
    Here is the quiz:
    ```json
    {
      "quizzes": [
        {
          "question": "Test question?",
          "correctAnswer": "A",
          "wrongAnswers": ["B", "C", "D"],
          "explanation": "Because A",
          "conceptTested": "Testing"
        }
      ]
    }
    ```
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
    XCTAssertEqual(response.quizzes[0].correctAnswer, "A")
  }

  func testParseResponse_WrappedInGenericCodeBlock() throws {
    let json = """
    ```
    {
      "quizzes": [
        {
          "question": "Test?",
          "correctAnswer": "Yes",
          "wrongAnswers": ["No", "Maybe", "Never"],
          "explanation": "Correct",
          "conceptTested": "Basics"
        }
      ]
    }
    ```
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
  }

  func testParseResponse_WithTrailingComma() throws {
    let json = """
    {
      "quizzes": [
        {
          "question": "Test?",
          "correctAnswer": "A",
          "wrongAnswers": ["B", "C", "D",],
          "explanation": "Explanation",
          "conceptTested": "Test",
        },
      ]
    }
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
  }

  func testParseResponse_WithMissingClosingBrackets() throws {
    let json = """
    {
      "quizzes": [
        {
          "question": "Test?",
          "correctAnswer": "A",
          "wrongAnswers": ["B", "C", "D"],
          "explanation": "Explanation",
          "conceptTested": "Test"
        }
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
  }

  func testParseResponse_WithSurroundingText() throws {
    let json = """
    Sure! Here are the quizzes:
    {"quizzes":[{"question":"Q?","correctAnswer":"A","wrongAnswers":["B","C","D"],"explanation":"E","conceptTested":"C"}]}
    Hope this helps!
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 1)
  }

  func testParseResponse_MultipleQuizzes() throws {
    let json = """
    {
      "quizzes": [
        {
          "question": "Q1?",
          "correctAnswer": "A1",
          "wrongAnswers": ["B1", "C1", "D1"],
          "explanation": "E1",
          "conceptTested": "C1"
        },
        {
          "question": "Q2?",
          "correctAnswer": "A2",
          "wrongAnswers": ["B2", "C2", "D2"],
          "explanation": "E2",
          "conceptTested": "C2"
        }
      ]
    }
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertEqual(response.quizzes.count, 2)
    XCTAssertEqual(response.quizzes[0].question, "Q1?")
    XCTAssertEqual(response.quizzes[1].question, "Q2?")
  }

  func testParseResponse_InvalidJSON_Throws() {
    let json = "This is not JSON at all"

    XCTAssertThrowsError(try QuizPromptTemplate.parseResponse(json))
  }

  func testParseResponse_EmptyQuizzesArray() throws {
    let json = """
    {"quizzes": []}
    """

    let response = try QuizPromptTemplate.parseResponse(json)
    XCTAssertTrue(response.quizzes.isEmpty)
  }

  // MARK: - validate Tests

  func testValidate_ValidItem_ReturnsTrue() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "What is Swift?",
      correctAnswer: "A programming language",
      wrongAnswers: ["A database", "An OS", "A browser"],
      explanation: "Swift is Apple's programming language",
      conceptTested: "Basics"
    )

    XCTAssertTrue(QuizPromptTemplate.validate(item))
  }

  func testValidate_EmptyQuestion_ReturnsFalse() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "",
      correctAnswer: "A",
      wrongAnswers: ["B", "C", "D"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertFalse(QuizPromptTemplate.validate(item))
  }

  func testValidate_EmptyCorrectAnswer_ReturnsFalse() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "Q?",
      correctAnswer: "",
      wrongAnswers: ["B", "C", "D"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertFalse(QuizPromptTemplate.validate(item))
  }

  func testValidate_TooFewWrongAnswers_ReturnsFalse() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "Q?",
      correctAnswer: "A",
      wrongAnswers: ["B"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertFalse(QuizPromptTemplate.validate(item))
  }

  func testValidate_TwoWrongAnswers_ReturnsTrue() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "Q?",
      correctAnswer: "A",
      wrongAnswers: ["B", "C"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertTrue(QuizPromptTemplate.validate(item))
  }

  func testValidate_EmptyWrongAnswer_ReturnsFalse() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "Q?",
      correctAnswer: "A",
      wrongAnswers: ["B", "", "D"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertFalse(QuizPromptTemplate.validate(item))
  }

  func testValidate_DuplicateAnswers_ReturnsFalse() {
    let item = QuizPromptTemplate.QuizGenerationResponse.GeneratedQuizItem(
      question: "Q?",
      correctAnswer: "A",
      wrongAnswers: ["A", "C", "D"],
      explanation: "E",
      conceptTested: "C"
    )

    XCTAssertFalse(QuizPromptTemplate.validate(item))
  }

  // MARK: - stripHTML Tests

  func testStripHTML_RemovesTags() {
    let html = "<p>Hello <strong>World</strong></p>"
    let result = QuizPromptTemplate.stripHTML(html)
    XCTAssertEqual(result, "Hello World")
  }

  func testStripHTML_HandlesEmptyString() {
    XCTAssertEqual(QuizPromptTemplate.stripHTML(""), "")
  }

  func testStripHTML_PlainTextPassesThrough() {
    let text = "No HTML here"
    XCTAssertEqual(QuizPromptTemplate.stripHTML(text), text)
  }

  func testStripHTML_HandlesComplexHTML() {
    let html = """
    <div class="proposal"><h1>SE-0001</h1><p>This is a <a href="#">link</a>.</p></div>
    """
    let result = QuizPromptTemplate.stripHTML(html)
    XCTAssertTrue(result.contains("SE-0001"))
    XCTAssertTrue(result.contains("link"))
    XCTAssertFalse(result.contains("<"))
    XCTAssertFalse(result.contains(">"))
  }

  // MARK: - buildQuizGenerationPrompt Tests

  func testBuildPrompt_ContainsDifficultyAndCount() {
    let prompt = QuizPromptTemplate.buildQuizGenerationPrompt(
      content: "Test content",
      difficulty: .beginner,
      count: 3
    )

    XCTAssertTrue(prompt.contains("3"))
    XCTAssertTrue(prompt.contains("Easy"))
  }

  func testBuildPrompt_TruncatesLongContent() {
    let longContent = String(repeating: "A", count: 2000)
    let prompt = QuizPromptTemplate.buildQuizGenerationPrompt(
      content: longContent,
      difficulty: .intermediate,
      count: 1
    )

    // 800文字制限 + プロンプト文のため、元の2000文字は含まれない
    XCTAssertTrue(prompt.count < 2000)
  }

  func testBuildPrompt_StripsHTMLFromContent() {
    let htmlContent = "<p>This is <strong>HTML</strong> content</p>"
    let prompt = QuizPromptTemplate.buildQuizGenerationPrompt(
      content: htmlContent,
      difficulty: .intermediate,
      count: 1
    )

    XCTAssertFalse(prompt.contains("<p>"))
    XCTAssertFalse(prompt.contains("<strong>"))
    XCTAssertTrue(prompt.contains("HTML"))
    XCTAssertTrue(prompt.contains("content"))
  }
}
