import Testing
import PDFKit
@testable import PDFViewer

@MainActor
struct PDFDocumentStateTests {

    private func makeState(pageCount: Int) -> PDFDocumentState {
        let document = TestPDFFactory.makeDocument(pageCount: pageCount)
        let fileDocument = PDFFileDocument(pdfDocument: document)
        let state = PDFDocumentState(fileDocument: fileDocument, fileURL: nil)
        let pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        pdfView.document = document
        state.attach(pdfView: pdfView)
        return state
    }

    @Test func initialStateReflectsDocumentPageCount() {
        let state = makeState(pageCount: 12)
        #expect(state.pageCount == 12)
        #expect(state.currentPageIndex == 0)
    }

    @Test func goToPageUpdatesCurrentPageAndFieldText() {
        let state = makeState(pageCount: 10)
        state.goToPage(4)
        #expect(state.currentPageIndex == 4)
        #expect(state.pageNumberFieldText == "5")
    }

    @Test func goToPageClampsOutOfRangeIndices() {
        let state = makeState(pageCount: 5)
        state.goToPage(999)
        #expect(state.currentPageIndex == 4)

        state.goToPage(-10)
        #expect(state.currentPageIndex == 0)
    }

    @Test func firstPreviousNextLastNavigation() {
        let state = makeState(pageCount: 5)
        state.goToPage(2)

        state.goToNextPage()
        #expect(state.currentPageIndex == 3)

        state.goToPreviousPage()
        #expect(state.currentPageIndex == 2)

        state.goToFirstPage()
        #expect(state.currentPageIndex == 0)

        state.goToLastPage()
        #expect(state.currentPageIndex == 4)
    }

    @Test func submitPageNumberFieldNavigatesOnValidInput() {
        let state = makeState(pageCount: 20)
        state.pageNumberFieldText = "15"
        state.submitPageNumberField()
        #expect(state.currentPageIndex == 14)
    }

    @Test func submitPageNumberFieldResetsOnInvalidInput() {
        let state = makeState(pageCount: 20)
        state.goToPage(3)
        state.pageNumberFieldText = "not a number"
        state.submitPageNumberField()
        #expect(state.currentPageIndex == 3)
        #expect(state.pageNumberFieldText == "4")
    }

    @Test func backAndForwardHistoryFollowsExplicitNavigation() {
        let state = makeState(pageCount: 10)
        state.goToPage(1)
        state.goToPage(5)
        state.goToPage(9)

        state.goBackInHistory()
        #expect(state.currentPageIndex == 5)

        state.goBackInHistory()
        #expect(state.currentPageIndex == 1)

        state.goForwardInHistory()
        #expect(state.currentPageIndex == 5)
    }

    @Test func sidebarTogglesVisibility() {
        let state = makeState(pageCount: 1)
        let initial = state.sidebarVisible
        state.toggleSidebar()
        #expect(state.sidebarVisible == !initial)
    }

    @Test func dismissSearchClearsQueryAndResults() {
        let state = makeState(pageCount: 1)
        state.isSearchActive = true
        state.dismissSearch()
        #expect(!state.isSearchActive)
        #expect(state.search.queryText.isEmpty)
        #expect(state.search.results.isEmpty)
    }
}
