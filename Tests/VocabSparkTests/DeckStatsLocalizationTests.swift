import Testing
import Foundation
@testable import VocabSpark

/// Localization contract for the deck stats line "%lld Wörter · %lld gelernt":
/// both counts must inflect correctly in the singular. Tests resolve the
/// compiled string catalog per language from the app bundle, so they exercise
/// exactly what ships. Only languages whose plural boundary is 1↔other are
/// asserted here (category selection follows the runtime locale).
struct DeckStatsLocalizationTests {

    private let key = "%lld Wörter · %lld gelernt"

    private func stats(_ lang: String, _ total: Int, _ learned: Int) throws -> String {
        let path = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String.localizedStringWithFormat(format, total, learned)
    }

    @Test func german_singularWord() throws {
        #expect(try stats("de", 1, 0) == "1 Wort · 0 gelernt")
    }

    @Test func german_pluralWords() throws {
        #expect(try stats("de", 5, 3) == "5 Wörter · 3 gelernt")
    }

    @Test func english_singularWord() throws {
        #expect(try stats("en", 1, 1) == "1 word · 1 learned")
    }

    @Test func spanish_singularLearnedInflects() throws {
        #expect(try stats("es", 3, 1) == "3 palabras · 1 aprendida")
    }

    @Test func swedish_singularLearnedInflects() throws {
        #expect(try stats("sv", 1, 1) == "1 ord · 1 inlärt")
    }

    // Gleiche Vertragspflicht für Ein-Argument-Keys (Plural-Variationen)

    private func localized(_ lang: String, _ key: String, _ n: Int) throws -> String {
        let path = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String.localizedStringWithFormat(format, n)
    }

    @Test func german_sessionButton_singularCard() throws {
        #expect(try localized("de", "Los geht's! (%lld Karten)", 1) == "Los geht's! (1 Karte)")
    }

    @Test func french_repeatedCount_singularInflects() throws {
        #expect(try localized("fr", "· %lld wiederholt", 1) == "· 1 répété")
    }
}
