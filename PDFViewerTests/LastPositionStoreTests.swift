import Testing
import Foundation
@testable import PDFViewer

@MainActor
struct LastPositionStoreTests {

    private func makeStore() -> LastPositionStore {
        let suiteName = "com.brueggemann.pdfviewer.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return LastPositionStore(defaults: defaults)
    }

    private func makeTemporaryFile(content: String = "test") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try Data(content.utf8).write(to: url)
        return url
    }

    @Test func savingAndReadingBackAPosition() throws {
        let store = makeStore()
        let url = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        store.savePosition(pageIndex: 7, zoomScale: 1.5, for: url)
        let restored = store.position(for: url)

        #expect(restored?.pageIndex == 7)
        #expect(restored?.zoomScale == 1.5)
    }

    @Test func unknownFileHasNoSavedPosition() throws {
        let store = makeStore()
        let url = try makeTemporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(store.position(for: url) == nil)
    }

    @Test func staleEntryIsIgnoredWhenFileSizeChanges() throws {
        let store = makeStore()
        let url = try makeTemporaryFile(content: "short")
        defer { try? FileManager.default.removeItem(at: url) }

        store.savePosition(pageIndex: 3, zoomScale: 1.0, for: url)
        #expect(store.position(for: url) != nil)

        // Simulate the file being replaced with different content (different size).
        try Data("a much longer replacement file content".utf8).write(to: url)

        #expect(store.position(for: url) == nil)
    }
}
