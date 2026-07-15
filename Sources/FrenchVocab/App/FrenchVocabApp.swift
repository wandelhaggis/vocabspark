import SwiftUI
import SwiftData
import CoreData

@main
struct VocabSparkApp: App {
    static let cloudKitContainerID = "iCloud.com.michikoenig.vocabspark"

    /// False when the container fell back to the local-only store.
    /// Surfaced in Settings so a broken sync is never silent.
    static private(set) var isCloudKitSyncEnabled = false

    /// CloudKit-synced container: data lives in the user's private iCloud
    /// database and survives app reinstall / device wipe. Falls back to a
    /// local-only store if the CloudKit configuration cannot be loaded
    /// (e.g. missing entitlement) so the app never crashes over sync setup.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([VocabItem.self, SessionRecord.self, LanguageDeck.self, MasteryEvent.self])
        do {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            let container = try ModelContainer(for: schema, configurations: [cloudConfig])
            isCloudKitSyncEnabled = true
            return container
        } catch {
            print("⚠️ CloudKit ModelContainer failed (\(error)) — falling back to local-only store")
            do {
                let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

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
        .modelContainer(Self.sharedModelContainer)
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
            // Merge duplicates a previous CloudKit sync may have left behind.
            DeckDeduplicator.deduplicate(in: modelContext)
            if reminderEnabled {
                await NotificationService.shared.refreshReminderSchedule(
                    hour: reminderHour,
                    minute: reminderMinute,
                    modelContext: modelContext
                )
            }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                .receive(on: DispatchQueue.main)
        ) { note in
            // After every finished iCloud import: merge duplicates that the
            // sync produced (CloudKit cannot enforce uniqueness).
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .import, event.endDate != nil, event.succeeded else { return }
            if DeckDeduplicator.deduplicate(in: modelContext),
               let deck = selectedDeck, deck.isDeleted {
                // The open deck was merged into another one — back to the picker.
                selectedDeck = nil
            }
        }
    }
}
