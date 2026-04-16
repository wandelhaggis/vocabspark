import SwiftUI
import SwiftData

@main
struct VocabSparkApp: App {
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    if reminderEnabled {
                        await NotificationService.shared.enableReminder()
                    }
                }
        }
        .modelContainer(for: [VocabItem.self, SessionRecord.self, LanguageDeck.self])
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
