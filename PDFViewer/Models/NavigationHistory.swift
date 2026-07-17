import Foundation

/// Back/forward page-visit history, independent of PDFKit so it is trivially unit-testable.
/// Visiting a new page while not at the end of the stack truncates forward history,
/// matching standard browser-style navigation semantics.
struct NavigationHistory: Equatable {
    private(set) var pages: [Int] = []
    private(set) var currentIndex: Int = -1

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex >= 0 && currentIndex < pages.count - 1 }

    var current: Int? {
        guard pages.indices.contains(currentIndex) else { return nil }
        return pages[currentIndex]
    }

    /// Records a visit to `pageIndex`. Calling this repeatedly with the same value is a no-op,
    /// so simple scroll-driven page updates don't flood the history.
    mutating func recordVisit(to pageIndex: Int) {
        if let current, current == pageIndex { return }
        if currentIndex < pages.count - 1 {
            pages.removeSubrange((currentIndex + 1)...)
        }
        pages.append(pageIndex)
        currentIndex = pages.count - 1
    }

    mutating func goBack() -> Int? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return pages[currentIndex]
    }

    mutating func goForward() -> Int? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return pages[currentIndex]
    }

    mutating func reset() {
        pages.removeAll()
        currentIndex = -1
    }
}
