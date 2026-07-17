import Foundation
import PDFKit

struct DocumentInfo: Equatable {
    var title: String
    var author: String?
    var pageCount: Int
    var fileSizeDescription: String
    var hasSelectableText: Bool
    var isEncrypted: Bool
}

enum DocumentInfoService {

    static func makeInfo(document: PDFKit.PDFDocument, fileURL: URL?, fallbackTitle: String) -> DocumentInfo {
        let attributes = document.documentAttributes ?? [:]
        let title = (attributes[PDFDocumentAttribute.titleAttribute] as? String)
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            ?? fallbackTitle
        let author = attributes[PDFDocumentAttribute.authorAttribute] as? String

        var fileSizeDescription = String(localized: "Unbekannt")
        if let fileURL, let size = try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int {
            fileSizeDescription = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }

        let hasSelectableText = documentContainsSelectableText(document)

        return DocumentInfo(
            title: title,
            author: author,
            pageCount: document.pageCount,
            fileSizeDescription: fileSizeDescription,
            hasSelectableText: hasSelectableText,
            isEncrypted: document.isEncrypted
        )
    }

    /// Samples the first few pages for a text layer rather than scanning the whole
    /// document, which would be slow for large scanned PDFs that have none.
    private static func documentContainsSelectableText(_ document: PDFKit.PDFDocument) -> Bool {
        let sampleCount = min(document.pageCount, 5)
        for index in 0..<sampleCount {
            guard let page = document.page(at: index) else { continue }
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        return false
    }
}
