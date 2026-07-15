import Foundation
import SwiftData

// CloudKit sync: every property needs a default or must be optional, no .unique.
@Model
final class SessionRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var totalCards: Int = 0
    var againCount: Int = 0
    var hardCount: Int = 0
    var goodCount: Int = 0

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
