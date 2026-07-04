# Manueller Testplan v1.2.0 — Wischen & schnelleres Lernen

Stand: 2026-07-04. Automatisch verifiziert sind: 19 Unit-Tests grün (SessionDeckEngine,
SRSEngine), Build grün, App bootet im Simulator, Deck-Anlage funktioniert.
**Nicht** automatisch prüfbar sind die visuellen/haptischen Punkte unten — die brauchen
Hand am Gerät oder Simulator. Nach bestandenem Test: committen (Wortlaut siehe CHANGELOG v1.2.0).

## Setup

- App ist bereits im Simulator **iPad Air 13-inch (M4)** installiert (Debug-Build v1.2.0).
  Starten: `open -a Simulator`, App "VocabSpark" öffnen.
  Bei Code-Änderungen vorher: `xcodegen generate` + Build (Kommandos in CLAUDE.md).
- Ein Sprach-Deck existiert schon (gestern per Automation angelegt). Für die Tests
  **5–6 Vokabeln anlegen** (ohne OpenAI-Key: Auto-Übersetzen/TTS/Beispielsätze fehlen — für
  diese Tests egal, nur Test 3e/3f braucht einen Key).

## 1. Leak-Fix — der Rezensions-Bug (wichtigster Test)

- [ ] **1a** Lernsession mit ≥3 Vokabeln starten. Aufdecken → "Gewusst!". Beim Kartenwechsel
  scharf hinsehen: Die rausanimierende Karte darf **nie** die Auflösung der *nächsten* Karte
  zeigen. Mehrfach zügig wiederholen.
- [ ] **1b** Dasselbe mit "Nochmal" statt "Gewusst!".
- [ ] **1c** Grenzfall gleiche Karte: Session so weit spielen, bis nur noch **1 Karte** übrig
  ist, Richtung "Zufällig". Mehrfach "Nochmal" drücken — dieselbe Karte kommt wieder, ggf. mit
  getauschter Abfragerichtung. Kein Aufblitzen der Antwort, Karte hängt nicht versetzt.
- [ ] **1d** Vokabeltest-Modus: 1a–1c dort wiederholen ("Nochmal" / "Kann ich!").
- [ ] **1e** Kosmetik-Blick: Wenn die alte Karte rausfadet, darf ihre Antwort-Hälfte nicht
  hässlich zusammenklappen. (Bekannte Unsicherheit im neuen Aufbau — falls es auffällt, notieren,
  ist ein Einzeiler-Kandidat.)

## 2. Tempo — keine Zwangspause mehr

- [ ] **2a** Mehrere Karten so schnell wie möglich durcharbeiten (Space, 2, Space, 2, …).
  Es darf kein blockiertes Warten nach "Gewusst!" geben; jede Karte muss aber erst
  aufgedeckt werden.
- [ ] **2b** Doppel-Tap-Schutz: Auf aufgedeckter Karte zweimal blitzschnell "Gewusst!" tippen
  (oder mit zwei Fingern gleichzeitig). Es darf **nur eine** Karte bewertet werden — die
  nächste, noch nicht aufgedeckte Karte darf nicht mitbewertet werden. Zähler "x von y" prüfen.
- [ ] **2c** Grüner Flash erscheint bei "Gewusst!", stört aber nicht (nicht klickblockierend).

## 3. Swipe-Steuerung

- [ ] **3a** Aufgedeckte Karte langsam nach rechts ziehen: grünes Häkchen blendet sich ein,
  Karte neigt sich leicht. Loslassen nach >⅓ Bildschirmbreite → Karte fliegt raus = "Gewusst!".
- [ ] **3b** Nach links: rotes X = "Nochmal" (im Vokabeltest: oranges Wiederholen-Symbol).
- [ ] **3c** Kurz ziehen und loslassen (unter Schwelle) → Karte federt zurück, nichts bewertet.
- [ ] **3d** Schneller kurzer Flick (wenig Weg, hohe Geschwindigkeit) → löst ebenfalls aus.
- [ ] **3e** *(mit OpenAI-Key)* TTS-Button "Anhören" auf der Karte bleibt normal tippbar.
- [ ] **3f** *(mit OpenAI-Key)* Drag, der **auf** dem TTS-Button startet, wischt die Karte
  (und feuert kein TTS) — akzeptables Verhalten, nur bewusst abnicken.
- [ ] **3g** Nicht aufgedeckte Karte: Wischen bewegt nichts, bewertet nichts.

## 4. 2-Button-System & SRS-Wirkung

- [ ] **4a** Buttons: nur noch "Nochmal" (rot, X, "Später") und "Gewusst!" (grün, Haken,
  "Fertig"). "Fast" ist weg — auch im Vokabeltest unverändert 2 Buttons.
- [ ] **4b** "Nochmal"-Karte kommt **ans Ende** des Stapels (nicht sofort wieder). Session
  endet erst, wenn alles auf "Gewusst!" steht.
- [ ] **4c** Zusammenfassung: nur Zeilen "Gewusst" (grün) und "Nochmal" (rot). Eine Karte, die
  einmal "Nochmal" war und später gewusst wurde, zählt als "Nochmal".
- [ ] **4d** SRS-Reset: Vokabel mit Status "Bekannt" (in Vokabelliste manuell setzen) in der
  Session einmal "Nochmal" geben, später "Gewusst!". Danach in der Vokabelliste: Status
  "Lernen", fällig morgen.
