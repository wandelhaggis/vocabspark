import SwiftUI
import SwiftData

struct CSVImportView: View {
    let result: CSVImportResult
    let deck: LanguageDeck
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var imported = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.indigo)

                Text("\(result.items.count) Vokabeln gefunden")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)

                if result.skippedLines > 0 {
                    Text("\(result.skippedLines) Zeilen \u{FC}bersprungen")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                // Preview
                List {
                    ForEach(Array(result.items.prefix(10).enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(entry.term)
                                .fontWeight(.medium)
                            Spacer()
                            Text(entry.translation)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if result.items.count > 10 {
                        Text("... und \(result.items.count - 10) weitere")
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                if imported {
                    Label("Importiert!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                        .padding(.bottom, 32)
                } else {
                    Button {
                        importAll()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Alle importieren")
                        }
                        .font(.headline)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(result.items.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("CSV Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey(imported ? "Fertig" : "Abbrechen")) { dismiss() }
                }
            }
        }
    }

    private func importAll() {
        let targetLang = deck.ttsLanguage
        let nativeLang = deck.nativeLanguageName
        var insertedItems: [VocabItem] = []

        for entry in result.items {
            let item = VocabItem(term: entry.term, translation: entry.translation, deck: deck)
            modelContext.insert(item)
            insertedItems.append(item)
            // Queue term-TTS prefetch immediately (serialized in TTSService)
            TTSService.shared.prefetch(item.term, language: targetLang)
        }

        // Background: fetch example sentences + prefetch their TTS sequentially
        // Serialized via ExampleSentenceService + TTSService internal queues.
        Task {
            for item in insertedItems {
                await ExampleSentenceService.shared.fetchExample(
                    for: item,
                    targetLanguage: targetLang,
                    nativeLanguage: nativeLang
                )
                if let example = item.exampleSentence {
                    TTSService.shared.prefetch(example, language: targetLang)
                }
            }
        }

        HapticService.success()
        imported = true
    }
}
