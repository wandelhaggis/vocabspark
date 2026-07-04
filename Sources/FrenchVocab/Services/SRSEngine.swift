import Foundation

/// Simplified SM-2 algorithm with 2 rating levels.
/// Rating:
///   .again = Nochmal (failed → reset, due tomorrow)
///   .good  = Gewusst (confident → normal progression)
enum SRSRating {
    case again
    case good
}

struct SRSEngine {

    static func apply(rating: SRSRating, to item: VocabItem) {
        let now = Date()
        item.lastReviewedAt = now

        switch rating {
        case .again:
            // Reset — review tomorrow
            item.repetitions = 0
            item.interval = 1
            item.easeFactor = max(1.3, item.easeFactor - 0.2)

        case .good:
            // Standard SM-2 progression
            if item.repetitions == 0 {
                item.interval = 1
            } else if item.repetitions == 1 {
                item.interval = 4
            } else {
                item.interval = Int(Double(item.interval) * item.easeFactor)
            }
            item.easeFactor = max(1.3, item.easeFactor + 0.1)
            item.repetitions += 1
        }

        // Fix #7: normalize to start-of-day so cards are due "on day X", not "at time X"
        let targetDate = Calendar.current.date(
            byAdding: .day,
            value: item.interval,
            to: now
        ) ?? now.addingTimeInterval(86400)
        item.nextReviewDate = Calendar.current.startOfDay(for: targetDate)
    }
}
