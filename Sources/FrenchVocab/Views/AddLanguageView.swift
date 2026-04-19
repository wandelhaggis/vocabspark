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
                VStack(spacing: 24) {
                    Text("Welche Sprache m\u{F6}chtest du lernen?")
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .padding(.top)

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
                                        .lineLimit(1)
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

                    Divider()
                        .padding(.horizontal, 40)

                    // Native language picker
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
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Sprache w\u{E4}hlen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func createDeck(_ lang: LanguageOption) {
        let deck = LanguageDeck(
            name: lang.name,
            emoji: lang.emoji,
            ttsLanguage: lang.ttsLanguage,
            nativeLanguageCode: nativeCode
        )
        modelContext.insert(deck)
        HapticService.success()
        dismiss()
        onCreated(deck)
    }
}
