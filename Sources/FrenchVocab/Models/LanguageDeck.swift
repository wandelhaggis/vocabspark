import Foundation
import SwiftData

@Model
final class LanguageDeck {
    var id: UUID
    var name: String           // "Französisch", "Spanisch"
    var emoji: String          // "🇫🇷", "🇪🇸"
    var ttsLanguage: String    // "French", "Spanish" (for TTS API)
    var createdAt: Date

    init(name: String, emoji: String, ttsLanguage: String) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.ttsLanguage = ttsLanguage
        self.createdAt = Date()
    }
}

/// Predefined languages for easy selection.
struct LanguageOption: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let ttsLanguage: String
}

let predefinedLanguages: [LanguageOption] = [
    .init(name: "Franz\u{F6}sisch", emoji: "\u{1F1EB}\u{1F1F7}", ttsLanguage: "French"),
    .init(name: "Englisch", emoji: "\u{1F1EC}\u{1F1E7}", ttsLanguage: "English"),
    .init(name: "Spanisch", emoji: "\u{1F1EA}\u{1F1F8}", ttsLanguage: "Spanish"),
    .init(name: "Italienisch", emoji: "\u{1F1EE}\u{1F1F9}", ttsLanguage: "Italian"),
    .init(name: "Portugiesisch", emoji: "\u{1F1F5}\u{1F1F9}", ttsLanguage: "Portuguese"),
    .init(name: "Niederl\u{E4}ndisch", emoji: "\u{1F1F3}\u{1F1F1}", ttsLanguage: "Dutch"),
    .init(name: "Schwedisch", emoji: "\u{1F1F8}\u{1F1EA}", ttsLanguage: "Swedish"),
    .init(name: "Polnisch", emoji: "\u{1F1F5}\u{1F1F1}", ttsLanguage: "Polish"),
    .init(name: "Russisch", emoji: "\u{1F1F7}\u{1F1FA}", ttsLanguage: "Russian"),
    .init(name: "T\u{FC}rkisch", emoji: "\u{1F1F9}\u{1F1F7}", ttsLanguage: "Turkish"),
    .init(name: "Griechisch", emoji: "\u{1F1EC}\u{1F1F7}", ttsLanguage: "Greek"),
    .init(name: "Japanisch", emoji: "\u{1F1EF}\u{1F1F5}", ttsLanguage: "Japanese"),
    .init(name: "Koreanisch", emoji: "\u{1F1F0}\u{1F1F7}", ttsLanguage: "Korean"),
    .init(name: "Chinesisch", emoji: "\u{1F1E8}\u{1F1F3}", ttsLanguage: "Chinese"),
    .init(name: "Arabisch", emoji: "\u{1F1F8}\u{1F1E6}", ttsLanguage: "Arabic"),
    .init(name: "Latein", emoji: "\u{1F3DB}\u{FE0F}", ttsLanguage: "Latin"),
]
