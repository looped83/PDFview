import AppKit

/// Owns app-lifecycle behavior that SwiftUI's `DocumentGroup` does not expose directly:
/// showing a native "no document open" welcome window instead of an empty Untitled document,
/// since `DocumentGroup(viewing:)` has no document to create on launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var welcomeWindowController: WelcomeWindowController?

    /// Set by the UI test target only (see `PDFViewerUITests`) so tests can open a known
    /// fixture file without having to drive the native Open panel, which XCUITest cannot
    /// reliably automate. A normal user launch never has this environment variable set.
    private var uiTestFixtureURL: URL? {
        ProcessInfo.processInfo.environment["UITEST_PDF_PATH"].map(URL.init(fileURLWithPath:))
    }

    /// Suppresses AppKit's default "show the Open panel at launch" behavior for
    /// document-based apps (governed by `NSShowAppCentricOpenPanelInsteadOfUntitledFile`,
    /// which modern macOS treats as enabled by default). Without this, an Open dialog
    /// appears behind our welcome window on every launch. Turning it off routes launch
    /// through `applicationShouldOpenUntitledFile`, where we show the welcome window
    /// instead. Must run before AppKit makes the launch decision, hence `willFinishLaunching`.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(
            defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false]
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        if let uiTestFixtureURL {
            NSDocumentController.shared.openDocument(withContentsOf: uiTestFixtureURL, display: true) { _, _, _ in }
        } else {
            showWelcomeWindowIfNeeded()
        }
    }

    /// Called by AppKit when the app is launched or re-activated with no file to open.
    /// Returning false suppresses the default "Untitled" document behavior; we show
    /// our own welcome window instead.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        guard uiTestFixtureURL == nil else { return false }
        showWelcomeWindowIfNeeded()
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showWelcomeWindowIfNeeded()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showWelcomeWindowIfNeeded() {
        guard NSDocumentController.shared.documents.isEmpty else { return }
        if welcomeWindowController == nil {
            welcomeWindowController = WelcomeWindowController()
        }
        welcomeWindowController?.showWindow(nil)
        welcomeWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
