import SwiftUI
import SwiftData

struct AddVocabView: View {
    let deck: LanguageDeck

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var term = ""
    @State private var translation = ""
    @State private var savedCount = 0
    @State private var isTranslating = false
    @State private var showUnsavedAlert = false

    private var hasUnsavedInput: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty ||
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @FocusState private var focusedField: Field?

    enum Field { case term, translation }

    var canSave: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Show translate button in the term field when translation has text but term is empty
    var canTranslateToTerm: Bool {
        term.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Show translate button in the translation field when term has text but translation is empty
    var canTranslateToTranslation: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty &&
        translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Foreign language field
                    HStack {
                        Text(deck.emoji)
                            .font(.title3)
                        TextField(deck.name, text: $term)
                            .focused($focusedField, equals: .term)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .onSubmit { focusedField = .translation }
                        if canTranslateToTerm && !isTranslating {
                            Button {
                                translateField(fromForeign: false)
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                    .foregroundStyle(.indigo)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // German field
                    HStack {
                        Text("\u{1F1E9}\u{1F1EA}")
                            .font(.title3)
                        TextField("Deutsch", text: $translation)
                            .focused($focusedField, equals: .translation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { saveAndClear() }
                        if canTranslateToTranslation && !isTranslating {
                            Button {
                                translateField(fromForeign: true)
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                    .foregroundStyle(.indigo)
                            }
                            .buttonStyle(.plain)
                        }
                        if isTranslating {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Neue Vokabel")
                } footer: {
                    if savedCount > 0 {
                        Label(
                            "\(savedCount) Vokabel\(savedCount == 1 ? "" : "n") gespeichert",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                    }
                }

                Section {
                    Button {
                        saveAndClear()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Speichern & n\u{E4}chste")
                        }
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Vokabel hinzuf\u{FC}gen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        // Fix #15: warn before discarding half-typed vocab
                        if hasUnsavedInput {
                            showUnsavedAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Nicht gespeicherte Eingabe?", isPresented: $showUnsavedAlert) {
                Button("Verwerfen", role: .destructive) { dismiss() }
                Button("Zur\u{FC}ck", role: .cancel) { }
            } message: {
                Text("Die aktuell eingegebene Vokabel wird nicht gespeichert.")
            }
            .onAppear {
                focusedField = .term
            }
        }
    }

    /// Kick off background work for a newly added item:
    /// 1. Prefetch TTS for the term (parallel, cheap)
    /// 2. Fetch example sentence
    /// 3. Once example is ready, prefetch its TTS too
    private func prefetchAudioAndExample(for item: VocabItem) {
        let language = deck.ttsLanguage
        let deckName = deck.name
        // Start term-TTS download immediately
        TTSService.shared.prefetch(item.term, language: language)
        // Example sentence + its TTS run sequentially in the background
        Task {
            await ExampleSentenceService.shared.fetchExample(for: item, languageName: deckName)
            if let example = item.exampleSentence {
                TTSService.shared.prefetch(example, language: language)
            }
        }
    }

    private func translateField(fromForeign: Bool) {
        let sourceText = fromForeign ? term : translation
        guard !sourceText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isTranslating = true
        Task {
            if let result = await ExampleSentenceService.shared.translate(
                word: sourceText,
                languageName: deck.name,
                fromForeign: fromForeign
            ) {
                if fromForeign {
                    translation = result
                } else {
                    term = result
                }
                HapticService.light()
            }
            isTranslating = false
        }
    }

    private func saveAndClear() {
        guard canSave else { return }
        let item = VocabItem(
            term: term.trimmingCharacters(in: .whitespaces),
            translation: translation.trimmingCharacters(in: .whitespaces),
            deck: deck
        )
        modelContext.insert(item)
        prefetchAudioAndExample(for: item)
        HapticService.light()
        savedCount += 1
        term = ""
        translation = ""
        focusedField = .term
    }
}
