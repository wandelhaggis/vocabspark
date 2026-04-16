import SwiftUI

/// Drill-until-mastery session for vocab test preparation.
/// Cards repeat until all are marked "Kann ich!". No SRS changes.
struct VocabTestSessionView: View {
    let items: [VocabItem]
    let direction: LearningDirection
    let deck: LanguageDeck

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tts = TTSService.shared

    @State private var cardDeck: [VocabItem]
    @State private var mastered: Set<UUID> = []
    @State private var isRevealed = false
    @State private var showingSummary = false
    @State private var resolvedDirection: LearningDirection = .frToDE
    @State private var ttsTask: Task<Void, Never>?
    @State private var round = 1
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

    var body: some View {
        Group {
            if showingSummary {
                testSummary
            } else if current != nil {
                cardView
            }
        }
        .onDisappear {
            ttsTask?.cancel()
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
                        .frame(width: totalCount > 0 ? geo.size.width * CGFloat(mastered.count) / CGFloat(totalCount) : 0)
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
                if round > 1 {
                    Text("(Runde \(round))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Spacer()

            // Card content
            VStack(spacing: 20) {
                // Prompt card
                VStack(spacing: 14) {
                    Text(isTermPrompt ? "\(deck.emoji) \(deck.name)" : "\u{1F1E9}\u{1F1EA} Deutsch")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text(promptText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
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
                .padding(32)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                // Answer (revealed)
                if isRevealed {
                    VStack(spacing: 14) {
                        Text(isTermPrompt ? "\u{1F1E9}\u{1F1EA} Deutsch" : "\(deck.emoji) \(deck.name)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text(answerText)
                            .font(.system(size: 30, weight: .medium, design: .rounded))
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

            if let error = tts.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
            }

            // Bottom buttons
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
    }

    // MARK: - Helpers

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

    // MARK: - Logic

    private func revealCard() {
        HapticService.light()
        withAnimation { isRevealed = true }
    }

    private func rateNochmal() {
        guard !cardDeck.isEmpty else { return }
        HapticService.medium()
        ttsTask?.cancel()
        tts.stop()

        let item = cardDeck.removeFirst()
        // Insert at a random later position so the card comes back
        let insertAt = cardDeck.isEmpty ? 0 : Int.random(in: min(2, cardDeck.count)...cardDeck.count)
        cardDeck.insert(item, at: insertAt)
        round = max(round, mastered.count == 0 ? 1 : 2)

        isRevealed = false
        resolveDirection()
        // TTS only on user tap
    }

    private func rateMastered() {
        guard let item = cardDeck.first else { return }
        HapticService.success()
        ttsTask?.cancel()
        tts.stop()

        // Show green flash, then advance after 350ms
        showSuccessFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            showSuccessFlash = false

            cardDeck.removeFirst()
            mastered.insert(item.id)

            if cardDeck.isEmpty {
                withAnimation { showingSummary = true }
            } else {
                isRevealed = false
                resolveDirection()
                // TTS only on user tap
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
                Text("\(totalCount) Vokabeln gemeistert")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
                if round > 1 {
                    Text("In \(round) Runden")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Alles beim ersten Mal!")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
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
