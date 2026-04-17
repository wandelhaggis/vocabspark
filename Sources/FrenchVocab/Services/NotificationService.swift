import UserNotifications
import Foundation

@MainActor
class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let dailyID = "daily-reminder"

    /// Enable reminder at the given time. Also used to re-schedule after time changes.
    func enableReminder(hour: Int, minute: Int) async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
        }
        let refreshed = await center.notificationSettings()
        guard refreshed.authorizationStatus != .denied else { return }
        scheduleDailyReminder(hour: hour, minute: minute)
    }

    func disableReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
    }

    /// Returns true if notifications are authorized at the OS level.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    private func scheduleDailyReminder(hour: Int, minute: Int) {
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])

        let content = UNMutableNotificationContent()
        content.title = "Zeit zum Lernen! \u{1F4DA}"
        content.body = "Deine Vokabeln warten. Nur 5 Minuten!"
        content.sound = .default

        var when = DateComponents()
        when.hour = hour
        when.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
        center.add(request)
    }
}
