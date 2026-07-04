import Testing
import Foundation
@testable import VocabSpark

/// Tests for the pure reminder-planning logic (Tester-Report 6:
/// no reminder on days the user already completed a session).
struct NotificationPlannerTests {

    private let calendar = Calendar.current

    /// A fixed "now": today 08:00 local time (reminder hour 17 is still ahead).
    private var now: Date {
        calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    }

    private func plan(dueDates: [Date], learnedToday: Bool, hour: Int = 17, now: Date? = nil) -> [Date] {
        NotificationService.plannedReminderDates(
            dueDates: dueDates,
            hasLearnedToday: learnedToday,
            hour: hour,
            minute: 0,
            horizonDays: 14,
            now: now ?? self.now,
            calendar: calendar
        )
    }

    @Test func keepsToday_whenNotLearnedYet() {
        let dueNow = [now.addingTimeInterval(-3600)]  // overdue since 07:00
        let dates = plan(dueDates: dueNow, learnedToday: false)
        #expect(!dates.isEmpty)
        #expect(calendar.isDate(dates[0], inSameDayAs: now))
    }

    @Test func skipsToday_whenAlreadyLearnedToday() {
        let dueNow = [now.addingTimeInterval(-3600)]
        let dates = plan(dueDates: dueNow, learnedToday: true)
        #expect(!dates.isEmpty, "future days with due cards must still be planned")
        #expect(!calendar.isDate(dates[0], inSameDayAs: now), "today must be skipped after a completed session")
        #expect(calendar.isDate(dates[0], inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now)!))
    }

    @Test func skipsDaysWithoutDueCards() {
        // Card due in 3 days → no reminder today/tomorrow, first on day 3.
        let dueInThreeDays = [calendar.date(byAdding: .day, value: 3, to: now)!]
        let dates = plan(dueDates: dueInThreeDays, learnedToday: false)
        #expect(!dates.isEmpty)
        #expect(calendar.isDate(dates[0], inSameDayAs: dueInThreeDays[0]))
    }

    @Test func skipsTodaysTrigger_whenTimeAlreadyPassed() {
        // now = 18:00, reminder hour 17 → today's trigger is in the past.
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        let dueNow = [evening.addingTimeInterval(-7200)]
        let dates = plan(dueDates: dueNow, learnedToday: false, now: evening)
        #expect(!dates.isEmpty)
        #expect(!calendar.isDate(dates[0], inSameDayAs: evening))
    }

    @Test func returnsEmpty_whenNothingDueInHorizon() {
        let dueFarAway = [calendar.date(byAdding: .day, value: 30, to: now)!]
        let dates = plan(dueDates: dueFarAway, learnedToday: false)
        #expect(dates.isEmpty)
    }

    @Test func triggerDates_carryReminderHourAndMinute() {
        let dueNow = [now.addingTimeInterval(-3600)]
        let dates = plan(dueDates: dueNow, learnedToday: false)
        for date in dates {
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            #expect(comps.hour == 17)
            #expect(comps.minute == 0)
        }
    }
}
