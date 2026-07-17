import AppKit
import PDFKit
import Observation

/// Per-window viewing state: current page, zoom, layout mode, sidebar, search, and
/// navigation history. Deliberately separate from `PDFFileDocument` (the file content
/// model) so that scrolling, zooming, or opening the sidebar never touches — or gets
/// confused with — the document's identity or its (potentially large) PDF payload.
///
/// Owns a weak reference to the live `PDFView` so it can drive navigation, zoom, print,
/// and search directly through PDFKit rather than re-implementing any of that logic.
@Observable
@MainActor
final class PDFDocumentState {

    let fileDocument: PDFFileDocument
    let fileURL: URL?
    let search: PDFSearchController

    weak var pdfView: PDFView?

    var currentPageIndex: Int = 0
    var pageCount: Int = 0
    var pageNumberFieldText: String = "1"

    var zoomMode: ZoomMode = .fitPage
    var currentScaleFactor: CGFloat = 1.0

    var layoutMode: PageLayoutMode = .singlePageContinuous

    var sidebarVisible: Bool = true
    var sidebarMode: SidebarMode = .thumbnails

    var isSearchActive: Bool = false

    var isPasswordPromptPresented: Bool
    var passwordAttemptFailed: Bool = false

    var saveCopyErrorMessage: String?
    var exportErrorMessage: String?
    var exportInfoMessage: String?
    var isExporting: Bool = false
    var isExportOptionsPresented: Bool = false
    var exportSettings = PDFExportSettings()

    private(set) var navigationHistory = NavigationHistory()
    private var hasRestoredPosition = false

    init(fileDocument: PDFFileDocument, fileURL: URL?) {
        self.fileDocument = fileDocument
        self.fileURL = fileURL
        self.isPasswordPromptPresented = fileDocument.isLocked
        self.search = PDFSearchController()
        self.pageCount = fileDocument.pdfDocument?.pageCount ?? 0
    }

    // MARK: - Lifecycle

    /// Called once by `PDFKitView.Coordinator` when the underlying `PDFView` is created.
    func attach(pdfView: PDFView) {
        self.pdfView = pdfView
        if let document = pdfView.document {
            documentDidLoad(document)
        }
    }

    /// Called whenever the backing `PDFKit.PDFDocument` changes — initial load or
    /// successful password unlock.
    func documentDidLoad(_ document: PDFKit.PDFDocument) {
        pageCount = document.pageCount
        search.attach(to: document)
        restoreLastPositionIfNeeded()
    }

    private func restoreLastPositionIfNeeded() {
        guard !hasRestoredPosition, let fileURL, let pdfView, let document = pdfView.document else { return }
        hasRestoredPosition = true
        guard let saved = LastPositionStore.shared.position(for: fileURL),
              saved.pageIndex >= 0, saved.pageIndex < document.pageCount,
              let page = document.page(at: saved.pageIndex) else { return }
        pdfView.go(to: page)
        currentPageIndex = saved.pageIndex
        pageNumberFieldText = String(saved.pageIndex + 1)
        navigationHistory.recordVisit(to: saved.pageIndex)
    }

    func persistCurrentPosition() {
        guard let fileURL else { return }
        LastPositionStore.shared.savePosition(
            pageIndex: currentPageIndex,
            zoomScale: Double(currentScaleFactor),
            for: fileURL
        )
    }

    // MARK: - Password

    func submitPassword(_ password: String) {
        if fileDocument.unlock(password: password) {
            isPasswordPromptPresented = false
            passwordAttemptFailed = false
            if let document = fileDocument.pdfDocument {
                pdfView?.document = document
                documentDidLoad(document)
            }
        } else {
            passwordAttemptFailed = true
        }
    }

    // MARK: - Navigation

    func goToPage(_ index: Int, recordHistory: Bool = true) {
        guard let pdfView, let document = pdfView.document, document.pageCount > 0 else { return }
        let clamped = max(0, min(index, document.pageCount - 1))
        guard let page = document.page(at: clamped) else { return }
        pdfView.go(to: page)
        currentPageIndex = clamped
        pageNumberFieldText = String(clamped + 1)
        if recordHistory { navigationHistory.recordVisit(to: clamped) }
    }

    /// Records a page visit driven by the user scrolling directly in `PDFKitView`
    /// (as opposed to an explicit `goToPage` call, which records its own visit).
    func recordHistoryVisit(_ pageIndex: Int) {
        navigationHistory.recordVisit(to: pageIndex)
    }

    func goToFirstPage() { goToPage(0) }
    func goToPreviousPage() { goToPage(currentPageIndex - 1) }
    func goToNextPage() { goToPage(currentPageIndex + 1) }
    func goToLastPage() { goToPage(pageCount - 1) }

    func goBackInHistory() {
        guard let target = navigationHistory.goBack() else { return }
        goToPage(target, recordHistory: false)
    }

    func goForwardInHistory() {
        guard let target = navigationHistory.goForward() else { return }
        goToPage(target, recordHistory: false)
    }

    /// Parses `pageNumberFieldText` (1-based, as shown to the user) and navigates if valid;
    /// otherwise resets the field back to the current page without navigating.
    func submitPageNumberField() {
        guard let value = Int(pageNumberFieldText), value >= 1, value <= max(pageCount, 1) else {
            pageNumberFieldText = String(currentPageIndex + 1)
            return
        }
        goToPage(value - 1)
    }

    // MARK: - Zoom

    func zoomIn() {
        let newScale = min(currentScaleFactor * ZoomMode.stepFactor, ZoomMode.maximumScale)
        zoomMode = .custom(newScale)
    }

