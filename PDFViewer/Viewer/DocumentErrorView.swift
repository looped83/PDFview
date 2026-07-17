import SwiftUI

/// Shown in place of the PDF surface when a document failed to load. Never surfaces raw
/// system error text — only the curated, actionable `PDFLoadError` messages.
struct DocumentErrorView: View {
    let error: PDFLoadError

    var body: some View {
        ContentUnavailableView {
            Label(error.errorDescription ?? String(localized: "Dokument konnte nicht geöffnet werden"), systemImage: "doc.badge.exclamationmark")
        } description: {
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
            }
        }
    }
}
