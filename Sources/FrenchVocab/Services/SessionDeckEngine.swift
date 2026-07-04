import Foundation

/// Model-free deck state machine for a learning session.
/// Cards cycle until rated "Gewusst" (.good). A card that was ever rated
/// "Nochmal" (.again) keeps .again as its final SRS rating for the session.
/// `generation` increases on every card advance — views use it as identity
/// so the outgoing card always animates with its own (old) content, even
/// when the same card comes right back (single-card deck).
struct SessionDeckEngine {

    /// Where a "Nochmal" card is reinserted into the deck.
    enum ReinsertPolicy {
        /// SRS session: card goes to the end of the deck.
        case toEnd
        /// Vocab test drill: card comes back at a random later position.
        case randomLater
    }

    private(set) var cardIDs: [UUID]
    private(set) var mastered: Set<UUID> = []
    /// IDs that were rated "Nochmal" at least once this session.
    private(set) var repeatedIDs: Set<UUID> = []
    /// One final rating per mastered card, in mastering order.
    private(set) var results: [SRSRating] = []
    private(set) var generation: Int = 0

    let totalCount: Int
    private let reinsertPolicy: ReinsertPolicy
    private var rng: any RandomNumberGenerator

    init(
        cardIDs: [UUID],
        reinsertPolicy: ReinsertPolicy = .toEnd,
        rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.cardIDs = cardIDs
        self.totalCount = cardIDs.count
        self.reinsertPolicy = reinsertPolicy
        self.rng = rng
    }

    var currentID: UUID? { cardIDs.first }
    var isFinished: Bool { cardIDs.isEmpty }

    /// "Nochmal": the card goes back into the deck and its final SRS rating
    /// for this session is locked to .again.
    mutating func rateAgain() {
        guard !cardIDs.isEmpty else { return }
        let id = cardIDs.removeFirst()
        repeatedIDs.insert(id)

        switch reinsertPolicy {
        case .toEnd:
            cardIDs.append(id)
        case .randomLater:
            // Not immediately again: position ≥ 2 whenever the deck allows it.
            let insertAt = cardIDs.isEmpty
                ? 0
                : Int.random(in: min(2, cardIDs.count)...cardIDs.count, using: &rng)
            cardIDs.insert(id, at: insertAt)
        }

        generation += 1
    }

    /// "Gewusst!": the card leaves the deck. Returns the final rating to
    /// apply to SRS — .again if the card was ever failed this session.
    mutating func rateGood() -> SRSRating? {
        guard !cardIDs.isEmpty else { return nil }
        let id = cardIDs.removeFirst()
        mastered.insert(id)
        let final: SRSRating = repeatedIDs.contains(id) ? .again : .good
        results.append(final)
        generation += 1
        return final
    }
}