- [ ] **4e** Tastatur: Space = aufdecken, 1 = Nochmal, 2 = Gewusst. Taste 3 tut **nichts**.

## 5. Session-Ende & Abbruch

- [ ] **5a** Letzte Karte "Gewusst!": Flash + Rausfliegen bleiben sichtbar, nach ~einer halben
  Sekunde erscheint die Zusammenfassung. Kein leerer Zwischen-Screen mit "Aufdecken"-Button.
- [ ] **5b** Session mittendrin mit "Beenden" abbrechen → kein Absturz, Teilfortschritt in der
  Statistik gespeichert.
- [ ] **5c** Direkt nach der letzten "Gewusst!"-Bewertung (im Halbsekunden-Fenster) "Beenden"
  tippen → kein Absturz, keine doppelte Session in der Statistik.

## 6. RTL — Arabisch

- [ ] **6a** iOS-Einstellungen → VocabSpark → Sprache → Arabisch. Session starten: Buttons
  bleiben physisch **rot links / grün rechts**, Swipe rechts = Gewusst (deckungsgleich mit
  den Badges). Rest der UI normal gespiegelt.

## 7. Smarte Erinnerungen (v1.1.1 — noch nie am Gerät getestet!)

- [ ] **7a** Einstellungen → Erinnerung aktivieren → OS-Permission-Dialog erscheint, nach
  "Erlauben" bleibt der Schalter an.
- [ ] **7b** Mit fälligen Vokabeln: Erinnerungszeit auf 2–3 Minuten in die Zukunft stellen,
  App in den Hintergrund → Notification kommt.
- [ ] **7c** Gegentest: alle Vokabeln "Gewusst!" durchspielen (nichts mehr heute fällig),
  Erinnerungszeit wieder kurz in die Zukunft → **keine** Notification.

## 8. Regressions-Rundumblick (je 30 Sekunden)

- [ ] **8a** Fortschrittsbalken + "x von y" zählen korrekt hoch.
- [ ] **8b** Streak-Anzeige in der Zusammenfassung wie gewohnt.
- [ ] **8c** Vokabeltest komplett durchspielen: "· n wiederholt"-Zähler, End-Screen.
- [ ] **8d** Fortschritts-Chart aktualisiert sich nach der Session (MasteryEvents).
- [ ] **8e** Einmal iPhone-Simulator (beliebig): Karten-Layout in compact-Größe okay.

## 9. Tester-Fixes vom 2026-07-04 (zweite Runde)

Bereits im Simulator verifiziert (Screenshot-gestützt, 2026-07-04): Richtung "Zufall"
übersteht App-Neustart (Fix 2), Fortschrittsbalken wächst bei "Nochmal" statt zu hängen
(Fix 3), Drag-Selektion über die Auswahlkreise im Vokabeltest funktioniert (Fix 5).
Unit-getestet: Erinnerungs-Planung (Fix 6). Bleibt für Hand am Gerät:

- [ ] **9a** *(mit OpenAI-Key)* TTS-Timing: "Anhören" tippen — sobald die Stimme fertig
  ist, muss der Button **sofort** wieder tippbar sein (vorher: mehrere Sekunden gesperrt,
  weil die volle MP3-Länge inkl. Endstille abgewartet wurde). Mit einem längeren
  Beispielsatz wiederholen.
- [ ] **9b** *(mit OpenAI-Key)* TTS abbrechen: Während der Wiedergabe die Karte bewerten
  → Ton stoppt, nichts hängt, nächste Karte normal bedienbar.
- [ ] **9c** Persistenz komplett: Richtung in Lernsession UND Karten-Filter ("Fällige"/"Alle")
  UND Richtung im Vokabeltest ändern, App aus dem App-Switcher werfen, neu starten —
  alle drei Einstellungen unverändert.
- [ ] **9d** Balken-Gefühl im echten Durchlauf: Session mit vielen "Nochmal" spielen —
  Balken wächst bei jeder Bewertung, springt nie zurück, ist exakt voll wenn die
  Zusammenfassung kommt. Zähler "x von y" zählt weiterhin nur Gemeistertes.
- [ ] **9e** Erinnerung nach Session: Erinnerung aktiv, Zeit ein paar Minuten in die
  Zukunft, dann eine Session abschließen → heute KEINE Notification mehr. Am Folgetag
  (oder Datum vorstellen) mit fälligen Karten → Notification kommt wieder.
- [ ] **9f** Drag-Selektion auf dem Gerät: Im Vokabeltest mit dem Finger über die
  Auswahlkreise streichen — zusammenhängende Auswahl; über bereits gewählte streichen
  wählt ab. Scrollen der Liste (Drag rechts neben den Kreisen) funktioniert weiter.

## Bekannte bewusste Entscheidungen (kein Testbedarf, nur Kontext)

- Swipe-Richtung ist absichtlich **physisch** auch bei RTL (deshalb 6a).
- VoiceOver-Nutzer bewerten über die Buttons; eigene Accessibility-Actions für Swipe sind
  bewusst weggelassen.
- "Nochmal" setzt das SRS-Intervall hart zurück (kein "Fast"-Mittelweg mehr) — Rückbau wäre
  eine Einzeiler-Änderung in `LearningSessionView.rate()` / `SRSEngine`.
