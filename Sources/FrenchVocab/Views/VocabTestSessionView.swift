import SwiftUI

/// Drill-until-mastery session for vocab test preparation.
/// Cards repeat until all are marked "Kann ich!". No SRS changes.
struct VocabTestSessionView: View {
    let items: [VocabItem]
    let direction: LearningDirection
    let deck: LanguageDeck

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @ObservedObject private var tts = TTSService.shared

    private var promptFontSize: CGFloat { hSize == .compact ? 28 : 34 }
    private var answerFontSize: CGFloat { hSize == .compact ? 24 : 30 }
    private var cardPadding: CGFloat { hSize == .compact ? 20 : 32 }

    /// Deck state machine: failed cards come back at a random later position.
    @State private var engine: SessionDeckEngine
    @State private var isRevealed = false
    @State private var showingSummary = false
    @State private var resolvedDirection: LearningDirection = .frToDE
    @State private var ttsTask: Task<Void, Never>?
    @State private var showSuccessFlash = false
    @State private var flashResetTask: Task<Void, Never>?
    @State private var summaryTask: Task<Void, Never>?

    @FocusState private var isFocused: Bool

    private let itemsByID: [UUID: VocabItem]

    init(items: [VocabItem], direction: LearningDirection, deck: LanguageDeck) {
        self.items = items
        self.direction = direction
        self.deck = deck
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        _engine = State(initialValue: SessionDeckEngine(cardIDs: items.map(\.id), reinsertPolicy: .randomLater))
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

    var body: some View {
        Group {
            if showingSummary {
                testSummary
            } else {
                cardView
            }
        }
        .onDisappear {
            ttsTask?.cancel()
            flashResetTask?.cancel()
            summaryTask?.cancel()
            tts.stop()
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private var cardView: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: engine.totalCount > 0 ? geo.size.width * CGFloat(engine.mastered.count) / CGFloat(engine.totalCount) : 0)
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
                if !engine.repeatedIDs.isEmpty {
                    Text("\u{B7} \(engine.repeatedIDs.count) wiederholt")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Spacer()

            // Card content — fresh identity per advance (see SessionCardView).
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
                        leftBadge: .init(icon: "arrow.counterclockwise.circle.fill", color: .orange),
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

            if let error = tts.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }

            // Bottom buttons (hidden once the deck is empty and the summary is pending)
            if !engine.isFinished {
                if isRevealed {
                    drillButtons
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
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
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

                // Green flash overlay
                if showSuccessFlash {
                    Color.green.opacity(0.25)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
        )
        .animation(.easeOut(duration: 0.25), value: showSuccessFlash)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) {
            guard !isRevealed else { return .ignored }
            revealCard()
            return .handled
        }
        .onKeyPress("1") {
            guard isRevealed else { return .ignored }
            rateNochmal()
            return .handled
        }
        .onKeyPress("2") {
            guard isRevealed else { return .ignored }
            rateMastered()
            return .handled
        }
        .onAppear {
            isFocused = true
            resolveDirection()
        }
    }

    // MARK: - Drill Buttons

    @ViewBuilder
    private var drillButtons: some View {
        HStack(spacing: 16) {
            // Nochmal
            Button { rateNochmal() } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.orange)
                    Text("Nochmal")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Kann ich!
            Button { rateMastered() } label: {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.green)
                    Text("Kann ich!")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        // Pin physical order: orange must stay left so it matches swipe-left,
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
        if direction == .right {
            rateMastered()
        } else {
            rateNochmal()
        }
    }

    private func rateNochmal() {
        // Only a revealed card can be rated (closes the double-tap window).
        guard isRevealed, current != nil else { return }
        isRevealed = false
        HapticService.medium()
        ttsTask?.cancel()
        tts.stop()

        withAnimation(cardAdvanceAnimation) { engine.rateAgain() }
        resolveDirection()
    }

    private func rateMastered() {
        guard isRevealed, current != nil else { return }
        isRevealed = false
        HapticService.success()
        ttsTask?.cancel()
        tts.stop()

        withAnimation(cardAdvanceAnimation) { _ = engine.rateGood() }
        flashSuccess()

        if engine.isFinished {
            summaryTask = Task {
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                withAnimation { showingSummary = true }
            }
        } else {
            resolveDirection()
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

    private func resolveDirection() {
        if direction == .random {
            resolvedDirection = Bool.random() ? .frToDE : .deToFR
        } else {
            resolvedDirection = direction
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var testSummary: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Alles geschafft!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("\u{1F4AA}")
                    .font(.system(size: 60))
            }

            VStack(spacing: 8) {
                Text("\(engine.totalCount) Vokabeln gemeistert")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                // Fix #20: only claim "first try" if no card was ever repeated
                if engine.repeatedIDs.isEmpty {
                    Text("Alles beim ersten Mal!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                } else {
                    Text("\(engine.repeatedIDs.count) Vokabeln wiederholt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Spacer()

            Button { dismiss() } label: {
                Text("Fertig")
                    .font(.title3)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
