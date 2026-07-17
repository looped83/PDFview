import Testing
@testable import PDFViewer

struct PageNumberFormatterTests {

    @Test func pageStatusFormatsCurrentAndTotal() {
        #expect(PageNumberFormatter.pageStatus(current: 0, total: 10) == "1 / 10")
        #expect(PageNumberFormatter.pageStatus(current: 9, total: 10) == "10 / 10")
    }

    @Test func pageStatusHandlesEmptyDocument() {
        #expect(PageNumberFormatter.pageStatus(current: 0, total: 0) == "–")
    }

    @Test func validatedPageIndexAcceptsInRangeValues() {
        #expect(PageNumberFormatter.validatedPageIndex(from: "1", pageCount: 10) == 0)
        #expect(PageNumberFormatter.validatedPageIndex(from: "10", pageCount: 10) == 9)
        #expect(PageNumberFormatter.validatedPageIndex(from: "5", pageCount: 10) == 4)
    }

    @Test func validatedPageIndexRejectsOutOfRangeOrMalformedValues() {
        #expect(PageNumberFormatter.validatedPageIndex(from: "0", pageCount: 10) == nil)
        #expect(PageNumberFormatter.validatedPageIndex(from: "11", pageCount: 10) == nil)
        #expect(PageNumberFormatter.validatedPageIndex(from: "-1", pageCount: 10) == nil)
        #expect(PageNumberFormatter.validatedPageIndex(from: "abc", pageCount: 10) == nil)
        #expect(PageNumberFormatter.validatedPageIndex(from: "", pageCount: 10) == nil)
        #expect(PageNumberFormatter.validatedPageIndex(from: "3", pageCount: 0) == nil)
    }
}
