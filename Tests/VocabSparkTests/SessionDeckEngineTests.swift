import Testing
import Foundation
@testable import VocabSpark

/// Deterministic RNG (SplitMix64) so random-reinsert behavior is testable.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct SessionDeckEngineTests {

    private func ids(_ count: Int) -> [UUID] {
        (0..<count).map { _ in UUID() }
    }

    // MARK: - rateGood

    @Test func rateGood_freshCard_returnsGoodAndMastersCard() {
        let cards = ids(3)
        var engine = SessionDeckEngine(cardIDs: cards)

        let final = engine.rateGood()

        #expect(final == .good)
        #expect(engine.mastered == [cards[0]])
        #expect(engine.currentID == cards[1])
        #expect(engine.results == [.good])
    }

    @Test func rateGood_lastCard_finishesSession() {
        var engine = SessionDeckEngine(cardIDs: ids(1))
        engine.rateGood()
        #expect(engine.isFinished)
    }

    @Test func rateGood_onEmptyDeck_returnsNil() {
        var engine = SessionDeckEngine(cardIDs: [])
        #expect(engine.rateGood() == nil)
        #expect(engine.results.isEmpty)
    }

    @Test func rateGood_recordsExactlyOneResultPerCard() {
        var engine = SessionDeckEngine(cardIDs: ids(2))
        engine.rateAgain()   // card A failed
        engine.rateAgain()   // card B failed
        _ = engine.rateGood()
        _ = engine.rateGood()
        #expect(engine.results.count == 2)
        #expect(engine.isFinished)
    }

    // MARK: - rateAgain

    @Test func rateAgain_movesCardToEndOfDeck() {
        let cards = ids(3)
        var engine = SessionDeckEngine(cardIDs: cards)

        engine.rateAgain()

        #expect(engine.cardIDs == [cards[1], cards[2], cards[0]])
        #expect(engine.mastered.isEmpty)
    }

    @Test func rateAgain_thenLaterGood_locksAgainAsFinalRating() {
        let cards = ids(2)
        var engine = SessionDeckEngine(cardIDs: cards)

        engine.rateAgain()               // fail card A → end of deck
        _ = engine.rateGood()            // master card B
        let finalA = engine.rateGood()   // card A comes back, now known

        #expect(finalA == .again)
        #expect(engine.results == [.good, .again])
    }

    @Test func rateAgain_marksCardAsRepeated() {
        let cards = ids(2)
        var engine = SessionDeckEngine(cardIDs: cards)
        engine.rateAgain()
        #expect(engine.repeatedIDs == [cards[0]])
    }

    @Test func rateAgain_singleCardDeck_keepsCardCurrent() {
        let cards = ids(1)
        var engine = SessionDeckEngine(cardIDs: cards)
        engine.rateAgain()
        #expect(engine.currentID == cards[0])
        #expect(!engine.isFinished)
    }

    // MARK: - Generation (view identity)

    @Test func generation_incrementsOnEveryAdvance_evenForSameCard() {
        var engine = SessionDeckEngine(cardIDs: ids(1))
        #expect(engine.generation == 0)
        engine.rateAgain()   // same card stays current …
        #expect(engine.generation == 1)   // … but identity must change
        _ = engine.rateGood()
        #expect(engine.generation == 2)
    }

    // MARK: - Random reinsert (vocab test drill)

    @Test func randomReinsert_neverPlacesCardBackAtFront() {
        // Drill mode: a failed card must not come back immediately
        // (deck ≥ 3 remaining cards → position ≥ 2).
        for seed: UInt64 in 1...50 {
            let cards = ids(5)
            var engine = SessionDeckEngine(
                cardIDs: cards,
                reinsertPolicy: .randomLater,
                rng: SeededRNG(seed: seed)
            )
            engine.rateAgain()
            let newIndex = engine.cardIDs.firstIndex(of: cards[0])
            #expect(newIndex != nil && newIndex! >= 2, "seed \(seed): failed card came back at \(String(describing: newIndex))")
        }
    }

    @Test func randomReinsert_twoCardDeck_putsCardAtEnd() {
        let cards = ids(2)
        var engine = SessionDeckEngine(
            cardIDs: cards,
            reinsertPolicy: .randomLater,
            rng: SeededRNG(seed: 7)
        )
        engine.rateAgain()
        #expect(engine.cardIDs == [cards[1], cards[0]])
    }
}
