struct Quiz: Codable, Identifiable {
    var id: String
    var proposalId: String
    var index: Int
    var answer: String
    var choices: [String]  // 誤答の選択肢3つ
    var allChoices: [String]

    init(id: String, proposalId: String, index: Int, answer: String, choices: [String]) {
        self.id = id
        self.proposalId = proposalId
        self.index = index
        self.answer = answer
        self.choices = choices
        allChoices = (choices + [answer]).shuffled()
    }
}
