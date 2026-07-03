import SwiftUI
import SwiftData

@main
struct VocabSparkApp: App {
    init() {
        // Fix #8: migrate any existing API key from UserDefaults to Keychain
        KeychainService.migrateFromUserDefaultsIfNeeded()
        // Fix #13: clean up TTS cache if it grew too large
        TTSService.cleanupCacheIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [VocabItem.self, SessionRecord.self, LanguageDeck.self, MasteryEvent.self])
    }
}

struct RootView: View {
    @State private var selectedDeck: LanguageDeck?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderHour") private var reminderHour = 17
    @AppStorage("dailyReminderMinute") private var reminderMinute = 0

    var body: some View {
        Group {
            if let deck = selectedDeck {
                ContentView(deck: deck, onSwitchLanguage: { selectedDeck = nil })
            } else {
                LanguagePickerView(selectedDeck: $selectedDeck)
            }
        }
        .task {
            if reminderEnabled {
                await NotificationService.shared.refreshReminderSchedule(
                    hour: reminderHour,
                    minute: reminderMinute,
                    modelContext: modelContext
                )
            }
        }
    }
}
