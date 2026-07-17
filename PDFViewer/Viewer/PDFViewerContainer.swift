import SwiftUI
import PDFKit

/// Root view for one document window: routes between the error, password, and normal
/// viewing states, and hosts the sidebar, PDF surface, toolbar, and search bar.
struct PDFViewerContainer: View {
    @ObservedObject private var fileDocument: PDFFileDocument
    private let fileURL: URL?

    @State private var state: PDFDocumentState

    init(fileDocument: PDFFileDocument, fileURL: URL?) {
        self.fileDocument = fileDocument
        self.fileURL = fileURL
        _state = State(initialValue: PDFDocumentState(fileDocument: fileDocument, fileURL: fileURL))
    }

    var body: some View {
        Group {
            if let loadError = fileDocument.loadError {
                DocumentErrorView(error: loadError)
            } else if fileDocument.isLocked {
                PasswordPromptView(state: state)
            } else {
                documentBody
            }
        }
        .navigationTitle(windowTitle)
        .onDisappear {
            state.persistCurrentPosition()
        }
    }

    private var windowTitle: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "PDF-Dokument")
    }

    private var documentBody: some View {
        NavigationSplitView(columnVisibility: sidebarVisibilityBinding) {
            SidebarView(state: state)
        } detail: {
            VStack(spacing: 0) {
                PDFKitView(state: state)
                    .accessibilityLabel(Text("PDF-Inhalt"))
                    .accessibilityIdentifier("pdfContentView")
                if state.isSearchActive {
                    SearchResultsBar(state: state)
                }
                StatusBar(state: state)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .pdfDropTarget()
        .toolbar {
            ViewerToolbar(state: state)
        }
        .searchable(
            text: $state.searchQueryText,
            isPresented: $state.isSearchActive,
            placement: .toolbar,
            prompt: Text("Im Dokument suchen")
        )
        .focusedSceneValue(\.pdfDocumentState, state)
        .alert(
            "Kopie konnte nicht gespeichert werden",
            isPresented: Binding(
                get: { state.saveCopyErrorMessage != nil },
                set: { if !$0 { state.saveCopyErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { state.saveCopyErrorMessage = nil }
        } message: {
            Text(state.saveCopyErrorMessage ?? "")
        }
    }

    private var sidebarVisibilityBinding: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { state.sidebarVisible ? .all : .detailOnly },
            set: { state.sidebarVisible = ($0 != .detailOnly) }
        )
    }
}

/// Dezente Status- und Navigationsinformationen at the bottom of the viewer.
private struct StatusBar: View {
    let state: PDFDocumentState

    var body: some View {
        HStack {
            Text(PageNumberFormatter.pageStatus(current: state.currentPageIndex, total: state.pageCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let info = state.documentInfo, info.isEncrypted {
                Label("Geschützt", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Focused value plumbing for menu commands

private struct PDFDocumentStateFocusedValueKey: FocusedValueKey {
    typealias Value = PDFDocumentState
}

extension FocusedValues {
    var pdfDocumentState: PDFDocumentState? {
        get { self[PDFDocumentStateFocusedValueKey.self] }
        set { self[PDFDocumentStateFocusedValueKey.self] = newValue }
    }
}
