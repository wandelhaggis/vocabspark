import Foundation
import SwiftData

/// CloudKit forbids unique constraints, so sync can produce duplicate decks:
/// e.g. a reinstall where the user re-creates "Französisch" before the iCloud
/// import finishes, or two devices creating the same language independently.
/// This merges such duplicates deterministically (both devices converge on
/// the same winner) — the standard pattern Apple recommends for
/// NSPersistentCloudKitContainer-backed stores.
enum DeckDeduplicator {

    /// Merges duplicate decks (same target + native language) into the oldest
    /// one and removes exact duplicate vocab cards within each deck.
    /// Returns true if anything was changed.
    @discardableResult
    static func deduplicate(in context: ModelContext) -> Bool {
        guard let decks = try? context.fetch(FetchDescriptor<LanguageDeck>()) else { return false }

        var changed = false
        let groups = Dictionary(grouping: decks) { "\($0.ttsLanguage)|\($0.nativeLanguageCode)" }

        for group in groups.values where group.count > 1 {
            // Deterministic winner so every device converges on the same deck.
            let sorted = group.sorted {
                ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
            }
            let winner = sorted[0]
            for loser in sorted.dropFirst() {
                for item in loser.items ?? [] {
                    item.deck = winner
                }
                for event in loser.masteryEvents ?? [] {
                    event.deck = winner
                }
                context.delete(loser)
                changed = true
            }
        }

        if deduplicateCards(in: context) {
            changed = true
        }

        if changed {
            try? context.save()
        }
        return changed
    }

    /// Removes cards that are exact duplicates (same deck, term and
    /// translation), keeping the one with the most learning progress.
    private static func deduplicateCards(in context: ModelContext) -> Bool {
        guard let items = try? context.fetch(FetchDescriptor<VocabItem>()) else { return false }

        var changed = false
        let groups = Dictionary(grouping: items) { item in
            "\(item.deck?.id.uuidString ?? "none")|\(item.term.trimmingCharacters(in: .whitespacesAndNewlines))|\(item.translation.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        for group in groups.values where group.count > 1 {
            // Keep the card with the most progress; tiebreak deterministically.
            let sorted = group.sorted { a, b in
                if a.repetitions != b.repetitions { return a.repetitions > b.repetitions }
                if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
                return a.id.uuidString < b.id.uuidString
            }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                changed = true
            }
        }
        return changed
    }
}
