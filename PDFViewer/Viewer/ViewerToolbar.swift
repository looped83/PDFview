import SwiftUI

/// The toolbar intentionally exposes only what's needed on every visit — sidebar, page
/// navigation, layout, zoom, and search (via `.searchable`). Everything else (print,
/// save a copy, reveal in Finder, document info) lives in the menu bar via `AppCommands`.
struct ViewerToolbar: ToolbarContent {
    @Bindable var state: PDFDocumentState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                state.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Seitenleiste ein-/ausblenden")
            .accessibilityLabel(Text("Seitenleiste ein- oder ausblenden"))
            .accessibilityIdentifier("sidebarToggleButton")
        }

        ToolbarItemGroup(placement: .principal) {
            Button {
                state.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.up")
            }
            .help("Vorherige Seite")
            .disabled(state.currentPageIndex <= 0)
            .accessibilityIdentifier("previousPageButton")

            HStack(spacing: 4) {
                TextField("", text: $state.pageNumberFieldText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                    .multilineTextAlignment(.center)
                    .onSubmit { state.submitPageNumberField() }
                    .accessibilityLabel(Text("Seitennummer"))
                    .accessibilityIdentifier("pageNumberField")
                Text("/ \(max(state.pageCount, 1))")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Button {
                state.goToNextPage()
            } label: {
                Image(systemName: "chevron.down")
            }
            .help("Nächste Seite")
            .disabled(state.currentPageIndex >= state.pageCount - 1)
            .accessibilityIdentifier("nextPageButton")
        }

        ToolbarItemGroup(placement: .automatic) {
            Menu {
                ForEach(PageLayoutMode.allCases) { mode in
                    Button {
                        state.layoutMode = mode
                    } label: {
                        Label(mode.label, systemImage: mode.symbolName)
                    }
                }
            } label: {
                Image(systemName: state.layoutMode.symbolName)
            }
            .help("Darstellungsmodus")
            .accessibilityLabel(Text("Darstellungsmodus"))

            Menu {
                Button("Vergrößern") { state.zoomIn() }
                Button("Verkleinern") { state.zoomOut() }
                Divider()
                Button("Tatsächliche Größe") { state.setActualSize() }
                Button("Ganze Seite") { state.setFitPage() }
                Button("An Breite anpassen") { state.setFitWidth() }
            } label: {
                Text(zoomLabel)
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .help("Zoom")
            .accessibilityLabel(Text("Zoomstufe, \(zoomLabel)"))
            .accessibilityIdentifier("zoomMenu")
        }
    }

    private var zoomLabel: String {
        "\(Int((state.currentScaleFactor * 100).rounded()))%"
    }
}
