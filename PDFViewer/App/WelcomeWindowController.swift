import AppKit
import SwiftUI

/// Hosts `EmptyStateView` in a plain AppKit window. `DocumentGroup(viewing:)` has no
/// "Untitled" document to create on launch, so there is no SwiftUI scene lifecycle hook
/// for "show a welcome screen when nothing is open" — `AppDelegate` drives this window
/// imperatively instead, which is the one place in this app AppKit is used directly
/// rather than SwiftUI.
@MainActor
final class WelcomeWindowController: NSWindowController {

    convenience init() {
        let hostingController = NSHostingController(rootView: EmptyStateView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = String(localized: "PDF Viewer")
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        // Give the window an explicit size up front so centering has a stable frame to
        // work with. No frame autosave: a saved frame would override centering and reopen
        // the welcome window wherever it last sat. We always want it centered on launch.
        window.setContentSize(NSSize(width: 640, height: 460))
        self.init(window: window)
        observeDocumentWindows()
    }

    /// Centers only after the window is shown and laid out. Centering in `init` runs
    /// before SwiftUI finalizes the content size, so the window would resize afterwards
    /// and drift off-center.
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Auto-dismisses the welcome window once a real document window opens, so the user
    /// isn't left with an empty-state window behind their newly opened PDF.
    private func observeDocumentWindows() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(otherWindowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func otherWindowBecameKey(_ notification: Notification) {
        guard let becameKeyWindow = notification.object as? NSWindow, becameKeyWindow !== window else { return }
        guard !NSDocumentController.shared.documents.isEmpty else { return }
        close()
    }
}
