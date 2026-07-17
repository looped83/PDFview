import Testing
import Foundation
@testable import PDFViewer

@MainActor
struct PDFFileDocumentUnlockTests {

    @Test func correctPasswordUnlocksDocument() throws {
        let url = try TestPDFFactory.writeLockedFile(pageCount: 4, userPassword: "geheim")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        let document = PDFFileDocument(encryptedData: data)
        #expect(document.isLocked)
        #expect(document.pdfDocument == nil)

        let success = document.unlock(password: "geheim")

        #expect(success)
        #expect(!document.isLocked)
        #expect(document.pdfDocument?.pageCount == 4)
    }

    @Test func incorrectPasswordFailsAndStaysLocked() throws {
        let url = try TestPDFFactory.writeLockedFile(pageCount: 2, userPassword: "geheim")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)

        let document = PDFFileDocument(encryptedData: data)
        let success = document.unlock(password: "falsch")

        #expect(!success)
        #expect(document.isLocked)
        #expect(document.pdfDocument == nil)
    }
}
