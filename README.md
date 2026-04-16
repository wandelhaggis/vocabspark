# VocabFr — iPad French Vocabulary App

Einfache SRS-basierte Vokabel-App für iPadOS. Kein Schnickschnack.

## Features
- Vokabeln eingeben (FR ↔ DE)
- SRS-Algorithmus (SM-2, 3-Button: Nochmal / Fast / Gewusst)
- OpenAI TTS für französische Aussprache mit lokalem Cache
- Lernmodus: FR→DE, DE→FR, Zufall
- Nur fällige Karten oder alle

## Setup

### 1. XcodeGen installieren
```bash
brew install xcodegen
```

### 2. Projekt generieren
```bash
cd FrenchVocab
xcodegen generate
```

### 3. OpenAI API Key konfigurieren

Erstelle eine Datei `Config.xcconfig` (wird von Git ignoriert):
```
OPENAI_API_KEY = sk-dein-key-hier
```

Dann in `project.yml` unter `targets.FrenchVocab.settings.base` ergänzen:
```yaml
INFOPLIST_FILE: Sources/FrenchVocab/Info.plist
```

Und in `Info.plist` den Key eintragen:
```xml
<key>OPENAI_API_KEY</key>
<string>$(OPENAI_API_KEY)</string>
```

**Alternativ (schnell & dirty für Tests):** Den API Key direkt in `TTSService.swift` hardcoden — aber niemals ins Git committen.

### 4. Bundle ID anpassen
In `project.yml`:
```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.DEINNAME.frenchvocab
```

### 5. Signing
In Xcode: Target → Signing & Capabilities → Team auswählen.

## TTS Kosten
- OpenAI `tts-1`: ~$0.015 pro 1.000 Zeichen
- Jede Vokabel wird gecacht → jedes Wort wird nur einmal abgerufen
- Bei 500 Vokabeln: Einmalkosten ~$0.10–0.20

## SRS Algorithmus

3-Button SM-2 Variante:

| Button | Intervall |
|--------|-----------|
| Nochmal | 1 Tag (Reset) |
| Fast | ×1.2 (langsamer Anstieg) |
| Gewusst | ×EaseFactor (Standard ~2.5) |

Ease Factor startet bei 2.5, sinkt bei Fehlern (min. 1.3).
