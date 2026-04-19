import Foundation
import SwiftData

@Model
final class LanguageDeck {
    var id: UUID
    var name: String               // "Französisch", "Spanisch" (display in UI language)
    var emoji: String              // "🇫🇷", "🇪🇸"
    var ttsLanguage: String        // "French", "Spanish" (English name, for GPT/TTS prompts)
    /// ISO 639-1 code of the native language (the "back" of the card, UI side).
    /// Default "de" for legacy decks created before v2.0.
    var nativeLanguageCode: String = "de"
    var createdAt: Date

    init(name: String, emoji: String, ttsLanguage: String, nativeLanguageCode: String = "de") {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.ttsLanguage = ttsLanguage
        self.nativeLanguageCode = nativeLanguageCode
        self.createdAt = Date()
    }

    /// Localized name of the deck's target (foreign) language, e.g. "Französisch" / "French".
    /// Use this in UI. The stored `name` is the German key used for localization lookup.
    var displayName: String {
        // Look up via the stable English name (ttsLanguage) to find the ISO code,
        // then return the localized display name for that code.
        if let code = LanguageCatalog.code(forEnglishName: ttsLanguage),
           let localized = LanguageCatalog.displayName(for: code) {
            return localized
        }
        return name  // fallback to the stored German name
    }

    /// English name of the native language (for GPT prompts).
    var nativeLanguageName: String {
        LanguageCatalog.englishName(for: nativeLanguageCode) ?? "German"
    }

    /// Flag emoji for the native language (for UI).
    var nativeEmoji: String {
        LanguageCatalog.emoji(for: nativeLanguageCode) ?? "\u{1F1E9}\u{1F1EA}"
    }

    /// Localized display name for the native language (for UI).
    var nativeDisplayName: String {
        LanguageCatalog.displayName(for: nativeLanguageCode) ?? "Deutsch"
    }

    /// Formatted label "🇩🇪 Deutsch" for native-language section headers.
    var nativeLabel: String {
        "\(nativeEmoji) \(nativeDisplayName)"
    }
}

/// Predefined language option for selection UIs.
struct LanguageOption: Identifiable {
    let id = UUID()
    /// German display name — also used as the localization key in `Localizable.xcstrings`.
    let name: String
    let emoji: String
    /// English name — stable, used for API prompts (TTS, GPT).
    let ttsLanguage: String
    /// ISO 639-1 code — stable, used for locale matching.
    let code: String

    /// UI-facing language name, looked up in the String Catalog via the German name as key.
    var localizedName: String {
        NSLocalizedString(name, comment: "Language display name")
    }
}

/// Central list of supported languages. Used for both target (all 17) and native (15 — Latin excluded).
let predefinedLanguages: [LanguageOption] = [
    .init(name: "Deutsch",           emoji: "\u{1F1E9}\u{1F1EA}", ttsLanguage: "German",     code: "de"),
    .init(name: "Englisch",          emoji: "\u{1F1EC}\u{1F1E7}", ttsLanguage: "English",    code: "en"),
    .init(name: "Franz\u{F6}sisch",  emoji: "\u{1F1EB}\u{1F1F7}", ttsLanguage: "French",     code: "fr"),
    .init(name: "Spanisch",          emoji: "\u{1F1EA}\u{1F1F8}", ttsLanguage: "Spanish",    code: "es"),
    .init(name: "Italienisch",       emoji: "\u{1F1EE}\u{1F1F9}", ttsLanguage: "Italian",    code: "it"),
    .init(name: "Portugiesisch",     emoji: "\u{1F1F5}\u{1F1F9}", ttsLanguage: "Portuguese", code: "pt"),
    .init(name: "Niederl\u{E4}ndisch", emoji: "\u{1F1F3}\u{1F1F1}", ttsLanguage: "Dutch",    code: "nl"),
    .init(name: "Schwedisch",        emoji: "\u{1F1F8}\u{1F1EA}", ttsLanguage: "Swedish",    code: "sv"),
    .init(name: "Polnisch",          emoji: "\u{1F1F5}\u{1F1F1}", ttsLanguage: "Polish",     code: "pl"),
    .init(name: "Russisch",          emoji: "\u{1F1F7}\u{1F1FA}", ttsLanguage: "Russian",    code: "ru"),
    .init(name: "T\u{FC}rkisch",     emoji: "\u{1F1F9}\u{1F1F7}", ttsLanguage: "Turkish",    code: "tr"),
    .init(name: "Griechisch",        emoji: "\u{1F1EC}\u{1F1F7}", ttsLanguage: "Greek",      code: "el"),
    .init(name: "Japanisch",         emoji: "\u{1F1EF}\u{1F1F5}", ttsLanguage: "Japanese",   code: "ja"),
    .init(name: "Koreanisch",        emoji: "\u{1F1F0}\u{1F1F7}", ttsLanguage: "Korean",     code: "ko"),
    .init(name: "Chinesisch",        emoji: "\u{1F1E8}\u{1F1F3}", ttsLanguage: "Chinese",    code: "zh"),
    .init(name: "Arabisch",          emoji: "\u{1F1F8}\u{1F1E6}", ttsLanguage: "Arabic",     code: "ar"),
    .init(name: "Latein",            emoji: "\u{1F3DB}\u{FE0F}",  ttsLanguage: "Latin",      code: "la"),
]

/// Helper for language lookups by ISO code.
enum LanguageCatalog {
    /// All predefined languages that can serve as native (UI) language. Latin excluded.
    static let nativeCapableLanguages: [LanguageOption] = predefinedLanguages.filter { $0.code != "la" }

    /// Returns the English language name for a given ISO code (used in GPT prompts).
    static func englishName(for code: String) -> String? {
        predefinedLanguages.first { $0.code == code }?.ttsLanguage
    }

    /// Reverse lookup: find the ISO code for a given English language name.
    static func code(forEnglishName englishName: String) -> String? {
        predefinedLanguages.first { $0.ttsLanguage == englishName }?.code
    }

    /// Returns the localized language name for a given ISO code.
    /// Looks up the German name in the String Catalog and returns the
    /// translation for the current locale.
    static func displayName(for code: String) -> String? {
        predefinedLanguages.first { $0.code == code }?.localizedName
    }

    /// Returns the flag emoji for a given ISO code.
    static func emoji(for code: String) -> String? {
        predefinedLanguages.first { $0.code == code }?.emoji
    }

    /// Best-match default native language based on the device's current locale.
    /// Falls back to German if device language isn't in our supported list.
    static var defaultNativeLanguageCode: String {
        let deviceCode = Locale.current.language.languageCode?.identifier ?? "de"
        return nativeCapableLanguages.contains { $0.code == deviceCode } ? deviceCode : "de"
    }
}
