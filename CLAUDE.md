# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an iPadOS-only SwiftUI app using **XcodeGen** to generate the Xcode project from `project.yml`.

```bash
# Generate Xcode project (run after any project.yml change)
xcodegen generate

# Build from command line
xcodebuild -project VocabSpark.xcodeproj -scheme VocabSpark -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)' build

# There are no tests configured (testTargets is empty in project.yml)
```

## Architecture

**SwiftUI + SwiftData** app for learning vocabulary in any language with spaced repetition (Foreign Language ↔ DE).

- **Data layer**: `LanguageDeck` model represents a language (name, emoji, TTS code). `VocabItem` has `term`/`translation` fields and a `deck` relationship. `SessionRecord` stores learning session results. All persisted via SwiftData.
- **Multi-language**: Users create language decks from a predefined list (16 languages). Each deck has its own vocabulary. A `LanguagePickerView` is shown on app start.
- **SRS engine**: `SRSEngine` is a stateless struct with a single static method `apply(rating:to:)` that mutates a `VocabItem` in place. Implements a 3-button SM-2 variant (`.again` / `.hard` / `.good`).
- **Vocab test mode**: `VocabTestSessionView` — drill-until-mastery session separate from SRS. Cards repeat until all marked "Kann ich!". No SRS changes applied.
- **TTS**: `TTSService` singleton calls OpenAI `gpt-4o-mini-tts` API with dynamic language instructions. Caches MP3 files using SHA256 hashes. API key stored in UserDefaults (user-configurable in Settings).
- **Example sentences**: `ExampleSentenceService` calls GPT-4o-mini to generate A1/A2 example sentences. Auto-fetched on vocab creation, stored on `VocabItem`.
- **Navigation**: `RootView` → `LanguagePickerView` (select deck) → `ContentView` (TabView with Vokabeln/Lernen/Einstellungen). Learning sessions and vocab tests launch as `fullScreenCover`.

## Key Conventions

- UI language is **German** (labels, buttons, status text)
- iPad-only: `TARGETED_DEVICE_FAMILY: "2"` in project.yml
- Deployment target: iOS 17.0, Swift 5.9
- No external dependencies — pure Apple frameworks + OpenAI REST API
- OpenAI API key configured by user in Settings tab (stored in UserDefaults), with fallback to `Config.xcconfig` for development
- Target user is a 13-year-old — simplicity is the top priority
- Haptic feedback on all key interactions (HapticService)
- iPad keyboard shortcuts: Space = reveal, 1/2/3 = rating buttons
