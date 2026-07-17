import Testing
import PDFKit
@testable import PDFViewer

struct DocumentInfoServiceTests {

    @Test func makeInfoReportsPageCountAndSelectableText() {
        let document = TestPDFFactory.makeDocument(pageCount: 3, titlePrefix: "Bericht")
        let info = DocumentInfoService.makeInfo(document: document, fileURL: nil, fallbackTitle: "Fallback")

        #expect(info.pageCount == 3)
        #expect(info.hasSelectableText)
        #expect(!info.isEncrypted)
    }

    @Test func makeInfoUsesFallbackTitleWhenDocumentHasNoTitleAttribute() {
        let document = TestPDFFactory.makeDocument(pageCount: 1)
        let info = DocumentInfoService.makeInfo(document: document, fileURL: nil, fallbackTitle: "Mein Dokument")
        #expect(info.title == "Mein Dokument")
    }

    @Test func makeInfoReportsUnknownFileSizeWithoutAURL() {
        let document = TestPDFFactory.makeDocument(pageCount: 1)
        let info = DocumentInfoService.makeInfo(document: document, fileURL: nil, fallbackTitle: "Doc")
        #expect(info.fileSizeDescription == "Unbekannt")
    }
}
