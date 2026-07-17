import SwiftUI

/// Options sheet shown before an optimized export, letting the user trade off size against
/// fidelity: keep selectable text (recompress images) or rasterize for the smallest files,
/// plus a compression-strength preset.
struct ExportOptionsView: View {
    @Bindable var state: PDFDocumentState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Optimiert exportieren")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Methode")
                    .font(.headline)
                Picker("Methode", selection: $state.exportSettings.method) {
                    ForEach(ExportMethod.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(state.exportSettings.method.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Qualität")
                    .font(.headline)
                Picker("Qualität", selection: $state.exportSettings.quality) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.label).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(qualityDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Abbrechen", role: .cancel) {
                    state.isExportOptionsPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Exportieren…") {
                    state.confirmOptimizedExport()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var qualityDetail: String {
        let q = state.exportSettings.quality
        return String(localized: "\(q.dpi) DPI, JPEG-Qualität \(Int(q.jpegQuality * 100)) %.")
    }
}
