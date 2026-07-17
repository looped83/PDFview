import Foundation
import PDFKit

/// Pure classification of raw file bytes into "opened", "needs a password", or
/// "corrupted/unsupported" — pulled out of `PDFFileDocument.init(configuration:)` so it
/// can be unit tested directly with plain `Data`, without needing SwiftUI's
/// `FileDocumentReadConfiguration`/`FileWrapper` machinery in the test target.
enum PDFFileClassification {
    case loaded(PDFKit.PDFDocument)
    case locked
    case corrupted

    static func classify(data: Data) -> PDFFileClassification {
        guard let document = PDFKit.PDFDocument(data: data) else { return .corrupted }
        return document.isLocked ? .locked : .loaded(document)
    }
}
