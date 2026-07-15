import SwiftUI
import SwiftData

struct AddLanguageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onCreated: (LanguageDeck) -> Void

    /// Native language defaults to the device locale, falls back to German.
    @State private var nativeCode: String = LanguageCatalog.defaultNativeLanguageCode

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Native language picker — on top so it's always visible and
                    // signals "set your own language first, then pick the target".
                    HStack {
                        Text("Meine Sprache")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Meine Sprache", selection: $nativeCode) {
                            ForEach(LanguageCatalog.nativeCapableLanguages, id: \.code) { lang in
                                Text("\(lang.emoji) \(lang.localizedName)").tag(lang.code)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Divider()
                        .padding(.horizontal, 40)

                    Text("Welche Sprache m\u{F6}chtest du lernen?")
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)

                    // Target language grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(predefinedLanguages) { lang in
                            Button {
                                createDeck(lang)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(lang.emoji)
                                        .font(.system(size: 36))
                                    Text(lang.localizedName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.75)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            // Users shouldn't target a deck in their own native language
                            .disabled(lang.code == nativeCode)
                            .opacity(lang.code == nativeCode ? 0.35 : 1)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Sprache w\u{E4}hlen")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func createDeck(_ lang: LanguageOption) {
        // CloudKit cannot enforce uniqueness — reuse an existing deck of the
        // same language pair instead of inserting a duplicate (e.g. when the
        // iCloud import after a reinstall hasn't finished yet).
        let tts = lang.ttsLanguage
        let native = nativeCode
        let descriptor = FetchDescriptor<LanguageDeck>(
            predicate: #Predicate { $0.ttsLanguage == tts && $0.nativeLanguageCode == native }
        )
        let deck: LanguageDeck
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            deck = existing
        } else {
            deck = LanguageDeck(
                name: lang.name,
                emoji: lang.emoji,
                ttsLanguage: lang.ttsLanguage,
                nativeLanguageCode: nativeCode
            )
            modelContext.insert(deck)
        }
        HapticService.success()
        dismiss()
        onCreated(deck)
    }
}
