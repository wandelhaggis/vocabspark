import Foundation
import SwiftData

/// Records a category transition of a VocabItem over time.
/// Used to reconstruct "how many cards were 'Bekannt' on day X" for the progress chart.
@Model
final class MasteryEvent {
    var id: UUID
    var date: Date
    var vocabItemID: UUID
    /// Previous category as rawValue (stored as string for stability across refactors).
    var fromCategoryRaw: String
    /// New category as rawValue.
    var toCategoryRaw: String
    /// Which deck this event belongs to. Allows per-deck progress charts.
    var deck: LanguageDeck?

    init(vocabItemID: UUID, from: VocabCategory, to: VocabCategory, deck: LanguageDeck?) {
        self.id = UUID()
        self.date = Date()
        self.vocabItemID = vocabItemID
        self.fromCategoryRaw = from.rawValue
        self.toCategoryRaw = to.rawValue
        self.deck = deck
    }

    var fromCategory: VocabCategory? { VocabCategory(rawValue: fromCategoryRaw) }
    var toCategory: VocabCategory? { VocabCategory(rawValue: toCategoryRaw) }
}
