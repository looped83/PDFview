import SwiftUI

/// Shown in the welcome window when no document is open. Deliberately minimal: no tips
/// carousel, no promotional content — just the way in.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Kein PDF geöffnet")
                    .font(.title2.bold())
                Text("Öffnen Sie eine PDF-Datei oder ziehen Sie sie in dieses Fenster.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("PDF öffnen…") {
                DocumentOpener.presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: .command)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("openPDFButton")
        }
        .padding(48)
        .frame(minWidth: 560, minHeight: 380)
        .pdfDropTarget()
    }
}

#Preview {
    EmptyStateView()
}
