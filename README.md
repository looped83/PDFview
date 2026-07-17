# PDF Viewer

Ein vollständig nativer, leichtgewichtiger PDF-Viewer für macOS 26 — gebaut mit
Swift, SwiftUI, AppKit und PDFKit. Keine Electron/WebView-Oberfläche, keine
eigene PDF-Rendering-Engine, keine Telemetrie, keine Netzwerkzugriffe.

> **Hinweis zum Stand dieses Repositories:** Der gesamte App-Code, die Tests,
> die Build-/Signier-/Notarisierungs-Skripte und diese Dokumentation wurden in
> einer Linux-Sandbox ohne Xcode/Swift-Toolchain erstellt. Der Code wurde
> **nicht** in Xcode kompiliert oder ausgeführt. Siehe
> ["Bekannte Einschränkungen"](#bekannte-einschränkungen) unten, bevor du das
> Projekt zum ersten Mal öffnest.

## Screenshots

_(Platzhalter — Screenshots werden ergänzt, sobald die App erstmals auf einem
Mac gebaut und ausgeführt wurde.)_

| Leerer Zustand | Dokumentansicht | Suche |
|---|---|---|
| `docs/screenshots/empty-state.png` | `docs/screenshots/document-view.png` | `docs/screenshots/search.png` |

## Funktionsübersicht

- Öffnen über Dateiauswahldialog, Doppelklick/„Öffnen mit" im Finder,
  Drag-and-drop (Fenster und Dock-Symbol), mehrere Dateien gleichzeitig
- Passwortgeschützte PDFs mit eigenem Entsperr-Bildschirm
- Einzelseite, fortlaufende Einzelseite, Doppelseite, fortlaufende Doppelseite
- Zoom: tatsächliche Größe, ganze Seite, an Breite anpassen, freier Zoom
- Seitennavigation inkl. direkter Seitenzahleingabe und Zurück/Vor-Verlauf
- Seitenleiste mit verzögert geladenen, gecachten Miniaturen und Inhaltsverzeichnis
- Nicht blockierende, abbrechbare Volltextsuche mit Trefferanzeige und Hervorhebung
- Textauswahl, Kopieren, Öffnen von internen und externen Links
- Drucken, Kopie speichern, im Finder anzeigen — nie wird die Originaldatei verändert
- Zuletzt-geöffnet-Unterstützung über macOS sowie lokale Speicherung der letzten
  Seite/des Zooms pro Datei (keine Dokumentinhalte)
- Mehrere Fenster, native Vollbilddarstellung
- Volle Tastaturbedienung, VoiceOver-Unterstützung

## Systemvoraussetzungen

- **macOS 26** oder neuer (Deployment Target)
- **Xcode 26** oder neuer (für Swift 6 / die aktuellen SwiftUI-, PDFKit- und
  Observation-APIs, die dieses Projekt verwendet)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) zum Erzeugen des
  `.xcodeproj` aus `project.yml`:
  ```sh
  brew install xcodegen
  ```
