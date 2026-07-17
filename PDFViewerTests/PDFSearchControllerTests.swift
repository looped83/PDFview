import Testing
import PDFKit
@testable import PDFViewer

@MainActor
struct PDFSearchControllerTests {

    private func makeDocumentWithText() -> PDFKit.PDFDocument {
        TestPDFFactory.makeDocument(pageCount: 5, titlePrefix: "Apfelkuchen")
    }

    @Test func searchFindsMatchesAcrossAllPages() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "Apfelkuchen")
        try await waitUntil { !controller.isSearching }

        #expect(controller.results.count == 5)
        #expect(controller.hasSearched)
    }

    @Test func emptyQueryClearsResultsWithoutSearching() {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "")

        #expect(controller.results.isEmpty)
        #expect(!controller.hasSearched)
        #expect(!controller.isSearching)
    }

    @Test func noMatchesReportsEmptyResultState() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "NichtVorhandenesWortXYZ")
        try await waitUntil { !controller.isSearching }

        #expect(controller.results.isEmpty)
        #expect(controller.hasSearched)
        #expect(controller.statusText == "Keine Treffer")
    }

    @Test func selectNextWrapsAroundToFirstResult() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "Apfelkuchen")
        try await waitUntil { !controller.isSearching }
        #expect(controller.results.count == 5)

        let first = controller.selectNext()
        for _ in 0..<4 {
            _ = controller.selectNext()
        }
        let wrapped = controller.selectNext()

        #expect(wrapped === first)
    }

    @Test func selectPreviousWrapsAroundToLastResult() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "Apfelkuchen")
        try await waitUntil { !controller.isSearching }

        let last = controller.selectPrevious()
        #expect(last != nil)
    }

    @Test func clearResetsControllerState() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)

        controller.search(for: "Apfelkuchen")
        try await waitUntil { !controller.isSearching }

        controller.clear()

        #expect(controller.queryText.isEmpty)
        #expect(controller.results.isEmpty)
        #expect(!controller.hasSearched)
    }

    @Test func attachingToNewDocumentClearsPreviousSearch() async throws {
        let document = makeDocumentWithText()
        let controller = PDFSearchController()
        controller.attach(to: document)
        controller.search(for: "Apfelkuchen")
        try await waitUntil { !controller.isSearching }

        controller.attach(to: TestPDFFactory.makeDocument(pageCount: 1, titlePrefix: "Anders"))

        #expect(controller.results.isEmpty)
        #expect(!controller.hasSearched)
    }

    private func waitUntil(timeout: TimeInterval = 3, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                throw TestTimeoutError()
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

private struct TestTimeoutError: Error {}
