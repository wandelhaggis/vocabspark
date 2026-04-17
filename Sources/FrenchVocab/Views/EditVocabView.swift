import SwiftUI

struct EditVocabView: View {
    let item: VocabItem
    let deck: LanguageDeck
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var term: String
    @State private var translation: String
    @State private var selectedCategory: VocabCategory
    @State private var isLoadingExample = false

    @FocusState private var focusedField: Field?

    enum Field { case term, translation }

    init(item: VocabItem, deck: LanguageDeck) {
        self.item = item
        self.deck = deck
        _term = State(initialValue: item.term)
        _translation = State(initialValue: item.translation)
        _selectedCategory = State(initialValue: item.category)
    }

    var canSave: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty &&
        !translation.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasChanges: Bool {
        term.trimmingCharacters(in: .whitespaces) != item.term ||
        translation.trimmingCharacters(in: .whitespaces) != item.translation ||
        selectedCategory != item.category
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vokabel bearbeiten") {
                    HStack {
                        Text(deck.emoji)
                            .font(.title3)
                        TextField(deck.name, text: $term)
                            .focused($focusedField, equals: .term)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .onSubmit { focusedField = .translation }
                    }
                    HStack {
                        Text("\u{1F1E9}\u{1F1EA}")
                            .font(.title3)
                        TextField("Deutsch", text: $translation)
                            .focused($focusedField, equals: .translation)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { save() }
                    }
                }

                // Category picker
                Section {
                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(VocabCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Kategorie")
                } footer: {
                    // Fix #3: warn about SRS reset when manually changing category
                    if selectedCategory != item.category {
                        Label("Setzt den Lernfortschritt zur\u{FC}ck", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                // Example sentence (read-only)
                if let sentence = item.exampleSentence, let trans = item.exampleTranslation {
                    Section("Beispielsatz") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(deck.emoji) \u{AB}\(sentence)\u{BB}")
                                .font(.subheadline)
                            Text("\u{1F1E9}\u{1F1EA} \u{AB}\(trans)\u{BB}")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if ExampleSentenceService.shared.isAvailable {
                    Section("Beispielsatz") {
                        if isLoadingExample {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Wird geladen...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                loadExample()
                            } label: {
                                Label("Beispiel laden", systemImage: "sparkles")
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Speichern")
                        }
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave || !hasChanges)
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                focusedField = .term
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let wordsChanged = term.trimmingCharacters(in: .whitespaces) != item.term ||
                           translation.trimmingCharacters(in: .whitespaces) != item.translation
        item.term = term.trimmingCharacters(in: .whitespaces)
        item.translation = translation.trimmingCharacters(in: .whitespaces)
        if selectedCategory != item.category {
            let oldCategory = item.category
            item.applyCategory(selectedCategory)
            modelContext.insert(MasteryEvent(
                vocabItemID: item.id,
                from: oldCategory,
                to: selectedCategory,
                deck: deck
            ))
        }
        // Re-fetch example if words changed or none exists
        if wordsChanged {
            // Word changed — prefetch new TTS immediately, then refresh example + its TTS
            TTSService.shared.prefetch(item.term, language: deck.ttsLanguage)
            let language = deck.ttsLanguage
            let deckName = deck.name
            Task {
                await ExampleSentenceService.shared.refetchExample(for: item, languageName: deckName)
                if let example = item.exampleSentence {
                    TTSService.shared.prefetch(example, language: language)
                }
            }
        } else if item.exampleSentence == nil {
            let language = deck.ttsLanguage
            let deckName = deck.name
            Task {
                await ExampleSentenceService.shared.fetchExample(for: item, languageName: deckName)
                if let example = item.exampleSentence {
                    TTSService.shared.prefetch(example, language: language)
                }
            }
        }
        dismiss()
    }

    private func loadExample() {
        isLoadingExample = true
        let language = deck.ttsLanguage
        let deckName = deck.name
        Task {
            await ExampleSentenceService.shared.fetchExample(for: item, languageName: deckName)
            if let example = item.exampleSentence {
                TTSService.shared.prefetch(example, language: language)
            }
            isLoadingExample = false
        }
    }
}
