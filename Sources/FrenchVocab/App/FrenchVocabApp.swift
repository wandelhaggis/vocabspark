import SwiftUI
import SwiftData

@main
struct VocabSparkApp: App {
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderHour") private var reminderHour = 17
    @AppStorage("dailyReminderMinute") private var reminderMinute = 0

    init() {
        // Fix #8: migrate any existing API key from UserDefaults to Keychain
        KeychainService.migrateFromUserDefaultsIfNeeded()
        // Fix #13: clean up TTS cache if it grew too large
        TTSService.cleanupCacheIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    if reminderEnabled {
                        await NotificationService.shared.enableReminder(hour: reminderHour, minute: reminderMinute)
                    }
                }
        }
        .modelContainer(for: [VocabItem.self, SessionRecord.self, LanguageDeck.self, MasteryEvent.self])
    }
}

struct RootView: View {
    @State private var selectedDeck: LanguageDeck?

    var body: some View {
        if let deck = selectedDeck {
            ContentView(deck: deck, onSwitchLanguage: { selectedDeck = nil })
        } else {
            LanguagePickerView(selectedDeck: $selectedDeck)
        }
    }
}
