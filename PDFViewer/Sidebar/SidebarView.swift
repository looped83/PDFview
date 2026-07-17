import SwiftUI

/// Container for the two sidebar panes (thumbnails, outline), switched via a segmented
/// control at the top — matching the standard macOS sidebar-with-mode-switcher pattern.
struct SidebarView: View {
    @Bindable var state: PDFDocumentState

    var body: some View {
        VStack(spacing: 0) {
            Picker("Seitenleistenmodus", selection: $state.sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in
                    Image(systemName: mode.symbolName)
                        .accessibilityLabel(Text(mode.label))
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)
            .accessibilityIdentifier("sidebarModePicker")

            Divider()

            switch state.sidebarMode {
            case .thumbnails:
                ThumbnailSidebar(state: state)
            case .outline:
                OutlineSidebar(state: state)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
    }
}
