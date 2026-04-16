import SwiftUI
import SwiftData

struct LanguagePickerView: View {
    @Query(sort: \LanguageDeck.createdAt) private var decks: [LanguageDeck]
    @Query private var allItems: [VocabItem]
    @Binding var selectedDeck: LanguageDeck?
    @State private var showingAddLanguage = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("\u{1F4DA}")
                    .font(.system(size: 60))
                Text("Was m\u{F6}chtest du\nheute lernen?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }

            if decks.isEmpty {
                Text("F\u{FC}ge eine Sprache hinzu, um loszulegen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(decks) { deck in
                        let deckItems = allItems.filter { $0.deck?.id == deck.id }
                        let knownCount = deckItems.filter { $0.category == .bekannt }.count
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedDeck = deck
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(deck.emoji)
                                    .font(.system(size: 44))
                                Text(deck.name)
                                    .font(.headline)
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.primary)
                                if !deckItems.isEmpty {
                                    Text("\(deckItems.count) W\u{F6}rter \u{B7} \(knownCount) gelernt")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Button {
                showingAddLanguage = true
            } label: {
                Label("Sprache hinzuf\u{FC}gen", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .sheet(isPresented: $showingAddLanguage) {
            AddLanguageView { newDeck in
                selectedDeck = newDeck
            }
        }
    }
}
