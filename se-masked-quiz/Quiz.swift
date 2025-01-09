struct Quiz: Codable, Identifiable {
    var id: String
    var proposalId: String
    var maskedWord: String
    var answer: String
    var choices: [String]  // 誤答の選択肢3つ
    
    var allChoices: [String] {
        (choices + [answer]).shuffled()
    }
}
