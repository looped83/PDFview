import AppKit
import UniformTypeIdentifiers

/// Central place for turning "a URL the user handed us" (Open panel, drag-and-drop,
/// Finder) into an open document window via the standard `NSDocumentController`
/// machinery that `DocumentGroup` itself is built on.
@MainActor
enum DocumentOpener {

    @discardableResult
    static func open(urls: [URL]) -> Bool {
        let pdfURLs = urls.filter(isPDF)
        guard !pdfURLs.isEmpty else { return false }
        for url in pdfURLs {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
        return true
    }

    static func presentOpenPanel() {
        NSDocumentController.shared.openDocument(nil)
    }

    private static func isPDF(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .pdf)
        }
        return url.pathExtension.lowercased() == "pdf"
    }
}
