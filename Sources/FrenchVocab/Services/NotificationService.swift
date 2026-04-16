import UserNotifications

@MainActor
class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let dailyID = "daily-reminder"

    func enableReminder() async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
        }
        guard settings.authorizationStatus != .denied else { return }
        scheduleDailyReminder()
    }

    func disableReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
    }

    /// Returns true if notifications are authorized at the OS level.
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    private func scheduleDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])

        let content = UNMutableNotificationContent()
        content.title = "Zeit zum Lernen! \u{1F1EB}\u{1F1F7}"
        content.body = "Deine Vokabeln warten. Nur 5 Minuten!"
        content.sound = .default

        var when = DateComponents()
        when.hour = 17
        when.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
        center.add(request)
    }
}
