import Foundation
import SwiftData

@Model
final class SessionRecord {
    var id: UUID
    var date: Date
    var totalCards: Int
    var againCount: Int
    var hardCount: Int
    var goodCount: Int

    init(totalCards: Int, againCount: Int, hardCount: Int, goodCount: Int) {
        self.id = UUID()
        self.date = Date()
        self.totalCards = totalCards
        self.againCount = againCount
        self.hardCount = hardCount
        self.goodCount = goodCount
    }

    var successRate: Double {
        guard totalCards > 0 else { return 0 }
        return Double(goodCount) / Double(totalCards)
    }
}
