import Testing
import Foundation
import SwiftData
@testable import VocabSpark

/// Model-level cascade semantics: deleting a LanguageDeck must remove its
/// dependent records via SwiftData delete rules — not rely on view code
/// manually fetching and deleting them. Required for CloudKit sync, where
/// deletes can arrive from another device without any view code running.
struct DeckCascadeDeleteTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: LanguageDeck.self, VocabItem.self, MasteryEvent.self, SessionRecord.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func deleteDeck_cascadesToItsVocabItems() throws {
        let context = try makeContext()
        let deck = LanguageDeck(name: "Französisch", emoji: "🇫🇷", ttsLanguage: "French")
        context.insert(deck)
        let item = VocabItem(term: "bonjour", translation: "hallo", deck: deck)
        context.insert(item)
        try context.save()

        context.delete(deck)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<VocabItem>()) == 0)
    }

    @Test func deleteDeck_cascadesToItsMasteryEvents() throws {
        let context = try makeContext()
        let deck = LanguageDeck(name: "Französisch", emoji: "🇫🇷", ttsLanguage: "French")
        context.insert(deck)
        let event = MasteryEvent(vocabItemID: UUID(), from: .neu, to: .lernen, deck: deck)
        context.insert(event)
        try context.save()

        context.delete(deck)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<MasteryEvent>()) == 0)
    }

    // MARK: - Cascade boundaries (coverage tests, written green against the
    // finished delete rules — they pin the blast radius, they did not drive it)

    @Test func deleteDeck_keepsSessionRecords() throws {
        let context = try makeContext()
        let deck = LanguageDeck(name: "Französisch", emoji: "🇫🇷", ttsLanguage: "French")
        context.insert(deck)
        context.insert(SessionRecord(totalCards: 10, againCount: 2, hardCount: 0, goodCount: 8))
        try context.save()

        context.delete(deck)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SessionRecord>()) == 1)
    }

    @Test func deleteVocabItem_keepsItsDeck() throws {
        let context = try makeContext()
        let deck = LanguageDeck(name: "Französisch", emoji: "🇫🇷", ttsLanguage: "French")
        context.insert(deck)
        let item = VocabItem(term: "bonjour", translation: "hallo", deck: deck)
        context.insert(item)
        try context.save()

        context.delete(item)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<LanguageDeck>()) == 1)
    }
}
