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
            .onDrop(of: [.pdf], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
                return true
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

    /// Each dropped item is opened independently as soon as it resolves, rather than
    /// collected into a shared array first — `loadObject` callbacks can fire on
    /// arbitrary queues, so this sidesteps any cross-thread mutable state entirely.
    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    DocumentOpener.open(urls: [url])
                }
            }
        }
    }
}
