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

    /// Deck state machine: cards cycle until rated "Gewusst!".
    @State private var engine: SessionDeckEngine
    @State private var isRevealed = false
    /// Total completed sessions — used to throttle review prompt.
    @AppStorage("completedSessionCount") private var completedSessionCount = 0
    /// Fix #4: prevent saveSession from running twice.
    @State private var sessionSaved = false
    @State private var showingSummary = false
    @State private var resolvedDirection: LearningDirection = .frToDE
    @State private var ttsTask: Task<Void, Never>?
    @State private var showSuccessFlash = false
    @State private var flashResetTask: Task<Void, Never>?
    /// Short delay before the summary so the last card's fly-out stays visible.
    @State private var summaryTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private let itemsByID: [UUID: VocabItem]

    init(items: [VocabItem], direction: LearningDirection, deck: LanguageDeck) {
        self.items = items
        self.direction = direction
        self.deck = deck
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        _engine = State(initialValue: SessionDeckEngine(cardIDs: items.map(\.id)))
    }

    var current: VocabItem? {
        engine.currentID.flatMap { itemsByID[$0] }
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
        guard engine.totalCount > 0 else { return 0 }
        return CGFloat(engine.mastered.count) / CGFloat(engine.totalCount)
    }

    var body: some View {
        Group {
            if showingSummary {
                SummaryView(
                    total: engine.totalCount,
                    results: engine.results,
                    onDone: { dismiss() }
                )
            } else {
                cardView
            }
        }
        .onDisappear {
            ttsTask?.cancel()
            flashResetTask?.cancel()
            summaryTask?.cancel()
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
                        .animation(.spring(duration: 0.4), value: engine.mastered.count)
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
                Text("\(engine.mastered.count) von \(engine.totalCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Spacer()

            // Card content — a fresh identity per advance means the outgoing
            // card always animates out with its own (old) content.
            Group {
                if current != nil {
                    SessionCardView(
                        promptLabel: isTermPrompt ? "\(deck.emoji) \(deck.displayName)" : deck.nativeLabel,
                        answerLabel: isTermPrompt ? deck.nativeLabel : "\(deck.emoji) \(deck.displayName)",
                        promptText: promptText,
                        answerText: answerText,
                        promptExample: promptExample,
                        answerExample: answerExample,
                        promptIsTerm: isTermPrompt,
                        ttsLanguage: deck.ttsLanguage,
                        isRevealed: isRevealed,
                        promptFontSize: promptFontSize,
                        answerFontSize: answerFontSize,
                        cardPadding: cardPadding,
                        leftBadge: .init(icon: "xmark.circle.fill", color: .red),
                        rightBadge: .init(icon: "checkmark.circle.fill", color: .green),
                        onSwipe: handleSwipe
                    )
                    .id(engine.generation)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            // TTS error hint
            if let error = tts.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }

            // Bottom buttons (hidden once the deck is empty and the summary is pending)
            if !engine.isFinished {
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

    // MARK: - Rating Buttons

    @ViewBuilder
    private var ratingButtons: some View {
        HStack(spacing: 12) {
            RatingButton(
                label: "Nochmal",
                icon: "xmark.circle.fill",
                color: .red,
                description: "Sp\u{E4}ter"
            ) { rate(.again) }

            RatingButton(
                label: "Gewusst!",
                icon: "checkmark.circle.fill",
                color: .green,
                description: "Fertig"
            ) { rate(.good) }
        }
        // Pin physical order: red must stay left so it matches swipe-left,
        // also in RTL languages (same approach as the pinned i18n arrows).
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: - Logic

    private func revealCard() {
        guard current != nil else { return }
        HapticService.light()
        withAnimation { isRevealed = true }
    }

    private func handleSwipe(_ direction: CardSwipeDirection) {
        rate(direction == .right ? .good : .again)
    }

    /// 2-button rating:
    /// - .again = "Nochmal": back to the end of the deck, final SRS rating
    ///            locked to reset (comes back tomorrow)
    /// - .good  = "Gewusst!": done for this session, SRS applied once
    private func rate(_ rating: SRSRating) {
        // Only a revealed card can be rated. Hiding it as the first mutation
        // closes the double-tap window — no advancing lock needed.
        guard isRevealed, let item = current else { return }
        isRevealed = false
        ttsTask?.cancel()
        tts.stop()

        switch rating {
        case .again:
            HapticService.medium()
            withAnimation(cardAdvanceAnimation) { engine.rateAgain() }
            resolveDirection()

        case .good:
            HapticService.success()
            var finalRating: SRSRating = .good
            withAnimation(cardAdvanceAnimation) {
                finalRating = engine.rateGood() ?? .good
            }
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
            flashSuccess()

            if engine.isFinished {
                saveSession()
                summaryTask = Task {
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation { showingSummary = true }
                }
            } else {
                resolveDirection()
            }
        }
    }

    private var cardAdvanceAnimation: Animation {
        .spring(duration: 0.35, bounce: 0.15)
    }

    /// Decorative, non-blocking success flash.
    private func flashSuccess() {
        flashResetTask?.cancel()
        showSuccessFlash = true
        flashResetTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            showSuccessFlash = false
        }
    }

    private func saveSession() {
        // Fix #4: idempotent — called from both .onDisappear and completion
        guard !sessionSaved, !engine.results.isEmpty else { return }
        sessionSaved = true

        let againCount = engine.results.filter { $0 == .again }.count
        let goodCount = engine.results.filter { $0 == .good }.count

        let record = SessionRecord(
            totalCards: engine.results.count,
            againCount: againCount,
            hardCount: 0,
            goodCount: goodCount
        )
        modelContext.insert(record)
        streakManager.recordSession(cardCount: engine.results.count)
        completedSessionCount += 1

        // SRS state changed — re-plan reminders so they only fire on days with due cards.
        let reminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        if reminderEnabled {
            let hour = UserDefaults.standard.object(forKey: "dailyReminderHour") as? Int ?? 17
            let minute = UserDefaults.standard.object(forKey: "dailyReminderMinute") as? Int ?? 0
            let context = modelContext
            Task { @MainActor in
                await NotificationService.shared.refreshReminderSchedule(
                    hour: hour,
                    minute: minute,
                    modelContext: context
                )
            }
        }
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
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    let description: LocalizedStringKey
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
    let label: LocalizedStringKey
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
