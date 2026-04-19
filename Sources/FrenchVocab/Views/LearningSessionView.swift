import SwiftUI
import StoreKit

struct LearningSessionView: View {
    let items: [VocabItem]
    let direction: LearningDirection
    let deck: LanguageDeck

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSize
    @ObservedObject private var tts = TTSService.shared
    @ObservedObject private var streakManager = StreakManager.shared

    // Fix #6: adaptive sizing for iPhone (compact) vs iPad (regular)
    private var promptFontSize: CGFloat { hSize == .compact ? 28 : 34 }
    private var answerFontSize: CGFloat { hSize == .compact ? 24 : 30 }
    private var cardPadding: CGFloat { hSize == .compact ? 20 : 32 }

    // Deck-based: cards cycle until all rated .good
    @State private var cardDeck: [VocabItem]
    @State private var mastered: Set<UUID> = []
    @State private var isRevealed = false
    @State private var sessionResults: [SRSRating] = []
    /// Worst rating per card in this session — used for final SRS update.
    @State private var cardWorstRating: [UUID: SRSRating] = [:]
    /// Fix #1: lock to prevent double-rate during the success flash animation.
    @State private var isAdvancing = false
    /// Fix #19: hold the flash-advance task so we can cancel on dismiss.
    @State private var advanceTask: Task<Void, Never>?
    /// Total completed sessions — used to throttle review prompt.
    @AppStorage("completedSessionCount") private var completedSessionCount = 0
    /// Fix #4: prevent saveSession from running twice.
    @State private var sessionSaved = false
    @State private var showingSummary = false
    @State private var resolvedDirection: LearningDirection = .frToDE
    @State private var ttsTask: Task<Void, Never>?
    @State private var showSuccessFlash = false
    @FocusState private var isFocused: Bool

    let totalCount: Int

    init(items: [VocabItem], direction: LearningDirection, deck: LanguageDeck) {
        self.items = items
        self.direction = direction
        self.deck = deck
        self.totalCount = items.count
        _cardDeck = State(initialValue: items)
    }

    var current: VocabItem? {
        cardDeck.first
    }

    var promptText: String {
        guard let item = current else { return "" }
        return isTermPrompt ? item.term : item.translation
    }

    var answerText: String {
        guard let item = current else { return "" }
        return isTermPrompt ? item.translation : item.term
    }

    var isTermPrompt: Bool { resolvedDirection == .frToDE }

    var promptExample: String? {
        guard let item = current else { return nil }
        return isTermPrompt ? item.exampleSentence : item.exampleTranslation
    }

    var answerExample: String? {
        guard let item = current else { return nil }
        return isTermPrompt ? item.exampleTranslation : item.exampleSentence
    }

