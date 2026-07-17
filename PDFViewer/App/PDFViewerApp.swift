import SwiftUI

@main
struct PDFViewerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(viewing: PDFFileDocument.self) { configuration in
            PDFViewerContainer(fileDocument: configuration.document, fileURL: configuration.fileURL)
        }
        .commands {
            AppCommands()
        }
    }
}
