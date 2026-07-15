import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CloudKit

struct SettingsView: View {
    let deck: LanguageDeck

    @Environment(\.modelContext) private var modelContext

    // Fix #8: API key now stored in Keychain instead of UserDefaults
    @State private var storedKey: String = KeychainService.load() ?? ""
    @State private var keyInput = ""
    @State private var showSaved = false

    // iCloud sync visibility: a broken sync must never be silent
    @State private var iCloudAccountStatus: CKAccountStatus?

    // CSV Import
    @State private var showingFileImporter = false
    @State private var importResult: CSVImportResult?
    @State private var showingImport = false
    @State private var importError: String?

    var isConfigured: Bool { !storedKey.isEmpty }

    private var iCloudSyncActive: Bool {
        VocabSparkApp.isCloudKitSyncEnabled && iCloudAccountStatus == .available
    }

    private var iCloudSyncTitle: String {
        if !VocabSparkApp.isCloudKitSyncEnabled { return "iCloud-Sync inaktiv" }
        switch iCloudAccountStatus {
        case .available: return "iCloud-Sync aktiv"
        case .noAccount: return "Kein iCloud-Konto"
        case nil:        return "iCloud wird gepr\u{FC}ft \u{2026}"
        default:         return "iCloud nicht verf\u{FC}gbar"
        }
    }

    private var iCloudSyncDetail: String {
        if !VocabSparkApp.isCloudKitSyncEnabled {
            return "Deine Vokabeln werden nur auf diesem Ger\u{E4}t gespeichert"
        }
        switch iCloudAccountStatus {
        case .available: return "Deine Vokabeln werden automatisch in iCloud gesichert"
        case .noAccount: return "Melde dich in den iOS-Einstellungen bei iCloud an, damit deine Vokabeln gesichert werden"
        case nil:        return "Verbindung zu iCloud wird gepr\u{FC}ft"
        default:         return "Deine Vokabeln werden gerade nur auf diesem Ger\u{E4}t gespeichert"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status
                Section("Status") {
                    HStack {
                        Image(systemName: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(isConfigured ? .green : .orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(isConfigured ? "API-Key aktiv" : "API-Key fehlt"))
                                .fontWeight(.medium)
                            Text(LocalizedStringKey(isConfigured
                                 ? "Aussprache und Beispiels\u{E4}tze sind aktiv"
                                 : "Ohne Key keine Aussprache und Beispiels\u{E4}tze"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: iCloudSyncActive ? "icloud.fill" : "icloud.slash.fill")
                            .foregroundStyle(iCloudSyncActive ? .green : .orange)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(iCloudSyncTitle))
                                .fontWeight(.medium)
                            Text(LocalizedStringKey(iCloudSyncDetail))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task {
                        iCloudAccountStatus = try? await CKContainer(
                            identifier: VocabSparkApp.cloudKitContainerID
                        ).accountStatus()
                    }
                }

                // Key input
                Section {
                    TextField("sk-proj-...", text: $keyInput)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                            keyInput = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                            HapticService.light()
                        }
                    } label: {
                        Label("Aus Zwischenablage einf\u{FC}gen", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        KeychainService.save(trimmed)
                        storedKey = trimmed
                        showSaved = true
                        HapticService.success()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Speichern")
                        }
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if showSaved {
                        Label("Gespeichert!", systemImage: "checkmark")
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    }

                    if isConfigured {
                        Button(role: .destructive) {
                            KeychainService.delete()
                            storedKey = ""
                            keyInput = ""
                            showSaved = false
                        } label: {
                            Label("Key entfernen", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("OpenAI API-Key")
                } footer: {
                    Text("Hol dir einen Key unter platform.openai.com/api-keys\nDer Key bleibt nur auf diesem Ger\u{E4}t gespeichert.")
                }
                // Daily reminder
                Section {
                    Toggle(isOn: $reminderEnabled) {
                        Text("T\u{E4}gliche Erinnerung")
                            .fontWeight(.medium)
                    }
                    .tint(.indigo)
                    .onChange(of: reminderEnabled) { _, enabled in
                        Task {
                            if enabled {
                                await NotificationService.shared.refreshReminderSchedule(
                                    hour: reminderHour,
                                    minute: reminderMinute,
                                    modelContext: modelContext
                                )
                                let authorized = await NotificationService.shared.isAuthorized()
                                if !authorized {
                                    reminderEnabled = false
                                }
                            } else {
                                await NotificationService.shared.disableReminder()
                            }
                        }
                    }

                    if reminderEnabled {
                        DatePicker(
                            "Uhrzeit",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderHour) { _, _ in rescheduleReminder() }
                        .onChange(of: reminderMinute) { _, _ in rescheduleReminder() }
                    }
                } header: {
                    Text("Erinnerung")
                } footer: {
                    Text("Du bekommst zur gew\u{E4}hlten Uhrzeit nur dann eine Erinnerung, wenn Vokabeln zum Lernen f\u{E4}llig sind.")
                }

                // CSV Import
                Section {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Vokabelliste importieren", systemImage: "doc.badge.plus")
                    }
                    if let error = importError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Import f\u{FC}r \(deck.emoji) \(deck.displayName)")
                } footer: {
                    Text("Importiere eine CSV-/TXT-Datei mit \(deck.displayName);\(deck.nativeDisplayName) pro Zeile.")
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                keyInput = storedKey
            }
            .sheet(isPresented: $showingImport) {
                if let importResult {
                    CSVImportView(result: importResult, deck: deck)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .tabSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                importError = nil
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = String(localized: "Datei konnte nicht gelesen werden")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        importResult = try CSVImportService.parse(data: data)
                        showingImport = true
                    } catch {
                        importError = String(localized: "Datei konnte nicht verarbeitet werden")
                    }
                case .failure:
                    importError = String(localized: "Import abgebrochen")
                }
            }
        }
    }

    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderHour") private var reminderHour = 17
    @AppStorage("dailyReminderMinute") private var reminderMinute = 0

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = components.hour ?? 17
                reminderMinute = components.minute ?? 0
            }
        )
    }

    private func rescheduleReminder() {
        guard reminderEnabled else { return }
        Task {
            await NotificationService.shared.refreshReminderSchedule(
                hour: reminderHour,
                minute: reminderMinute,
                modelContext: modelContext
            )
        }
    }
}
