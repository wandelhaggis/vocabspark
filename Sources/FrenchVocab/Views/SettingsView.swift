import SwiftUI

struct SettingsView: View {
    @AppStorage("openai_api_key") private var storedKey = ""
    @State private var keyInput = ""
    @State private var showSaved = false

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
                        storedKey = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("T\u{E4}gliche Erinnerung")
                                .fontWeight(.medium)
                            Text("Jeden Tag um 17:00 Uhr")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.indigo)
                    .onChange(of: reminderEnabled) { _, enabled in
                        Task {
                            if enabled {
                                await NotificationService.shared.enableReminder()
                                // Check if permission was actually granted
                                let authorized = await NotificationService.shared.isAuthorized()
                                if !authorized {
                                    reminderEnabled = false
                                }
                            } else {
                                NotificationService.shared.disableReminder()
                            }
                        }
                    }
                } header: {
                    Text("Erinnerung")
                } footer: {
                    Text("Du bekommst eine Benachrichtigung, wenn du heute noch nicht gelernt hast.")
                }
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                keyInput = storedKey
            }
        }
    }

    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
}
