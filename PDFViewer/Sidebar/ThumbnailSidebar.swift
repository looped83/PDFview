import SwiftUI
import PDFKit

/// Page thumbnails. Rendering is entirely lazy: `LazyVStack` only materializes rows near
/// the visible area, and each row generates its own thumbnail bitmap in `.task(id:)` —
/// so opening a thousand-page document never renders a thousand bitmaps up front, only
/// however many rows actually scroll into view. A shared `NSCache` (evicted automatically
/// under memory pressure) avoids regenerating a thumbnail every time its row scrolls
/// back into sight.
struct ThumbnailSidebar: View {
    @Bindable var state: PDFDocumentState
    @State private var cache = NSCache<NSNumber, NSImage>()

    private var document: PDFKit.PDFDocument? {
        state.pdfView?.document
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let document {
                        ForEach(0..<document.pageCount, id: \.self) { index in
                            ThumbnailRow(
                                index: index,
                                document: document,
                                cache: cache,
                                isSelected: index == state.currentPageIndex
                            )
                            .id(index)
                            .onTapGesture {
                                state.goToPage(index)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .onChange(of: state.currentPageIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

private struct ThumbnailRow: View {
    let index: Int
    let document: PDFKit.PDFDocument
    let cache: NSCache<NSNumber, NSImage>
    let isSelected: Bool

    @State private var image: NSImage?

    private static let thumbnailSize = CGSize(width: 150, height: 150)

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .aspectRatio(pageAspectRatio, contentMode: .fit)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 2 : 1
                    )
            }

            Text("\(index + 1)")
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .task(id: index) {
            await loadThumbnailIfNeeded()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Seite \(index + 1)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }

    private var pageAspectRatio: CGFloat {
        guard let page = document.page(at: index) else { return 0.77 }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.height > 0 else { return 0.77 }
        return bounds.width / bounds.height
    }

    /// Runs on the main actor throughout — deliberately not off-loaded to a detached task,
    /// since PDFKit's types are not `Sendable` and cannot safely cross actor boundaries.
    /// `Task.yield()` gives layout a chance to settle first, and `.task(id:)` cancellation
    /// means a row scrolled quickly past never pays for a render that will never be seen.
    private func loadThumbnailIfNeeded() async {
        let key = NSNumber(value: index)
        if let cached = cache.object(forKey: key) {
            image = cached
            return
        }
        guard let page = document.page(at: index) else { return }
        await Task.yield()
        guard !Task.isCancelled else { return }
        let generated = page.thumbnail(of: Self.thumbnailSize, for: .mediaBox)
        guard !Task.isCancelled else { return }
        cache.setObject(generated, forKey: key)
        image = generated
    }
}
