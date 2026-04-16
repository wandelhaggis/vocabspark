import Foundation

/// Simplified SM-2 algorithm with 3 rating levels.
/// Rating:
///   0 = Nochmal (failed)
///   1 = Fast (hesitant)
///   2 = Gewusst (confident)
enum SRSRating: Int {
    case again = 0
    case hard = 1
    case good = 2
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

        case .hard:
            // Progresses but slowly
            if item.repetitions == 0 {
                item.interval = 1
            } else if item.repetitions == 1 {
                item.interval = 3
            } else {
                item.interval = max(1, Int(Double(item.interval) * 1.2))
            }
            item.easeFactor = max(1.3, item.easeFactor - 0.15)
            item.repetitions += 1

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

        item.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: item.interval,
            to: now
        ) ?? now.addingTimeInterval(86400)
    }
}
