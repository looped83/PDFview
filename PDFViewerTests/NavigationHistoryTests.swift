import Testing
@testable import PDFViewer

struct NavigationHistoryTests {

    @Test func recordingVisitsTracksCurrentPage() {
        var history = NavigationHistory()
        history.recordVisit(to: 0)
        history.recordVisit(to: 4)
        #expect(history.current == 4)
    }

    @Test func duplicateConsecutiveVisitsAreNotDuplicated() {
        var history = NavigationHistory()
        history.recordVisit(to: 2)
        history.recordVisit(to: 2)
        #expect(history.pages == [2])
    }

    @Test func backAndForwardNavigateHistory() {
        var history = NavigationHistory()
        history.recordVisit(to: 0)
        history.recordVisit(to: 5)
        history.recordVisit(to: 9)

        #expect(history.canGoBack)
        #expect(history.goBack() == 5)
        #expect(history.goBack() == 0)
        #expect(!history.canGoBack)
        #expect(history.goBack() == nil)

        #expect(history.canGoForward)
        #expect(history.goForward() == 5)
        #expect(history.goForward() == 9)
        #expect(!history.canGoForward)
    }

    @Test func visitingAfterGoingBackTruncatesForwardHistory() {
        var history = NavigationHistory()
        history.recordVisit(to: 0)
        history.recordVisit(to: 5)
        history.recordVisit(to: 9)
        _ = history.goBack() // -> 5, at index 1 of [0,5,9]

        history.recordVisit(to: 20)

        #expect(history.pages == [0, 5, 20])
        #expect(!history.canGoForward)
    }

    @Test func resetClearsHistory() {
        var history = NavigationHistory()
        history.recordVisit(to: 1)
        history.recordVisit(to: 2)
        history.reset()
        #expect(history.pages.isEmpty)
        #expect(history.current == nil)
        #expect(!history.canGoBack)
        #expect(!history.canGoForward)
    }
}
