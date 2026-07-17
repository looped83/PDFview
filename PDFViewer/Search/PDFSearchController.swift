import PDFKit
import Observation

/// Non-blocking full-text search over a `PDFKit.PDFDocument`.
///
/// Uses `PDFDocument.beginFindString(withOptions:)`, which searches asynchronously and
/// delivers matches incrementally via notifications, rather than the synchronous
/// `findString` API — so a search across a multi-thousand-page document never blocks
/// the UI, and can be cancelled mid-flight (e.g. when the user types a new query).
///
/// Deliberately holds no reference to `PDFView`: it only produces `PDFSelection` results.
/// Scrolling to / highlighting a result is the caller's responsibility (see
/// `PDFDocumentState.revealSearchSelection`), which keeps this type simple to unit test.
@Observable
@MainActor
final class PDFSearchController {

    private(set) var queryText: String = ""
    private(set) var results: [PDFSelection] = []
    private(set) var currentResultIndex: Int?
    private(set) var isSearching: Bool = false
    private(set) var hasSearched: Bool = false

    private weak var document: PDFKit.PDFDocument?
    private var matchObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?

    var statusText: String {
        if isSearching && results.isEmpty { return String(localized: "Suche…") }
        guard hasSearched else { return "" }
        if results.isEmpty { return String(localized: "Keine Treffer") }
        if let currentResultIndex {
            return String(localized: "\(currentResultIndex + 1) von \(results.count)")
        }
        return String(localized: "\(results.count) Treffer")
    }

    /// Rebinds the controller to a (possibly new) document and clears any previous search.
    func attach(to document: PDFKit.PDFDocument?) {
        clear()
        self.document = document
    }

    func search(for query: String) {
        cancelActiveSearch()
        queryText = query

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let document, !trimmed.isEmpty else {
            results = []
            currentResultIndex = nil
            hasSearched = false
            return
        }

        results = []
        currentResultIndex = nil
        hasSearched = true
        isSearching = true
        subscribe(to: document)
        document.beginFindString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
    }

    func cancelActiveSearch() {
        document?.cancelFindString()
        unsubscribe()
        isSearching = false
    }

    func clear() {
        cancelActiveSearch()
        queryText = ""
        results = []
        currentResultIndex = nil
        hasSearched = false
    }

    @discardableResult
    func selectNext() -> PDFSelection? {
        guard !results.isEmpty else { return nil }
        let next = ((currentResultIndex ?? -1) + 1) % results.count
        currentResultIndex = next
        return results[next]
    }

    @discardableResult
    func selectPrevious() -> PDFSelection? {
        guard !results.isEmpty else { return nil }
        let previous = ((currentResultIndex ?? 0) - 1 + results.count) % results.count
        currentResultIndex = previous
        return results[previous]
    }

    // MARK: - Notifications

    private func subscribe(to document: PDFKit.PDFDocument) {
        let center = NotificationCenter.default
        matchObserver = center.addObserver(
            forName: .PDFDocumentDidFindMatch,
            object: document,
            queue: .main
        ) { [weak self] notification in
            guard let selection = notification.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else { return }
            // Delivery is on the main queue (see `queue: .main` above), so this is safe.
            nonisolated(unsafe) let foundSelection = selection
            MainActor.assumeIsolated {
                self?.results.append(foundSelection)
            }
        }
        endObserver = center.addObserver(
            forName: .PDFDocumentDidEndFind,
            object: document,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isSearching = false
            }
        }
    }

    private func unsubscribe() {
        let center = NotificationCenter.default
        if let matchObserver { center.removeObserver(matchObserver) }
        if let endObserver { center.removeObserver(endObserver) }
        matchObserver = nil
        endObserver = nil
    }
}
