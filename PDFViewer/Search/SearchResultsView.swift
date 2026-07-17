import SwiftUI

/// Compact status + navigation bar shown while search is active: match count,
/// previous/next, and dismiss. The text field itself is provided by the native
/// `.searchable` toolbar modifier applied in `PDFViewerContainer`.
struct SearchResultsBar: View {
    @Bindable var state: PDFDocumentState

    var body: some View {
        HStack(spacing: 12) {
            Text(state.search.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel(searchStatusAccessibilityLabel)
                .accessibilityIdentifier("searchStatusText")
                .frame(minWidth: 90, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                state.searchPrevious()
            } label: {
                Image(systemName: "chevron.up")
            }
            .help("Vorheriger Treffer")
            .disabled(state.search.results.isEmpty)
            .keyboardShortcut(.return, modifiers: [.shift])

            Button {
                state.searchNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .help("Nächster Treffer")
            .disabled(state.search.results.isEmpty)
            .keyboardShortcut(.return, modifiers: [])

            Button {
                state.dismissSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Suche schließen")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onChange(of: state.search.results.count) {
            state.updateSearchHighlights()
        }
    }

    private var searchStatusAccessibilityLabel: String {
        state.search.statusText.isEmpty ? String(localized: "Suche") : state.search.statusText
    }
}
