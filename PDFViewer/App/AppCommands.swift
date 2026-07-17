import SwiftUI

/// Menu bar commands for the active document window. Reads the focused window's
/// `PDFDocumentState` via `FocusedValue` (published in `PDFViewerContainer`), so these
/// commands act on whichever document window is currently key — and disable themselves
/// cleanly when no document window is focused (e.g. the welcome window).
///
/// `⌘O` (Open), `⌘W` (Close Window), and Enter/Exit Full Screen are provided automatically
/// by `DocumentGroup` and the window system and are intentionally not duplicated here.
struct AppCommands: Commands {
    @FocusedValue(\.pdfDocumentState) private var documentState

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Seitenleiste ein-/ausblenden") {
                documentState?.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
            .disabled(documentState == nil)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Suchen…") {
                documentState?.activateSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(documentState == nil)
        }

        CommandGroup(after: .saveItem) {
            Button("Kopie speichern unter…") {
                documentState?.saveCopy()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(documentState == nil)

            Button("Im Finder anzeigen") {
                documentState?.revealInFinder()
            }
            .disabled(documentState == nil)
        }

        CommandGroup(after: .printItem) {
            Button("Drucken…") {
                documentState?.printDocument()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(documentState == nil)
        }

        CommandMenu("Darstellung") {
            Button("Vergrößern") { documentState?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(documentState == nil)
            Button("Verkleinern") { documentState?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(documentState == nil)

            Divider()

            Button("Tatsächliche Größe") { documentState?.setActualSize() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(documentState == nil)
            Button("Ganze Seite") { documentState?.setFitPage() }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(documentState == nil)
            Button("An Breite anpassen") { documentState?.setFitWidth() }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(documentState == nil)

            Divider()

            ForEach(PageLayoutMode.allCases) { mode in
                Button(mode.label) {
                    documentState?.layoutMode = mode
                }
                .disabled(documentState == nil)
            }
        }

        CommandMenu("Gehe zu") {
            Button("Erste Seite") { documentState?.goToFirstPage() }
                .disabled(documentState == nil)
            Button("Vorherige Seite") { documentState?.goToPreviousPage() }
                .disabled(documentState == nil)
            Button("Nächste Seite") { documentState?.goToNextPage() }
                .disabled(documentState == nil)
            Button("Letzte Seite") { documentState?.goToLastPage() }
                .disabled(documentState == nil)

            Divider()

            Button("Zurück") { documentState?.goBackInHistory() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!(documentState?.navigationHistory.canGoBack ?? false))
            Button("Vor") { documentState?.goForwardInHistory() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!(documentState?.navigationHistory.canGoForward ?? false))
        }
    }
}
