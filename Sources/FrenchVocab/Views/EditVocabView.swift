import SwiftUI

struct EditVocabView: View {
    let item: VocabItem
    let deck: LanguageDeck
    @Environment(\.dismiss) private var dismiss

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
                            .submitLabel(.next)
                            .onSubmit { focusedField = .translation }
                    }
                    HStack {
                        Text("\u{1F1E9}\u{1F1EA}")
                            .font(.title3)
                        TextField("Deutsch", text: $translation)
                            .focused($focusedField, equals: .translation)
                            .submitLabel(.done)
                            .onSubmit { save() }
                    }
                }

                // Category picker
                Section("Kategorie") {
                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(VocabCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
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
            item.applyCategory(selectedCategory)
        }
        // Re-fetch example if words changed or none exists
        if wordsChanged || item.exampleSentence == nil {
            Task { await ExampleSentenceService.shared.refetchExample(for: item, languageName: deck.name) }
        }
        dismiss()
    }

    private func loadExample() {
        isLoadingExample = true
        Task {
            await ExampleSentenceService.shared.fetchExample(for: item, languageName: deck.name)
            isLoadingExample = false
        }
    }
}
