import SwiftUI

/// Swipe direction for rating a revealed card.
enum CardSwipeDirection {
    case left   // "Nochmal"
    case right  // "Gewusst!" / "Kann ich!"
}

/// Prompt/answer card pair shared by learning and drill sessions.
///
/// All content is passed **by value**: an outgoing card in a removal
/// transition keeps showing its own content — never the next card's
/// (fix for the reveal-leak from the App Store review). The parent gives
/// each card advance a fresh identity via `.id(engine.generation)`.
///
/// A revealed card can be swiped: right = knew it, left = again. The swipe
/// direction is deliberately physical (not layout-direction-mirrored) so it
/// matches the badge colors in RTL languages too.
struct SessionCardView: View {
    struct Badge {
        let icon: String
        let color: Color
    }

    let promptLabel: String
    let answerLabel: String
    let promptText: String
    let answerText: String
    let promptExample: String?
    let answerExample: String?
    /// True when the prompt side is the foreign-language term (that side gets TTS).
    let promptIsTerm: Bool
    let ttsLanguage: String
    let isRevealed: Bool
    let promptFontSize: CGFloat
    let answerFontSize: CGFloat
    let cardPadding: CGFloat
    let leftBadge: Badge
    let rightBadge: Badge
    let onSwipe: (CardSwipeDirection) -> Void

    @ObservedObject private var tts = TTSService.shared
    @State private var ttsTask: Task<Void, Never>?
    @State private var dragOffset: CGSize = .zero

    /// -1 … +1, fully saturated at 150 pt of horizontal travel.
    private var swipeProgress: CGFloat {
        max(-1, min(1, dragOffset.width / 150))
    }

    var body: some View {
        VStack(spacing: 20) {
            promptCard

            if isRevealed {
                answerCard
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: isRevealed)
        .overlay(swipeBadge)
        .offset(x: dragOffset.width, y: dragOffset.height * 0.1)
        .rotationEffect(.degrees(swipeProgress * 3))
        // Swipe only once revealed; .subviews keeps the TTS buttons tappable.
        .gesture(dragGesture, including: isRevealed ? .all : .subviews)
        .onDisappear { ttsTask?.cancel() }
    }

    // MARK: - Swipe

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let travel = value.translation.width
                let projected = value.predictedEndTranslation.width
                // Decisive if dragged far enough, or flicked fast enough.
                let decisive = abs(travel) > 120 ? travel : (abs(projected) > 260 ? projected : 0)

                if decisive == 0 {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = .zero }
                } else {
                    withAnimation(.easeOut(duration: 0.25)) {
                        dragOffset.width = decisive > 0 ? 1200 : -1200
                    }
                    onSwipe(decisive > 0 ? .right : .left)
                }
            }
    }

    @ViewBuilder
    private var swipeBadge: some View {
        ZStack {
            Image(systemName: rightBadge.icon)
                .font(.system(size: 64))
                .foregroundStyle(rightBadge.color)
                .opacity(swipeProgress > 0 ? Double(swipeProgress) : 0)
            Image(systemName: leftBadge.icon)
                .font(.system(size: 64))
                .foregroundStyle(leftBadge.color)
                .opacity(swipeProgress < 0 ? Double(-swipeProgress) : 0)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Cards

    private var promptCard: some View {
        VStack(spacing: 14) {
            Text(promptLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(promptText)
                .font(.system(size: promptFontSize, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if promptIsTerm && tts.isAvailable {
                ttsButton(text: promptText)
            }

            if let example = promptExample {
                Divider().padding(.horizontal, 20)
                exampleRow(text: example, isTerm: promptIsTerm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var answerCard: some View {
        VStack(spacing: 14) {
            Text(answerLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Text(answerText)
                .font(.system(size: answerFontSize, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !promptIsTerm && tts.isAvailable {
                ttsButton(text: answerText)
            }

            if let example = answerExample {
                Divider().padding(.horizontal, 20)
                exampleRow(text: example, isTerm: !promptIsTerm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - TTS

    private func speak(_ text: String) {
        ttsTask?.cancel()
        ttsTask = Task { await tts.speak(text, language: ttsLanguage) }
    }

    @ViewBuilder
    private func ttsButton(text: String) -> some View {
        Button {
            speak(text)
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
                    speak(text)
                } label: {
                    Image(systemName: tts.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
                .disabled(tts.isLoading || tts.isPlaying)
            }
        }
    }
}
