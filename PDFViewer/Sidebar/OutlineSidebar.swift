import SwiftUI
import PDFKit

/// The PDF's outline / bookmark tree, rendered with the native `OutlineGroup` so nested
/// entries get standard sidebar disclosure behavior for free.
struct OutlineSidebar: View {
    let state: PDFDocumentState

    private var rootNodes: [OutlineNode] {
        guard let root = state.pdfView?.document?.outlineRoot else { return [] }
        return OutlineNode(outline: root).children ?? []
    }

    var body: some View {
        let nodes = rootNodes
        if nodes.isEmpty {
            ContentUnavailableView(
                "Kein Inhaltsverzeichnis",
                systemImage: "list.bullet.indent",
                description: Text("Dieses Dokument enthält keine Gliederung.")
            )
        } else {
            List {
                OutlineGroup(nodes, children: \.children) { node in
                    Text(node.title)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture { navigate(to: node) }
                        .accessibilityAddTraits(.isButton)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func navigate(to node: OutlineNode) {
        guard let destination = node.outline.destination,
              let page = destination.page,
              let document = state.pdfView?.document else { return }
        state.goToPage(document.index(for: page))
    }
}

private struct OutlineNode: Identifiable {
    let outline: PDFOutline
    var id: ObjectIdentifier { ObjectIdentifier(outline) }

    var title: String {
        let trimmed = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? String(localized: "Unbenannt") : trimmed
    }

    var children: [OutlineNode]? {
        let count = outline.numberOfChildren
        guard count > 0 else { return nil }
        return (0..<count).compactMap { outline.child(at: $0) }.map(OutlineNode.init)
    }
}
