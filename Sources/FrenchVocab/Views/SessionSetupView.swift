import SwiftUI
import SwiftData

enum LearningDirection: String, CaseIterable {
    case frToDE = "fr→de"
    case deToFR = "de→fr"
    case random = "Zufall"

    var icon: String {
        switch self {
        case .frToDE: return "\u{27A1}\u{FE0F} Abfragen"
        case .deToFR: return "\u{2B05}\u{FE0F} \u{DC}bersetzen"
        case .random: return "\u{1F500} Zufall"
        }
    }
}

enum SessionFilter: String, CaseIterable {
    case dueOnly = "F\u{E4}llige"
    case all = "Alle"
}

struct SessionSetupView: View {
    let deck: LanguageDeck

    @Query private var allItems: [VocabItem]
    @Query(sort: \SessionRecord.date, order: .reverse) private var allSessions: [SessionRecord]
    @ObservedObject private var streakManager = StreakManager.shared

    @State private var direction: LearningDirection = .frToDE
    @State private var filter: SessionFilter = .dueOnly
    @State private var isLearning = false

    /// Items belonging to the current deck.
    var deckItems: [VocabItem] { allItems.filter { $0.deck?.id == deck.id } }

    var dueItems: [VocabItem] { deckItems.filter { $0.isDue } }
    var sessionItems: [VocabItem] { filter == .dueOnly ? dueItems : deckItems }

    var weekSessions: [SessionRecord] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allSessions.filter { $0.date >= weekAgo }
    }

    var weekSuccessRate: Int {
        let sessions = weekSessions
        guard !sessions.isEmpty else { return 0 }
        let totalGood = sessions.reduce(0) { $0 + $1.goodCount }
        let totalCards = sessions.reduce(0) { $0 + $1.totalCards }
        guard totalCards > 0 else { return 0 }
        return Int(Double(totalGood) / Double(totalCards) * 100)
    }

    var body: some View {
        NavigationStack {
            if deckItems.isEmpty {
                emptyLernenState
            } else {
                lernenContent
            }
        }
    }

    @ViewBuilder
    private var emptyLernenState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.indigo.opacity(0.4))
            Text("Noch nichts zum Lernen")
                .font(.title2)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            Text("F\u{FC}ge zuerst Vokabeln im Tab\n\u{AB}Vokabeln\u{BB} hinzu!")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle("Lernsession")
    }

    @ViewBuilder
    private var lernenContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Streak
                if streakManager.currentStreak > 0 {
                    streakBanner
                }

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(value: deckItems.count, label: "Gesamt", icon: "books.vertical.fill", color: .indigo)
                        StatCard(value: dueItems.count, label: "F\u{E4}llig", icon: "clock.fill", color: .orange)
                        if !weekSessions.isEmpty {
                            StatCard(value: weekSessions.count, label: "Diese Woche", icon: "flame.fill", color: .purple)
                            StatCard(value: weekSuccessRate, label: "% Gewusst", icon: "star.fill", color: .green)
                        }
                    }
                    .padding(.horizontal)

                    // Direction picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Richtung")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .padding(.horizontal)

                        HStack(spacing: 10) {
                            ForEach(LearningDirection.allCases, id: \.self) { dir in
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        direction = dir
                                    }
                                } label: {
                                    Text(dir.icon)
                                        .font(.subheadline)
                                        .fontWeight(direction == dir ? .bold : .regular)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(direction == dir ? Color.indigo : Color(.systemGray5))
                                        .foregroundStyle(direction == dir ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Filter picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Karten")
                            .font(.headline)
                            .fontDesign(.rounded)
                            .padding(.horizontal)

                        Picker("Karten", selection: $filter) {
                            ForEach(SessionFilter.allCases, id: \.self) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    // Start button
                    Button {
                        isLearning = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("Los geht's! (\(sessionItems.count) Karten)")
                        }
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background {
                            if sessionItems.isEmpty {
                                Color.gray
                            } else {
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: sessionItems.isEmpty ? .clear : .indigo.opacity(0.4), radius: 8, y: 4)
                    }
                    .disabled(sessionItems.isEmpty)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lernsession")
            .fullScreenCover(isPresented: $isLearning) {
                LearningSessionView(
                    items: sessionItems.shuffled(),
                    direction: direction,
                    deck: deck
                )
            }
            .onAppear {
                streakManager.refreshStreak()
            }
    }

    // MARK: - Streak Banner

    @ViewBuilder
    private var streakBanner: some View {
        HStack(spacing: 14) {
            Text("\u{1F525}")
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakManager.currentStreak) Tage")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(streakManager.currentStreak >= streakManager.longestStreak
                     ? "Bester Streak! \u{1F4AA}" : "Streak")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.15), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
