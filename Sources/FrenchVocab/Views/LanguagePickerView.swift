import SwiftUI
import SwiftData

struct LanguagePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LanguageDeck.createdAt) private var decks: [LanguageDeck]
    @Binding var selectedDeck: LanguageDeck?
    @State private var showingAddLanguage = false
    @State private var deckToDelete: LanguageDeck?

    // Fix #12: count cache to avoid loading all items on every render
    @State private var deckStats: [UUID: (total: Int, known: Int)] = [:]

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
                        deckCard(for: deck)
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
        .confirmationDialog(
            deckToDelete.map {
                String(format: String(localized: "%@ l\u{F6}schen?"), $0.displayName)
            } ?? "",
            isPresented: Binding(
                get: { deckToDelete != nil },
                set: { if !$0 { deckToDelete = nil } }
            ),
            presenting: deckToDelete
        ) { deck in
            Button("L\u{F6}schen", role: .destructive) {
                deleteDeck(deck)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: { deck in
            let count = deckStats[deck.id]?.total ?? 0
            if count > 0 {
                Text("Alle \(count) Vokabeln werden mitgel\u{F6}scht.")
            } else {
                Text("Diese Sprache wird entfernt.")
            }
        }
        .onAppear { refreshStats() }
    }

    // MARK: - Deck Card

    @ViewBuilder
    private func deckCard(for deck: LanguageDeck) -> some View {
        let stats = deckStats[deck.id] ?? (0, 0)
        Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedDeck = deck
            }
        } label: {
            VStack(spacing: 6) {
                Text(deck.emoji)
                    .font(.system(size: 44))
                Text(deck.displayName)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                if stats.total > 0 {
                    Text("\(stats.total) W\u{F6}rter \u{B7} \(stats.known) gelernt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .contextMenu {
            Button(role: .destructive) {
                deckToDelete = deck
            } label: {
                Label("L\u{F6}schen", systemImage: "trash")
            }
        }
    }

    // MARK: - Logic

    private func refreshStats() {
        var stats: [UUID: (total: Int, known: Int)] = [:]
        for deck in decks {
            let deckID = deck.id
            let totalDescriptor = FetchDescriptor<VocabItem>(
                predicate: #Predicate { $0.deck?.id == deckID }
            )
            let total = (try? modelContext.fetchCount(totalDescriptor)) ?? 0

            // For "known" count we still need the items because category is computed
            let items = (try? modelContext.fetch(totalDescriptor)) ?? []
            let known = items.filter { $0.category == .bekannt }.count

            stats[deckID] = (total, known)
        }
        deckStats = stats
    }

    private func deleteDeck(_ deck: LanguageDeck) {
        // Cascade: delete all vocab items of this deck
        let deckID = deck.id
        let descriptor = FetchDescriptor<VocabItem>(
            predicate: #Predicate { $0.deck?.id == deckID }
        )
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                modelContext.delete(item)
            }
        }
        modelContext.delete(deck)
        HapticService.success()
        refreshStats()
    }
}
