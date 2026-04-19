import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let deck: LanguageDeck

    // Fix #8: API key now stored in Keychain instead of UserDefaults
    @State private var storedKey: String = KeychainService.load() ?? ""
    @State private var keyInput = ""
    @State private var showSaved = false

    // CSV Import
    @State private var showingFileImporter = false
    @State private var importResult: CSVImportResult?
    @State private var showingImport = false
    @State private var importError: String?

    var isConfigured: Bool { !storedKey.isEmpty }

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
                            Text(isConfigured ? "API-Key aktiv" : "API-Key fehlt")
                                .fontWeight(.medium)
                            Text(isConfigured
                                 ? "Aussprache und Beispiels\u{E4}tze sind aktiv"
                                 : "Ohne Key keine Aussprache und Beispiels\u{E4}tze")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                                await NotificationService.shared.enableReminder(hour: reminderHour, minute: reminderMinute)
                                let authorized = await NotificationService.shared.isAuthorized()
                                if !authorized {
                                    reminderEnabled = false
                                }
                            } else {
                                NotificationService.shared.disableReminder()
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
                    Text("Du bekommst jeden Tag zur gew\u{E4}hlten Uhrzeit eine Erinnerung.")
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
                    Text("Import f\u{FC}r \(deck.emoji) \(deck.name)")
                } footer: {
                    Text("Importiere eine CSV-/TXT-Datei mit \(deck.name);\(deck.nativeDisplayName) pro Zeile.")
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
                        importError = "Datei konnte nicht gelesen werden"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        importResult = try CSVImportService.parse(data: data)
                        showingImport = true
                    } catch {
                        importError = "Datei konnte nicht verarbeitet werden"
                    }
                case .failure:
                    importError = "Import abgebrochen"
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
            await NotificationService.shared.enableReminder(hour: reminderHour, minute: reminderMinute)
        }
    }
}
