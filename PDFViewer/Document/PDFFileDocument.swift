import Foundation
import PDFKit
import UniformTypeIdentifiers
import SwiftUI

/// The file-level document model handed to SwiftUI's `DocumentGroup`.
///
/// Deliberately minimal: it owns *loading* a PDF from disk (including detecting
/// locked/encrypted files) and exposes the resulting `PDFKit.PDFDocument`. It does not
/// own zoom, page, sidebar, or search state — that is per-window UI state and lives in
/// `PDFDocumentState`, created by the viewer container. Keeping the two separate means
/// SwiftUI never has to re-diff or duplicate the (potentially large) PDF payload when
/// unrelated UI state changes.
///
/// This is a viewer, not an editor: `DocumentGroup(viewing:)` never surfaces Save / Save As
/// commands for `ReferenceFileDocument`, so `snapshot`/`fileWrapper` below exist only to
/// satisfy the protocol and are not reachable from the app's UI. "Speichern unter (Kopie)"
/// is implemented separately as a plain file copy that never touches this type.
final class PDFFileDocument: ReferenceFileDocument {

    static var readableContentTypes: [UTType] { [.pdf] }
    static var writableContentTypes: [UTType] { [.pdf] }

    /// `nil` while the document is locked and awaiting a password.
    @Published private(set) var pdfDocument: PDFKit.PDFDocument?
    @Published private(set) var isLocked: Bool
    @Published private(set) var loadError: PDFLoadError?

    private let originalData: Data

    /// Never throws for corrupt or unsupported PDF content — a thrown error here surfaces as
    /// a terse system alert with no room for guidance. Instead, load failures are captured in
    /// `loadError` so `PDFViewerContainer` can render a proper, actionable error view.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PDFLoadError.unreadable
        }
        self.originalData = data
        switch PDFFileClassification.classify(data: data) {
        case .loaded(let document):
            self.isLocked = false
            self.pdfDocument = document
            self.loadError = nil
        case .locked:
            self.isLocked = true
            self.pdfDocument = nil
            self.loadError = nil
        case .corrupted:
            self.isLocked = false
            self.pdfDocument = nil
            self.loadError = .corrupted
        }
    }

    /// Test-support entry point that sidesteps constructing SwiftUI's
    /// `FileDocumentReadConfiguration` (which needs a real `FileWrapper`). Not gated
    /// behind `#if DEBUG` since it's a harmless, internal-only initializer.
    init(pdfDocument: PDFKit.PDFDocument, isLocked: Bool = false, loadError: PDFLoadError? = nil) {
        self.originalData = pdfDocument.dataRepresentation() ?? Data()
        self.isLocked = isLocked
        self.pdfDocument = isLocked ? nil : pdfDocument
        self.loadError = loadError
    }

    /// Test-support entry point for exercising `unlock(password:)` against genuinely
    /// encrypted bytes (the `pdfDocument:` initializer above can't produce those, since
    /// re-encoding an already-open `PDFKit.PDFDocument` drops its encryption).
    init(encryptedData: Data) {
        self.originalData = encryptedData
        self.isLocked = true
        self.pdfDocument = nil
        self.loadError = nil
    }

    /// Attempts to unlock the document with a user-supplied password.
    /// Returns `true` on success.
    @discardableResult
    func unlock(password: String) -> Bool {
        guard let locked = PDFKit.PDFDocument(data: originalData) else { return false }
        guard locked.unlock(withPassword: password) else { return false }
        isLocked = false
        pdfDocument = locked
        return true
    }

    func snapshot(contentType: UTType) throws -> PDFKit.PDFDocument {
        guard let pdfDocument else { throw PDFLoadError.unreadable }
        return pdfDocument
    }

    func fileWrapper(snapshot: PDFKit.PDFDocument, configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = snapshot.dataRepresentation() else { throw PDFLoadError.unreadable }
        return FileWrapper(regularFileWithContents: data)
    }
}