    func zoomOut() {
        let newScale = max(currentScaleFactor / ZoomMode.stepFactor, ZoomMode.minimumScale)
        zoomMode = .custom(newScale)
    }

    func setActualSize() { zoomMode = .actualSize }
    func setFitPage() { zoomMode = .fitPage }
    func setFitWidth() { zoomMode = .fitWidth }

    // MARK: - Sidebar & search

    func toggleSidebar() { sidebarVisible.toggle() }

    /// Two-way binding target for the native `.searchable` toolbar field; setting it
    /// kicks off a new (cancellable) search on `search`.
    var searchQueryText: String {
        get { search.queryText }
        set { search.search(for: newValue) }
    }

    func activateSearch() { isSearchActive = true }

    func dismissSearch() {
        isSearchActive = false
        search.clear()
        pdfView?.highlightedSelections = nil
        pdfView?.currentSelection = nil
    }

    /// Keeps all-match highlighting on the live `PDFView` in sync with search results.
    /// Called reactively by the search UI whenever the result set changes.
    func updateSearchHighlights() {
        pdfView?.highlightedSelections = search.results.isEmpty ? nil : search.results
    }

    func revealSearchSelection(_ selection: PDFSelection) {
        guard let pdfView else { return }
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.scrollSelectionToVisible(nil)
        if let page = selection.pages.first, let document = pdfView.document {
            currentPageIndex = document.index(for: page)
            pageNumberFieldText = String(currentPageIndex + 1)
        }
    }

    func searchNext() {
        guard let selection = search.selectNext() else { return }
        revealSearchSelection(selection)
    }

    func searchPrevious() {
        guard let selection = search.selectPrevious() else { return }
        revealSearchSelection(selection)
    }

    // MARK: - Printing & export

    func printDocument() {
        guard let pdfView, let document = pdfView.document else { return }
        guard let operation = document.printOperation(
            for: .shared,
            scalingMode: .pageScaleDownToFit,
            autoRotate: true
        ) else { return }
        operation.run()
    }

    func revealInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    func saveCopy() {
        guard let fileURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileURL.lastPathComponent
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url else { return }
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: fileURL, to: destination)
            } catch {
                self?.saveCopyErrorMessage = String(
                    localized: "Die Kopie konnte nicht gespeichert werden."
                )
            }
        }
    }

    /// Whether an optimized export is currently possible (a viewable document is loaded).
    var canExportOptimized: Bool {
        !isExporting && (pdfView?.document ?? fileDocument.pdfDocument) != nil
    }

    /// Entry point for the toolbar/menu: opens the export-options sheet where the user picks
    /// the method (preserve text vs. rasterize) and compression strength before saving.
    func exportOptimizedPDF() {
        guard canExportOptimized else { return }
        isExportOptionsPresented = true
    }

    /// Called by the options sheet once the user confirms: prompts for a destination, then
    /// exports with the chosen `exportSettings` in the background (see `PDFCompressionService`).
    func confirmOptimizedExport() {
        isExportOptionsPresented = false
        guard canExportOptimized else { return }

        let panel = NSSavePanel()
        let baseName = fileURL?.deletingPathExtension().lastPathComponent
            ?? String(localized: "Dokument")
        panel.nameFieldStringValue = String(localized: "\(baseName) (komprimiert).pdf")
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard let self, response == .OK, let destination = panel.url else { return }
            self.runOptimizedExport(to: destination)
        }
    }

    private func runOptimizedExport(to destination: URL) {
        // Prefer the original file's bytes as the compression source (best quality input).
        // For originally-encrypted documents those bytes are unreadable without the password,
        // so fall back to the already-unlocked in-memory document's data.
        let wasEncrypted = pdfView?.document?.isEncrypted ?? false
        let sourceData: Data?
        if let fileURL, !wasEncrypted {
            sourceData = try? Data(contentsOf: fileURL)
        } else {
            sourceData = (pdfView?.document ?? fileDocument.pdfDocument)?.dataRepresentation()
        }

        guard let sourceData else {
            exportErrorMessage = String(localized: "Der optimierte Export ist fehlgeschlagen.")
            return
        }

        isExporting = true
        let settings = exportSettings
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try PDFCompressionService.writeOptimizedPDF(sourceData: sourceData, to: destination, settings: settings)
                await MainActor.run {
                    self?.isExporting = false
                    self?.exportInfoMessage = Self.message(for: result)
                }
            } catch {
                await MainActor.run {
                    self?.isExporting = false
                    self?.exportErrorMessage = String(
                        localized: "Der optimierte Export ist fehlgeschlagen."
                    )
                }
            }
        }
    }

    private static func message(for result: PDFCompressionService.Result) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        switch result {
        case let .compressed(originalBytes, optimizedBytes):
            let percent = Int((1 - Double(optimizedBytes) / Double(originalBytes)) * 100)
            let from = formatter.string(fromByteCount: Int64(originalBytes))
            let to = formatter.string(fromByteCount: Int64(optimizedBytes))
            return String(localized: "Exportiert: \(from) → \(to) (\(percent) % kleiner).")
        case let .alreadyOptimal(bytes):
            let size = formatter.string(fromByteCount: Int64(bytes))
            return String(localized: "Diese PDF war bereits optimal komprimiert (\(size)); das Original wurde unverändert exportiert.")
        }
    }

    var documentInfo: DocumentInfo? {
        guard let document = pdfView?.document ?? fileDocument.pdfDocument else { return nil }
        let fallbackTitle = fileURL?.deletingPathExtension().lastPathComponent
            ?? String(localized: "Unbenanntes Dokument")
        return DocumentInfoService.makeInfo(document: document, fileURL: fileURL, fallbackTitle: fallbackTitle)
    }
}
