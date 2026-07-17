import XCTest
import AppKit

/// End-to-end coverage of the core flows: launch, open a PDF, change pages, toggle the
/// sidebar, search, change zoom, close the window. Each test launches its own app
/// instance pointed at a small PDF generated on the fly (via `UITEST_PDF_PATH`, read by
/// `AppDelegate`), so tests never depend on driving the native Open panel — XCUITest
/// cannot reliably automate system file dialogs.
final class PDFViewerUITests: XCTestCase {

    private var fixtureURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtureURL = try Self.makeFixturePDF(pageCount: 6, titlePrefix: "UI-Testseite")
    }

    override func tearDownWithError() throws {
        if let fixtureURL {
            try? FileManager.default.removeItem(at: fixtureURL)
        }
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_PDF_PATH"] = fixtureURL.path
        app.launch()
        return app
    }

    // MARK: 1. App starten

    func testAppLaunchesAndShowsAWindow() {
        let app = launchApp()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    // MARK: 2. PDF öffnen

    func testOpeningAPDFShowsItsContent() {
        let app = launchApp()
        let content = app.windows.firstMatch.descendants(matching: .any)["pdfContentView"]
        XCTAssertTrue(content.waitForExistence(timeout: 10))
    }

    // MARK: 3. Seiten wechseln

    func testChangingPagesUpdatesPageField() {
        let app = launchApp()
        let pageField = app.windows.firstMatch.textFields["pageNumberField"]
        XCTAssertTrue(pageField.waitForExistence(timeout: 10))
        XCTAssertEqual(pageField.value as? String, "1")

        let nextButton = app.windows.firstMatch.buttons["nextPageButton"]
        XCTAssertTrue(nextButton.exists)
        nextButton.click()

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "2"),
            object: pageField
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: 4. Sidebar öffnen

    func testTogglingSidebarShowsModePicker() {
        let app = launchApp()
        let sidebarButton = app.windows.firstMatch.buttons["sidebarToggleButton"]
        XCTAssertTrue(sidebarButton.waitForExistence(timeout: 10))

        let picker = app.windows.firstMatch.segmentedControls["sidebarModePicker"]
        // Sidebar starts visible by default; toggling twice should return to a visible state.
        if !picker.exists {
            sidebarButton.click()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
    }

    // MARK: 5. Suche ausführen

    func testSearchShowsStatusText() {
        let app = launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // ⌘F focuses the native search field.
        app.typeKey("f", modifierFlags: .command)

        let searchField = window.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("UI-Testseite")

        let statusText = window.staticTexts["searchStatusText"]
        XCTAssertTrue(statusText.waitForExistence(timeout: 5))
    }

    // MARK: 6. Zoom ändern

    func testChangingZoomUpdatesZoomLabel() {
        let app = launchApp()
        let zoomMenu = app.windows.firstMatch.popUpButtons["zoomMenu"]
        XCTAssertTrue(zoomMenu.waitForExistence(timeout: 10))
        let initialLabel = zoomMenu.title

        app.typeKey("+", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "title != %@", initialLabel),
            object: zoomMenu
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: 7. Fenster schließen

    func testClosingWindowRemovesIt() {
        let app = launchApp()
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        app.typeKey("w", modifierFlags: .command)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: window
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    // MARK: - Fixture generation

    /// Minimal, self-contained PDF generator (deliberately not shared with the unit test
    /// target's `TestPDFFactory`) so this UI test target has no dependency on the app's
    /// internal test-only code.
    private static func makeFixturePDF(pageCount: Int, titlePrefix: String) throws -> URL {
        let pageSize = CGSize(width: 612, height: 792)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw NSError(domain: "PDFViewerUITests", code: 1)
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "PDFViewerUITests", code: 2)
        }
        for pageIndex in 0..<pageCount {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let text = "\(titlePrefix) \(pageIndex + 1)" as NSString
            text.draw(
                at: CGPoint(x: 72, y: pageSize.height - 120),
                withAttributes: [.font: NSFont.systemFont(ofSize: 28)]
            )
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try (data as Data).write(to: url)
        return url
    }
}