- Für signierte Releases zusätzlich: ein gültiges „Developer ID Application"-
  Zertifikat und eine Apple-ID mit App-spezifischem Passwort bzw. ein
  App Store Connect API-Key (siehe [Notarisierung](#notarisierung))

Keine weiteren Abhängigkeiten. Es wird kein CocoaPods, Carthage oder Swift
Package mit Drittanbieter-Code verwendet.

## Projektstruktur

```
PDFViewer/
├── project.yml                     # XcodeGen-Spezifikation — einzige Quelle
│                                    # der Wahrheit für das Xcode-Projekt
├── PDFViewer/
│   ├── App/                        # App-Einstiegspunkt, Menü-Commands, AppDelegate,
│   │                                # Willkommensfenster (Leerzustand ohne Dokument)
│   ├── Document/                   # Dateimodell (PDFFileDocument) und Fenster-
│   │                                # Betrachtungszustand (PDFDocumentState)
│   ├── Viewer/                     # PDFView-Bridge, Container, Toolbar, Zoom-/
│   │                                # Layout-Modelle, Leer-/Fehlerzustände
│   ├── Sidebar/                    # Miniaturen- und Inhaltsverzeichnis-Ansicht
│   ├── Search/                     # Asynchrone Volltextsuche
│   ├── Models/                     # Reine, unabhängig testbare Datentypen
│   ├── Services/                   # Positions-Speicherung, Passwort-Dialog,
│   │                                # Dokumentinfo, Dateien öffnen
│   ├── Utilities/                  # Kleine Helfer (Seitenformatierung, Drag&Drop)
│   └── Resources/                  # Entitlements, Asset-Katalog (App-Icon, Akzentfarbe)
├── PDFViewerTests/                 # Unit-Tests (Swift Testing) + generierte
│                                    # Test-PDF-Fabrik (keine Binär-Fixtures im Repo)
├── PDFViewerUITests/                # UI-Tests (XCTest/XCUITest) für die Kernabläufe
├── scripts/                        # Reproduzierbare Build-/Signier-/DMG-Skripte
└── docs/
    ├── architecture.md             # Kurze Sammlung der wichtigsten Entscheidungen
    └── release-checklist.md        # Checkliste vor jedem Release
```

Details zu den wichtigsten Architekturentscheidungen: [`docs/architecture.md`](docs/architecture.md).

## Lokale Entwicklung

```sh
git clone <repo-url> PDFViewer
cd PDFViewer
xcodegen generate      # erzeugt PDFViewer.xcodeproj aus project.yml
open PDFViewer.xcodeproj
```

In Xcode: Scheme `PDFViewer` auswählen, `⌘R` zum Ausführen.

`PDFViewer.xcodeproj` wird **nicht** versioniert (siehe `.gitignore`) — es ist
vollständig aus `project.yml` reproduzierbar. Nach jeder Änderung an
`project.yml` einfach erneut `xcodegen generate` ausführen.

## Build-Anleitung

### Über Xcode

`⌘B` (Debug) bzw. Product → Archive für einen Release-Build.

### Über die Kommandozeile

```sh
scripts/build-release.sh
```

Das Skript:
1. erzeugt das Xcode-Projekt neu (`xcodegen generate`),
2. entfernt alte Build-Artefakte (`build/`, `dist/`),
3. baut das Scheme `PDFViewer` in der Konfiguration `Release`,
4. kopiert die erzeugte `PDFViewer.app` nach `dist/PDFViewer.app`,
5. bricht bei jedem Fehler mit einem Exit-Code ungleich null ab.

## Tests ausführen

### Über Xcode

`⌘U` führt alle Unit- und UI-Tests aus.

### Über die Kommandozeile

```sh
xcodegen generate
xcodebuild test \
  -project PDFViewer.xcodeproj \
  -scheme PDFViewer \
  -destination "platform=macOS"
```

Die Unit-Tests verwenden [Swift Testing](https://developer.apple.com/documentation/testing)
und generieren ihre Test-PDFs zur Laufzeit über `TestPDFFactory`
(`PDFViewerTests/Fixtures/TestPDFFactory.swift`) — es sind keine
urheberrechtlich relevanten Binärdateien im Repository. Die UI-Tests
(`PDFViewerUITests`) decken die Kernabläufe ab: App-Start, PDF öffnen,
Seiten wechseln, Seitenleiste öffnen, Suche ausführen, Zoom ändern, Fenster
schließen — sie starten die App mit einer selbst generierten Test-PDF über die
Umgebungsvariable `UITEST_PDF_PATH`, um den nativen Dateiauswahldialog nicht
automatisieren zu müssen (was mit XCUITest nicht zuverlässig möglich ist).

Eine manuelle Prüf-Checkliste (große PDFs, gescannte PDFs, VoiceOver, Hell/Dunkel
usw.) befindet sich in [`docs/release-checklist.md`](docs/release-checklist.md).

## Erstellung der `.app`

```sh
scripts/build-release.sh
```
→ `dist/PDFViewer.app`

## Erstellung der `.dmg`

```sh
scripts/create-dmg.sh
```
→ `dist/PDFViewer.dmg`, enthält `PDFViewer.app` und einen symbolischen Link
auf `/Applications`, mit einfachem Finder-Icon-Layout. Verwendet ausschließlich
Bordmittel (`hdiutil`, `osascript`, `iconutil`, `sips`) — kein Drittanbieter-Tool.

Setzt eine bereits gebaute `dist/PDFViewer.app` voraus.

## Code-Signing-Anleitung

### Lokaler Entwicklungsmodus (kein Zertifikat nötig)

`scripts/build-release.sh` erzeugt einen unsignierten bzw. ad-hoc-signierten
Build (der Standard-Signaturmodus von Xcode für lokale Builds ohne
konfiguriertes Team). Diese `.app` lässt sich lokal starten und die `.dmg`
lässt sich lokal erzeugen.

**Gatekeeper-Hinweis:** Beim ersten Start einer nicht mit einer Developer-ID
signierten bzw. nicht notarisierten App zeigt macOS eine Warnung
("kann nicht geöffnet werden, da der Entwickler nicht verifiziert werden
kann" bzw. den Hinweis zu heruntergeladenen Apps). Für den eigenen,
lokal gebauten Build: Rechtsklick → Öffnen, oder
Systemeinstellungen → Datenschutz & Sicherheit → "Trotzdem öffnen".
Das ist bei lokalen Entwickler-Builds normal und kein Fehler.

### Signierter Distributionsmodus

Zertifikate, Team-IDs und Zugangsdaten werden **niemals** im Repository
gespeichert — ausschließlich über Umgebungsvariablen bzw. deine lokale,
nicht versionierte Konfiguration.

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Dein Name (TEAMID1234)"
scripts/sign-app.sh
```

Das Skript signiert `dist/PDFViewer.app` mit Hardened Runtime, den
Entitlements aus `PDFViewer/Resources/PDFViewer.entitlements`, einem
Secure Timestamp, und verifiziert die Signatur anschließend automatisch mit:

```sh
codesign --verify --deep --strict --verbose=2 dist/PDFViewer.app
```

## Notarisierung

1. Einmalig ein Schlüsselbund-Profil für `notarytool` anlegen (Zugangsdaten
   landen ausschließlich lokal im Schlüsselbund, nicht im Repository):
   ```sh
   xcrun notarytool store-credentials "pdfviewer-notary" \
     --apple-id "deine-apple-id@example.com" \
     --team-id "TEAMID1234" \
     --password "app-spezifisches-passwort"
   ```
2. Notarisierung anstoßen:
   ```sh
   export NOTARY_KEYCHAIN_PROFILE="pdfviewer-notary"
   scripts/notarize-app.sh
   ```
   Das Skript archiviert die App, reicht sie bei Apple ein, wartet auf das
   Ergebnis, heftet das Notarisierungs-Ticket an (`stapler staple`) und
   validiert es (`stapler validate`).
3. Falls du auch eine `.dmg` verteilst: **danach erneut**
   `scripts/create-dmg.sh` ausführen, damit die DMG die geheftete App enthält.

Abschließende Prüfung des gesamten Release-Artefakts:

```sh
scripts/verify-release.sh
```

prüft Bundle-Struktur, Code-Signatur (`codesign --verify --deep --strict`),
Gatekeeper-Freigabe (`spctl --assess --type execute`) und das
Notarisierungs-Ticket (`xcrun stapler validate`) — sowohl für die `.app` als
auch, falls vorhanden, die `.dmg`.

## Datenschutz

- Keine Netzwerkzugriffe, keine Telemetrie, keine Analytics, kein
  Drittanbieter-Crash-Reporting.
- Kein Benutzerkonto, keine Cloud-Synchronisierung.
- Dateinamen und Dokumentinhalte verlassen niemals das Gerät.
- Es werden **keine** vollständigen Dokumentinhalte dauerhaft gespeichert.
  Lokal gespeichert wird ausschließlich — pro Datei, in `UserDefaults` — die
  zuletzt angezeigte Seitenzahl und der Zoomfaktor, identifiziert über
  Dateipfad und Dateigröße (siehe `LastPositionStore`,
  [`docs/architecture.md`](docs/architecture.md) Abschnitt 9).
- App Sandbox ist aktiviert.

## Verwendete Entitlements

Siehe [`PDFViewer/Resources/PDFViewer.entitlements`](PDFViewer/Resources/PDFViewer.entitlements):

| Entitlement | Zweck |
|---|---|
| `com.apple.security.app-sandbox` | App Sandbox aktiviert. |
| `com.apple.security.files.user-selected.read-write` | Lesezugriff auf vom Nutzer geöffnete PDFs (Dateiauswahl, Drag-and-drop, Finder) **und** Schreibzugriff auf das vom Nutzer über den Sicherndialog gewählte Ziel bei „Kopie speichern unter…". Die Originaldatei wird dabei nie beschrieben. |
| `com.apple.security.print` | Nativer Druckdialog. |

Kein App-Scope-Bookmark-Entitlement: Die native „Zuletzt geöffnet"-Funktion
wird vom System selbst über eigene, App-unabhängige Security-Scoped Bookmarks
bereitgestellt.

## Bekannte Einschränkungen

- **Nicht in Xcode gebaut oder getestet.** Dieses Repository wurde in einer
  Linux-Umgebung ohne Swift-/Xcode-Toolchain erstellt. Der gesamte Code wurde
  nach bestem Wissen gegen die dokumentierten SwiftUI-/AppKit-/PDFKit-APIs
  geschrieben, aber **kein Build, kein Testlauf, keine Signierung, keine
  Notarisierung und keine DMG-Erstellung wurde tatsächlich ausgeführt oder
  verifiziert.** Vor dem ersten produktiven Einsatz: `xcodegen generate`,
  einen Build in Xcode 26 durchführen, Compiler-Fehler/-Warnungen beheben,
  alle Tests laufen lassen, und die Checkliste in
  [`docs/release-checklist.md`](docs/release-checklist.md) abarbeiten.
- **App-Icon ist ein Platzhalter.** `AppIcon-1024.png` wurde programmatisch
  generiert und sollte vor einer echten Veröffentlichung durch ein finales
  Design ersetzt werden (idealerweise über Icon Composer für die aktuelle
  macOS-Icon-Formsprache).
- **Keine echten Screenshots.** Die Platzhalter oben müssen nach dem ersten
  lauffähigen Build ersetzt werden.
- **OCR ist bewusst nicht enthalten.** Gescannte PDFs ohne Textebene bleiben
  ohne Suchtreffer und ohne auswählbaren Text — das ist beabsichtigtes
  Verhalten, keine fehlende Funktion.
- **Tab-Unterstützung nicht implementiert.** Laut Vorgabe nachrangig
  gegenüber Stabilität und Mehrfensterfähigkeit; die App unterstützt volle
  Mehrfensterfähigkeit ohne native Fenster-Tabs.

## Lizenz

[MIT](LICENSE)
