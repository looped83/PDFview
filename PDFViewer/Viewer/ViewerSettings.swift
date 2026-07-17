import PDFKit
import CoreGraphics

/// Page layout mode, mapped 1:1 onto `PDFDisplayMode` so PDFKit does the actual layout work.
enum PageLayoutMode: String, CaseIterable, Identifiable {
    case singlePage
    case singlePageContinuous
    case twoUp
    case twoUpContinuous

    var id: String { rawValue }

    var pdfDisplayMode: PDFDisplayMode {
        switch self {
        case .singlePage: .singlePage
        case .singlePageContinuous: .singlePageContinuous
        case .twoUp: .twoUp
        case .twoUpContinuous: .twoUpContinuous
        }
    }

    var isContinuous: Bool {
        self == .singlePageContinuous || self == .twoUpContinuous
    }

    var label: String {
        switch self {
        case .singlePage: String(localized: "Einzelne Seite")
        case .singlePageContinuous: String(localized: "Fortlaufend")
        case .twoUp: String(localized: "Doppelseite")
        case .twoUpContinuous: String(localized: "Doppelseite fortlaufend")
        }
    }

    var symbolName: String {
        switch self {
        case .singlePage: "doc"
        case .singlePageContinuous: "doc.on.doc"
        case .twoUp: "book"
        case .twoUpContinuous: "book.pages"
        }
    }
}

/// Zoom intent. `.custom` carries an explicit scale factor; the fit-based
/// cases are resolved against the current page and view size at apply time,
/// so they stay correct across window resizes.
enum ZoomMode: Equatable {
    case actualSize
    case fitPage
    case fitWidth
    case custom(CGFloat)

    static let minimumScale: CGFloat = 0.10
    static let maximumScale: CGFloat = 8.0
    static let stepFactor: CGFloat = 1.25

    var isFitBased: Bool {
        switch self {
        case .fitPage, .fitWidth: true
        case .actualSize, .custom: false
        }
    }
}

/// How an optimized export re-encodes the document.
enum ExportMethod: String, CaseIterable, Identifiable {
    /// Recompress embedded images via a Quartz filter; vector text stays selectable.
    case preserveText
    /// Rasterize each page to a JPEG image — loses text selection but reaches the
    /// smallest sizes, ideal for scans or image-only documents.
    case rasterize

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preserveText: String(localized: "Text erhalten")
        case .rasterize: String(localized: "Maximale Verkleinerung")
        }
    }

    var detail: String {
        switch self {
        case .preserveText:
            String(localized: "Bilder werden komprimiert, Text bleibt auswähl- und durchsuchbar.")
        case .rasterize:
            String(localized: "Jede Seite wird als Bild gespeichert – deutlich kleiner, aber Text ist nicht mehr auswählbar.")
        }
    }
}

/// Compression strength preset, mapped to a target image resolution and JPEG quality.
enum ExportQuality: String, CaseIterable, Identifiable {
    case high
    case balanced
    case strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: String(localized: "Hoch")
        case .balanced: String(localized: "Ausgewogen")
        case .strong: String(localized: "Stark komprimiert")
        }
    }

    var dpi: Int {
        switch self {
        case .high: 200
        case .balanced: 150
        case .strong: 110
        }
    }

    var jpegQuality: Double {
        switch self {
        case .high: 0.80
        case .balanced: 0.72
        case .strong: 0.55
        }
    }
}

struct PDFExportSettings: Equatable {
    var method: ExportMethod = .preserveText
    var quality: ExportQuality = .balanced
}

enum SidebarMode: String, CaseIterable, Identifiable {
    case thumbnails
    case outline

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thumbnails: String(localized: "Miniaturen")
        case .outline: String(localized: "Inhaltsverzeichnis")
        }
    }

    var symbolName: String {
        switch self {
        case .thumbnails: "square.grid.2x2"
        case .outline: "list.bullet.indent"
        }
    }
}
