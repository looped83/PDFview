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
