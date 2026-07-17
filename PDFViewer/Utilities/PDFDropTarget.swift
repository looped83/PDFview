import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Accepts PDF files dragged onto the view and opens each as a new document window,
    /// with a visible highlight while a drag is over the view.
    func pdfDropTarget() -> some View {
        modifier(PDFDropModifier())
    }
}

private struct PDFDropModifier: ViewModifier {
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            // `dropDestination(for: URL.self)` decodes file-URL drags directly and delivers
            // the resolved URLs on the main actor. A file dragged from Finder is registered
            // under its file type (e.g. `com.adobe.pdf`), which the older
            // `loadObject(ofClass: URL.self)` path failed to vend as a URL — so drops silently
            // did nothing. `DocumentOpener.open` filters to PDFs, so non-PDF drops are ignored.
            .dropDestination(for: URL.self) { urls, _ in
                DocumentOpener.open(urls: urls)
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .padding(4)
                        .allowsHitTesting(false)
                }
            }
    }
}
