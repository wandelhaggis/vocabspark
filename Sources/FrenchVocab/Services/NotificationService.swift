import UserNotifications
import Foundation
import SwiftData

@MainActor
class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let dailyIDPrefix = "daily-reminder-"
    private let scheduleHorizonDays = 14

    /// Plan reminders for the next N days, but only on days where at least one
    /// vocab item will already be due by the reminder time. Asks for permission
    /// on first call and bails out silently if the user denies.
    func refreshReminderSchedule(hour: Int, minute: Int, modelContext: ModelContext) async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
        }
        let refreshed = await center.notificationSettings()
        guard refreshed.authorizationStatus != .denied else { return }

        await clearAllReminders()

        let descriptor = FetchDescriptor<VocabItem>()
        guard let items = try? modelContext.fetch(descriptor), !items.isEmpty else { return }
        let dueDates = items.map { $0.nextReviewDate }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        for offset in 0..<scheduleHorizonDays {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = hour
            components.minute = minute
            guard let triggerDate = calendar.date(from: components), triggerDate > now else { continue }

            let hasDue = dueDates.contains { $0 <= triggerDate }
            guard hasDue else { continue }

            scheduleReminder(at: triggerDate, components: components)
        }
    }

    func disableReminder() async {
        await clearAllReminders()
    }

    /// Returns true if notifications are authorized at the OS level.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    private func clearAllReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(dailyIDPrefix) }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func scheduleReminder(at date: Date, components: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Zeit zum Lernen! \u{1F4DA}", comment: "Daily reminder notification title")
        content.body = String(localized: "Deine Vokabeln warten. Nur 5 Minuten!", comment: "Daily reminder notification body")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = identifier(for: date)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    private func identifier(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return dailyIDPrefix + formatter.string(from: date)
    }
}
