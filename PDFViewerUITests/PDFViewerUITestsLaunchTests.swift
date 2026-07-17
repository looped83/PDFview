import XCTest

final class PDFViewerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool { true }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsWelcomeWindowWithNoDocument() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["openPDFButton"].waitForExistence(timeout: 10))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
