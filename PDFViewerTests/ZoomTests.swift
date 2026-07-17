import Testing
import PDFKit
@testable import PDFViewer

@MainActor
struct ZoomTests {

    private func makeState() -> PDFDocumentState {
        let document = TestPDFFactory.makeDocument(pageCount: 3)
        let fileDocument = PDFFileDocument(pdfDocument: document)
        let state = PDFDocumentState(fileDocument: fileDocument, fileURL: nil)
        let pdfView = PDFView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        pdfView.document = document
        state.attach(pdfView: pdfView)
        return state
    }

    /// `zoomIn`/`zoomOut` only compute the *target* `zoomMode`; applying it to
    /// `currentScaleFactor` normally happens via `PDFKitView.Coordinator` reacting to a
    /// live view. This stands in for that sync step so clamping behavior across repeated
    /// calls can be verified without a hosted `PDFView` window.
    private func applyPendingZoomMode(_ state: PDFDocumentState) {
        if case let .custom(scale) = state.zoomMode {
            state.currentScaleFactor = scale
        }
    }

    @Test func zoomInComputesClampedCustomScale() {
        let state = makeState()
        state.currentScaleFactor = ZoomMode.maximumScale / 1.1
        state.zoomIn()
        guard case let .custom(scale) = state.zoomMode else {
            Issue.record("Expected .custom zoom mode after zoomIn()")
            return
        }
        #expect(scale <= ZoomMode.maximumScale)
    }

    @Test func zoomOutComputesClampedCustomScale() {
        let state = makeState()
        state.currentScaleFactor = ZoomMode.minimumScale * 1.1
        state.zoomOut()
        guard case let .custom(scale) = state.zoomMode else {
            Issue.record("Expected .custom zoom mode after zoomOut()")
            return
        }
        #expect(scale >= ZoomMode.minimumScale)
    }

    @Test func repeatedZoomInConvergesAtMaximum() {
        let state = makeState()
        state.currentScaleFactor = 1.0
        for _ in 0..<50 {
            state.zoomIn()
            applyPendingZoomMode(state)
        }
        #expect(state.currentScaleFactor <= ZoomMode.maximumScale)
        #expect(abs(state.currentScaleFactor - ZoomMode.maximumScale) < 0.01)
    }

    @Test func repeatedZoomOutConvergesAtMinimum() {
        let state = makeState()
        state.currentScaleFactor = 1.0
        for _ in 0..<50 {
            state.zoomOut()
            applyPendingZoomMode(state)
        }
        #expect(state.currentScaleFactor >= ZoomMode.minimumScale)
        #expect(abs(state.currentScaleFactor - ZoomMode.minimumScale) < 0.01)
    }

    @Test func fitAndActualSizeModesAreSelectable() {
        let state = makeState()
        state.setActualSize()
        #expect(state.zoomMode == .actualSize)
        state.setFitPage()
        #expect(state.zoomMode == .fitPage)
        state.setFitWidth()
        #expect(state.zoomMode == .fitWidth)
    }
}
