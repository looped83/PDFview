import SwiftUI
import PDFKit

/// Bridges AppKit's `PDFView` into SwiftUI.
///
/// The `PDFView` is created exactly once in `makeNSView` and never recreated on state
/// changes — recreating it on every SwiftUI update would drop scroll position, re-render
/// all visible pages, and defeat PDFKit's own internal caching. `updateNSView` only ever
/// pushes the *difference* between the current state and the view (see
/// `Coordinator.synchronize`), and every property write is guarded by an equality check,
/// so a state change that already matches the view's current value never re-enters PDFKit
/// and never triggers a duplicate notification back into `state`.
struct PDFKitView: NSViewRepresentable {
    let state: PDFDocumentState

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = state.fileDocument.pdfDocument
        view.displayMode = state.layoutMode.pdfDisplayMode
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        view.autoScales = false
        view.delegate = context.coordinator
        view.backgroundColor = .underPageBackgroundColor

        context.coordinator.attach(view: view, state: state)
        state.attach(pdfView: view)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.synchronize(view: nsView, with: state)
    }

    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, PDFViewDelegate {
        private weak var state: PDFDocumentState?
        private weak var pdfView: PDFView?
        private var notificationTokens: [NSObjectProtocol] = []

        func attach(view: PDFView, state: PDFDocumentState) {
            self.pdfView = view
            self.state = state
            subscribeToNotifications(for: view)
        }

        func detach() {
            let center = NotificationCenter.default
            notificationTokens.forEach(center.removeObserver)
            notificationTokens.removeAll()
        }

        /// Pushes `state` onto `view`, but only where they actually differ.
        func synchronize(view: PDFView, with state: PDFDocumentState) {
            if view.document !== state.fileDocument.pdfDocument, let document = state.fileDocument.pdfDocument {
                view.document = document
            }

            if view.displayMode != state.layoutMode.pdfDisplayMode {
                view.displayMode = state.layoutMode.pdfDisplayMode
            }

            applyZoom(state.zoomMode, to: view, state: state)
        }

        // MARK: - Zoom

        private func applyZoom(_ mode: ZoomMode, to view: PDFView, state: PDFDocumentState) {
            let target: CGFloat
            switch mode {
            case .actualSize:
                target = 1.0
            case .custom(let scale):
                target = scale
            case .fitPage:
                target = fitPageScale(for: view) ?? view.scaleFactor
            case .fitWidth:
                target = fitWidthScale(for: view) ?? view.scaleFactor
            }

            let clamped = min(max(target, ZoomMode.minimumScale), ZoomMode.maximumScale)

            if abs(view.scaleFactor - clamped) > 0.001 {
                view.scaleFactor = clamped
            }
            if abs(state.currentScaleFactor - clamped) > 0.001 {
                state.currentScaleFactor = clamped
            }
        }

        private func fitPageScale(for view: PDFView) -> CGFloat? {
            guard let page = view.currentPage ?? view.document?.page(at: 0) else { return nil }
            let pageBounds = page.bounds(for: .mediaBox)
            let viewSize = view.bounds.insetBy(dx: 8, dy: 8).size
            guard pageBounds.width > 0, pageBounds.height > 0,
                  viewSize.width > 0, viewSize.height > 0 else { return nil }
            return min(viewSize.width / pageBounds.width, viewSize.height / pageBounds.height)
        }

        private func fitWidthScale(for view: PDFView) -> CGFloat? {
            guard let page = view.currentPage ?? view.document?.page(at: 0) else { return nil }
            let pageBounds = page.bounds(for: .mediaBox)
            let viewWidth = view.bounds.insetBy(dx: 8, dy: 0).size.width
            guard pageBounds.width > 0, viewWidth > 0 else { return nil }
            return viewWidth / pageBounds.width
        }

        // MARK: - PDFKit → state

        private func subscribeToNotifications(for view: PDFView) {
            let center = NotificationCenter.default
            notificationTokens.append(center.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handlePageChanged() }
            })
            notificationTokens.append(center.addObserver(forName: .PDFViewScaleChanged, object: view, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleScaleChanged() }
            })
            notificationTokens.append(center.addObserver(forName: .PDFViewDocumentChanged, object: view, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleDocumentChanged() }
            })
        }

        private func handlePageChanged() {
            guard let pdfView, let state,
                  let document = pdfView.document,
                  let currentPage = pdfView.currentPage else { return }
            let index = document.index(for: currentPage)
            guard state.currentPageIndex != index else { return }
            state.currentPageIndex = index
            state.pageNumberFieldText = String(index + 1)
            state.recordHistoryVisit(index)
            state.persistCurrentPosition()
        }

        private func handleScaleChanged() {
            guard let pdfView, let state else { return }
            guard abs(state.currentScaleFactor - pdfView.scaleFactor) > 0.001 else { return }
            state.currentScaleFactor = pdfView.scaleFactor
            if !state.zoomMode.isFitBased {
                state.zoomMode = .custom(pdfView.scaleFactor)
            }
        }

        private func handleDocumentChanged() {
            guard let pdfView, let state, let document = pdfView.document else { return }
            state.documentDidLoad(document)
        }

        // MARK: - PDFViewDelegate
        // PDFKit already only follows a link after a direct user click, and opens external
        // URLs via NSWorkspace itself — no extra interception is required to satisfy the
        // "external links only after explicit user interaction" requirement.
        func pdfViewWillClick(onLink sender: PDFView, with url: URL) {}
    }
}