    var progress: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(mastered.count) / CGFloat(totalCount)
    }

    var body: some View {
        Group {
            if showingSummary {
                SummaryView(
                    total: totalCount,
                    results: sessionResults,
                    onDone: { dismiss() }
                )
            } else if current != nil {
                cardView
            }
        }
        .onDisappear {
            ttsTask?.cancel()
            advanceTask?.cancel()  // Fix #19
            tts.stop()
            // Fix #4: save partial progress when user abandons session
            saveSession()
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 0) {
            // Gradient progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(duration: 0.4), value: mastered.count)
                }
            }
            .frame(height: 5)

            // Top bar
            HStack {
                Button {
                    ttsTask?.cancel()
                    tts.stop()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Beenden")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(mastered.count) von \(totalCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            // Card content
            VStack(spacing: 20) {
                // Prompt card
                VStack(spacing: 14) {
                    Text(isTermPrompt ? "\(deck.emoji) \(deck.name)" : deck.nativeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(promptText)
                        .font(.system(size: promptFontSize, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if isTermPrompt && tts.isAvailable {
                        ttsButton(text: promptText)
                    }

                    if let example = promptExample {
                        Divider().padding(.horizontal, 20)
                        exampleRow(text: example, isTerm: isTermPrompt)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(cardPadding)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                // Answer card (revealed)
                if isRevealed {
                    VStack(spacing: 14) {
                        Text(isTermPrompt ? deck.nativeLabel : "\(deck.emoji) \(deck.name)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text(answerText)
                            .font(.system(size: answerFontSize, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if !isTermPrompt && tts.isAvailable {
                            ttsButton(text: answerText)
                        }

                        if let example = answerExample {
                            Divider().padding(.horizontal, 20)
                            exampleRow(text: example, isTerm: !isTermPrompt)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, 28)
            .animation(.spring(duration: 0.35, bounce: 0.2), value: isRevealed)

            Spacer()

            // TTS error hint
            if let error = tts.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }

            // Bottom buttons
            if isRevealed {
                ratingButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    revealCard()
                } label: {
                    Text("Aufdecken")
                        .font(.title3)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .indigo.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .background(
            ZStack {
                Color(.systemGroupedBackground)
                if showSuccessFlash {
                    Color.green.opacity(0.2)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        )
        .animation(.easeOut(duration: 0.3), value: showSuccessFlash)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) {
            if !isRevealed {
                revealCard()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("1") {
            if isRevealed {
                rate(.again)
                return .handled
            }
            return .ignored
        }
        .onKeyPress("2") {
            if isRevealed {
                rate(.hard)
                return .handled
            }
            return .ignored
        }
        .onKeyPress("3") {
            if isRevealed {
                rate(.good)
                return .handled
            }
            return .ignored
        }
        .onAppear {
            isFocused = true
            resolveDirection()
        }
    }

    // MARK: - Example Row

    @ViewBuilder
    private func exampleRow(text: String, isTerm: Bool) -> some View {
        HStack(spacing: 8) {
            Text("\u{AB}\(text)\u{BB}")
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isTerm && tts.isAvailable {
                Button {
                    ttsTask?.cancel()
                    ttsTask = Task { await tts.speak(text, language: deck.ttsLanguage) }
                } label: {
                    Image(systemName: tts.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
                .disabled(tts.isLoading || tts.isPlaying)
            }
        }
    }

    // MARK: - TTS Button

    @ViewBuilder
    private func ttsButton(text: String) -> some View {
        Button {
            ttsTask?.cancel()
            ttsTask = Task { await tts.speak(text, language: deck.ttsLanguage) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tts.isLoading ? "hourglass" : (tts.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2"))
                Text("Anh\u{F6}ren")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.indigo)
        }
        .disabled(tts.isLoading || tts.isPlaying)
    }

    // MARK: - Rating Buttons

    @ViewBuilder
    private var ratingButtons: some View {
        HStack(spacing: 12) {
            RatingButton(
                label: "Nochmal",
                icon: "xmark.circle.fill",
                color: .red,
                description: "Sofort"
            ) { rate(.again) }

            RatingButton(
                label: "Fast",
                icon: "minus.circle.fill",
                color: .orange,
                description: "Sp\u{E4}ter"
            ) { rate(.hard) }

            RatingButton(
                label: "Gewusst!",
                icon: "checkmark.circle.fill",
                color: .green,
                description: "Fertig"
            ) { rate(.good) }
        }
    }

    // MARK: - Logic

    private func revealCard() {
        HapticService.light()
        withAnimation { isRevealed = true }
    }

    /// MosaLingua-style rating:
    /// - .again = show immediately again (stays at front)
    /// - .hard  = move to end of deck (comes back this session)
    /// - .good  = remove from deck (done for this session) + apply SRS
    private func rate(_ rating: SRSRating) {
        // Fix #1: block rapid re-taps during the success-flash delay
        guard !isAdvancing, let item = current else { return }

        // Track worst rating per card (raw value: .again=0 < .hard=1 < .good=2)
        let previousWorst = cardWorstRating[item.id]?.rawValue ?? Int.max
        if rating.rawValue < previousWorst {
            cardWorstRating[item.id] = rating
        }

        ttsTask?.cancel()
        tts.stop()

        switch rating {
        case .again:
            // Sofort nochmal: card stays at front, no SRS update yet
            HapticService.medium()
            isRevealed = false
            resolveDirection()

        case .hard:
            // Ans Ende setzen: no SRS update yet, card comes back later
            HapticService.medium()
            cardDeck.removeFirst()
            cardDeck.append(item)
            isRevealed = false
            resolveDirection()

        case .good:
            // Fertig: apply SRS ONCE with the worst rating of this card in this session
            isAdvancing = true
            HapticService.success()
            showSuccessFlash = true
            let finalRating = cardWorstRating[item.id] ?? .good
            // Track category transition for the progress chart
            let oldCategory = item.category
            SRSEngine.apply(rating: finalRating, to: item)
            let newCategory = item.category
            if oldCategory != newCategory {
                modelContext.insert(MasteryEvent(
                    vocabItemID: item.id,
                    from: oldCategory,
                    to: newCategory,
                    deck: item.deck
                ))
            }
            sessionResults.append(finalRating)
            advanceTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                // Fix #19: abort if the view was dismissed during the flash
                guard !Task.isCancelled else { return }
                // Fix #2: update mastered + deck together with animation
                withAnimation {
                    showSuccessFlash = false
                    mastered.insert(item.id)
                    cardDeck.removeFirst()
                }
                isAdvancing = false
                if cardDeck.isEmpty {
                    saveSession()
                    withAnimation { showingSummary = true }
                } else {
                    isRevealed = false
                    resolveDirection()
                }
            }
        }
    }

    private func saveSession() {
        // Fix #4: idempotent — called from both .onDisappear and completion
        guard !sessionSaved, !sessionResults.isEmpty else { return }
        sessionSaved = true

        let againCount = sessionResults.filter { $0 == .again }.count
        let hardCount = sessionResults.filter { $0 == .hard }.count
        let goodCount = sessionResults.filter { $0 == .good }.count

        let record = SessionRecord(
            totalCards: sessionResults.count,
            againCount: againCount,
            hardCount: hardCount,
            goodCount: goodCount
        )
        modelContext.insert(record)
        streakManager.recordSession(cardCount: sessionResults.count)
        completedSessionCount += 1
    }

    private func resolveDirection() {
        if direction == .random {
            resolvedDirection = Bool.random() ? .frToDE : .deToFR
        } else {
            resolvedDirection = direction
        }
    }
}

// MARK: - Rating Button

struct RatingButton: View {
    let label: String
    let icon: String
    let color: Color
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(color)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Summary View

struct SummaryView: View {
    let total: Int
    let results: [SRSRating]
    let onDone: () -> Void

    @ObservedObject private var streakManager = StreakManager.shared
    @Environment(\.requestReview) private var requestReview

    @AppStorage("completedSessionCount") private var completedSessionCount = 0
    @AppStorage("lastReviewPromptTS") private var lastReviewPromptTS: Double = 0

    var againCount: Int { results.filter { $0 == .again }.count }
    var hardCount: Int { results.filter { $0 == .hard }.count }
    var goodCount: Int { results.filter { $0 == .good }.count }

    private var shouldPromptReview: Bool {
        // Need at least 5 completed sessions in total
        guard completedSessionCount >= 5 else { return false }
        // Don't ask after a bad session (> 50% Gewusst)
        guard total > 0, Double(goodCount) / Double(total) >= 0.5 else { return false }
        // Respect cooldown: never more often than every 120 days
        let last = Date(timeIntervalSince1970: lastReviewPromptTS)
        let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? Int.max
        return daysSince >= 120
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Geschafft!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("\u{1F389}")
                    .font(.system(size: 60))
            }

            VStack(spacing: 14) {
                SummaryRow(icon: "checkmark.circle.fill", color: .green, label: "Gewusst", count: goodCount, total: total)
                SummaryRow(icon: "minus.circle.fill", color: .orange, label: "Fast", count: hardCount, total: total)
                SummaryRow(icon: "xmark.circle.fill", color: .red, label: "Nochmal", count: againCount, total: total)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            if streakManager.currentStreak > 0 {
                HStack(spacing: 14) {
                    Text("\u{1F525}")
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streakManager.currentStreak) Tage Streak")
                            .font(.title2)
                            .fontWeight(.bold)
                            .fontDesign(.rounded)
                        if streakManager.currentStreak >= streakManager.longestStreak
                            && streakManager.currentStreak > 1 {
                            Text("Neuer Rekord! \u{1F4AA}")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
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
                .padding(.horizontal, 32)
            }

            Spacer()

            Button { onDone() } label: {
                Text("Weiter")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .onAppear {
            guard shouldPromptReview else { return }
            // Delay so the summary is visible before the system dialog appears
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                lastReviewPromptTS = Date().timeIntervalSince1970
                requestReview()
            }
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let color: Color
    let label: String
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(label)
                .fontWeight(.medium)
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    Capsule()
                        .fill(color)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(count) / CGFloat(total) : 0)
                }
            }
            .frame(width: 60, height: 8)
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundStyle(color)
        }
    }
}
