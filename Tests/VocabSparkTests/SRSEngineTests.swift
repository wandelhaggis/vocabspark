import Testing
import Foundation
@testable import VocabSpark

/// Characterization tests: they pin down the EXISTING SRSEngine behavior
/// (written against already-working code, not TDD). Verified once against
/// a deliberate mutation to prove they measure what they claim.
struct SRSEngineTests {

    private func makeItem() -> VocabItem {
        VocabItem(term: "bonjour", translation: "hallo")
    }

    // MARK: - .good progression

    @Test func applyGood_firstReview_setsIntervalToOneDay() {
        let item = makeItem()
        SRSEngine.apply(rating: .good, to: item)
        #expect(item.interval == 1)
        #expect(item.repetitions == 1)
    }

    @Test func applyGood_secondReview_setsIntervalToFourDays() {
        let item = makeItem()
        SRSEngine.apply(rating: .good, to: item)
        SRSEngine.apply(rating: .good, to: item)
        #expect(item.interval == 4)
        #expect(item.repetitions == 2)
    }

    @Test func applyGood_thirdReview_multipliesIntervalByEaseFactor() {
        let item = makeItem()
        SRSEngine.apply(rating: .good, to: item)   // interval 1, ease 2.6
        SRSEngine.apply(rating: .good, to: item)   // interval 4, ease 2.7
        SRSEngine.apply(rating: .good, to: item)   // multiplies BEFORE ease bump: 4 * 2.7 = 10
        #expect(item.interval == Int(4 * 2.7))
    }

    @Test func applyGood_increasesEaseFactor() {
        let item = makeItem()
        SRSEngine.apply(rating: .good, to: item)
        #expect(item.easeFactor == 2.6)
    }

    // MARK: - .again reset (the lapse semantics the 2-button system relies on)

    @Test func applyAgain_onMatureCard_resetsIntervalToOneDay() {
        let item = makeItem()
        item.interval = 30
        item.repetitions = 5
        SRSEngine.apply(rating: .again, to: item)
        #expect(item.interval == 1)
        #expect(item.repetitions == 0)
    }

    @Test func applyAgain_reducesEaseFactorButNotBelowFloor() {
        let item = makeItem()
        item.easeFactor = 1.4
        SRSEngine.apply(rating: .again, to: item)
        #expect(item.easeFactor == 1.3)
    }

    @Test func apply_setsNextReviewDateToStartOfDay() {
        let item = makeItem()
        SRSEngine.apply(rating: .good, to: item)
        let startOfDue = Calendar.current.startOfDay(for: item.nextReviewDate)
        #expect(item.nextReviewDate == startOfDue)
    }

    @Test func apply_marksItemAsReviewed() {
        let item = makeItem()
        #expect(item.lastReviewedAt == nil)
        SRSEngine.apply(rating: .again, to: item)
        #expect(item.lastReviewedAt != nil)
    }
}
