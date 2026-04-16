import SwiftUI
import SwiftData

struct AddLanguageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onCreated: (LanguageDeck) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Welche Sprache m\u{F6}chtest du lernen?")
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .padding(.top)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(predefinedLanguages) { lang in
                            Button {
                                createDeck(lang)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(lang.emoji)
                                        .font(.system(size: 36))
                                    Text(lang.name)
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
                        }
                    }
                    .padding(.horizontal)
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
        let deck = LanguageDeck(name: lang.name, emoji: lang.emoji, ttsLanguage: lang.ttsLanguage)
        modelContext.insert(deck)
        HapticService.success()
        dismiss()
        onCreated(deck)
    }
}
