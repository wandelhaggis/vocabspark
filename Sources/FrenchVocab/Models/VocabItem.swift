import Foundation
import SwiftData

enum VocabCategory: String, CaseIterable {
    case neu = "Neu"
    case lernen = "Lernen"
    case festigen = "Festigen"
    case bekannt = "Bekannt"
}

@Model
final class VocabItem {
    var id: UUID
    var term: String            // the word being learned (foreign language)
    var translation: String     // the translation (German / native)
    var createdAt: Date

    // SRS fields
    var interval: Int
    var easeFactor: Double
    var repetitions: Int
    var nextReviewDate: Date
    var lastReviewedAt: Date?

    // Example sentence (auto-generated via GPT)
    var exampleSentence: String?
    var exampleTranslation: String?

    // Language deck relationship
    var deck: LanguageDeck?

    init(term: String, translation: String, deck: LanguageDeck? = nil) {
        self.id = UUID()
        self.term = term
        self.translation = translation
        self.deck = deck
        self.createdAt = Date()
        self.interval = 0
        self.easeFactor = 2.5
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.lastReviewedAt = nil
    }

    var isDue: Bool {
        nextReviewDate <= Date()
    }

    var category: VocabCategory {
        if repetitions == 0 { return .neu }
        if interval <= 1 { return .lernen }
        if interval <= 7 { return .festigen }
        return .bekannt
    }

    var statusLabel: String { category.rawValue }

    func applyCategory(_ cat: VocabCategory) {
        let now = Date()
        switch cat {
        case .neu:
            repetitions = 0
            interval = 0
            nextReviewDate = now
            lastReviewedAt = nil
        case .lernen:
            repetitions = 1
            interval = 1
            easeFactor = max(easeFactor, 2.0)
            nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        case .festigen:
            repetitions = 2
            interval = 4
            easeFactor = max(easeFactor, 2.0)
            nextReviewDate = Calendar.current.date(byAdding: .day, value: 4, to: now) ?? now
        case .bekannt:
            repetitions = 3
            interval = 14
            easeFactor = max(easeFactor, 2.3)
            nextReviewDate = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        }
    }
}
