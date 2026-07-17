import Testing
import Foundation
@testable import PDFViewer

struct PDFFileClassificationTests {

    @Test func validPDFDataClassifiesAsLoaded() throws {
        let document = TestPDFFactory.makeDocument(pageCount: 3)
        let data = try #require(document.dataRepresentation())

        guard case .loaded(let loaded) = PDFFileClassification.classify(data: data) else {
            Issue.record("Expected .loaded")
            return
        }
        #expect(loaded.pageCount == 3)
    }

    @Test func passwordProtectedDataClassifiesAsLocked() throws {
        let url = try TestPDFFactory.writeLockedFile(pageCount: 2, userPassword: "geheim")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        guard case .locked = PDFFileClassification.classify(data: data) else {
            Issue.record("Expected .locked")
            return
        }
    }

    @Test func garbageDataClassifiesAsCorrupted() {
        let data = Data("Dies ist keine PDF-Datei.".utf8)
        guard case .corrupted = PDFFileClassification.classify(data: data) else {
            Issue.record("Expected .corrupted")
            return
        }
    }

    @Test func emptyDataClassifiesAsCorrupted() {
        guard case .corrupted = PDFFileClassification.classify(data: Data()) else {
            Issue.record("Expected .corrupted")
            return
        }
    }
}
