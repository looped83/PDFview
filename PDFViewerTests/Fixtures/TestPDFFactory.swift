import AppKit
import PDFKit

/// Generates small, throwaway PDF documents entirely at runtime via Core Graphics — no
/// binary fixtures are checked into the repository, so there is no risk of accidentally
/// committing a copyrighted or oversized test document.
enum TestPDFFactory {

    static func makeDocument(
        pageCount: Int,
        pageSize: CGSize = CGSize(width: 612, height: 792),
        titlePrefix: String = "Testseite"
    ) -> PDFKit.PDFDocument {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            fatalError("Could not create PDF data consumer")
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            fatalError("Could not create PDF context")
        }

        for pageIndex in 0..<max(pageCount, 0) {
            context.beginPDFPage(nil)

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

            let text = "\(titlePrefix) \(pageIndex + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 32),
                .foregroundColor: NSColor.black
            ]
            text.draw(at: CGPoint(x: 72, y: pageSize.height - 120), withAttributes: attributes)

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()

        guard let document = PDFKit.PDFDocument(data: data as Data) else {
            fatalError("Failed to build test PDFDocument")
        }
        return document
    }

    static func writeTemporaryFile(pageCount: Int, titlePrefix: String = "Testseite") throws -> URL {
        let document = makeDocument(pageCount: pageCount, titlePrefix: titlePrefix)
        guard let data = document.dataRepresentation() else {
            throw TestPDFFactoryError.dataRepresentationFailed
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try data.write(to: url)
        return url
    }

    static func writeLockedFile(pageCount: Int, userPassword: String) throws -> URL {
        let document = makeDocument(pageCount: pageCount)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: userPassword,
            .ownerPasswordOption: userPassword + "-owner"
        ]
        guard document.write(to: url, withOptions: options) else {
            throw TestPDFFactoryError.encryptedWriteFailed
        }
        return url
    }

    static func writeCorruptFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try Data("Dies ist keine gültige PDF-Datei.".utf8).write(to: url)
        return url
    }
}

enum TestPDFFactoryError: Error {
    case dataRepresentationFailed
    case encryptedWriteFailed
}
