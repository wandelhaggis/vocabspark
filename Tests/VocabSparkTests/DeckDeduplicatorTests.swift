import Testing
import Foundation
import SwiftData
@testable import VocabSpark

/// TDD tests for CloudKit duplicate cleanup: written before the
/// implementation, seen red against the no-op stub.
struct DeckDeduplicatorTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: LanguageDeck.self, VocabItem.self, MasteryEvent.self, SessionRecord.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeDeck(_ context: ModelContext, tts: String = "French", native: String = "de", createdAt: Date) -> LanguageDeck {
        let deck = LanguageDeck(name: tts, emoji: "🏳️", ttsLanguage: tts, nativeLanguageCode: native)
        deck.createdAt = createdAt
        context.insert(deck)
        return deck
    }

    @Test func dedupe_mergesSameLanguagePairIntoOldestDeck() throws {
        let context = try makeContext()
        let older = makeDeck(context, createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeDeck(context, createdAt: Date(timeIntervalSince1970: 2_000))
        context.insert(VocabItem(term: "bonjour", translation: "hallo", deck: older))
        context.insert(VocabItem(term: "merci", translation: "danke", deck: newer))
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        let decks = try context.fetch(FetchDescriptor<LanguageDeck>())
        #expect(decks.count == 1)
        #expect(decks.first?.id == older.id)
        #expect(try context.fetchCount(FetchDescriptor<VocabItem>()) == 2)
        let items = try context.fetch(FetchDescriptor<VocabItem>())
        #expect(items.allSatisfy { $0.deck?.id == older.id })
    }

    @Test func dedupe_repointsMasteryEventsToSurvivingDeck() throws {
        let context = try makeContext()
        let older = makeDeck(context, createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = makeDeck(context, createdAt: Date(timeIntervalSince1970: 2_000))
        let event = MasteryEvent(vocabItemID: UUID(), from: .neu, to: .lernen, deck: newer)
        context.insert(event)
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        let events = try context.fetch(FetchDescriptor<MasteryEvent>())
        #expect(events.count == 1)
        #expect(events.first?.deck?.id == older.id)
    }

    @Test func dedupe_keepsDecksOfDifferentTargetLanguages() throws {
        let context = try makeContext()
        _ = makeDeck(context, tts: "French", createdAt: Date(timeIntervalSince1970: 1_000))
        _ = makeDeck(context, tts: "Spanish", createdAt: Date(timeIntervalSince1970: 2_000))
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        #expect(try context.fetchCount(FetchDescriptor<LanguageDeck>()) == 2)
    }

    @Test func dedupe_keepsSameTargetWithDifferentNativeLanguage() throws {
        let context = try makeContext()
        _ = makeDeck(context, tts: "French", native: "de", createdAt: Date(timeIntervalSince1970: 1_000))
        _ = makeDeck(context, tts: "French", native: "en", createdAt: Date(timeIntervalSince1970: 2_000))
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        #expect(try context.fetchCount(FetchDescriptor<LanguageDeck>()) == 2)
    }

    @Test func dedupe_removesExactDuplicateCards_keepingTheOneWithProgress() throws {
        let context = try makeContext()
        let deck = makeDeck(context, createdAt: Date(timeIntervalSince1970: 1_000))
        let fresh = VocabItem(term: "bonjour", translation: "hallo", deck: deck)
        let learned = VocabItem(term: "bonjour", translation: "hallo", deck: deck)
        learned.repetitions = 3
        learned.interval = 4
        context.insert(fresh)
        context.insert(learned)
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        let items = try context.fetch(FetchDescriptor<VocabItem>())
        #expect(items.count == 1)
        #expect(items.first?.repetitions == 3)
    }

    @Test func dedupe_keepsCardsWithSameTermButDifferentTranslation() throws {
        let context = try makeContext()
        let deck = makeDeck(context, createdAt: Date(timeIntervalSince1970: 1_000))
        context.insert(VocabItem(term: "temps", translation: "Zeit", deck: deck))
        context.insert(VocabItem(term: "temps", translation: "Wetter", deck: deck))
        try context.save()

        DeckDeduplicator.deduplicate(in: context)

        #expect(try context.fetchCount(FetchDescriptor<VocabItem>()) == 2)
    }
}
