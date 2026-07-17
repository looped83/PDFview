import CoreGraphics
import Foundation
import Quartz

/// Writes a size-optimized copy of a PDF by re-drawing every page through a Quartz filter
/// that downsamples and JPEG-recompresses embedded images. Vector text and line art are
/// left untouched, so the exported file stays selectable and searchable — only the (usually
/// dominant) image payload shrinks.
///
/// The tuning targets "noticeably smaller, still clearly readable": 150 DPI is comfortably
/// above screen resolution and fine for most printing, and JPEG quality 0.72 removes bulk
/// without visible blocking on typical document imagery. It is deliberately less aggressive
/// than the system "Reduce File Size" filter (144 DPI / 0.70), which can look soft.
enum PDFCompressionService {

    enum CompressionError: LocalizedError {
        case cannotReadSource
        case cannotCreateFilter
        case cannotCreateContext

        var errorDescription: String? {
            String(localized: "Der optimierte Export ist fehlgeschlagen.")
        }
    }

    /// Quartz filter properties, mirroring the plist layout of the system
    /// `/System/Library/Filters/*.qfilter` files (the only documented format for these).
    private static var filterProperties: [AnyHashable: Any] {
        [
            "Name": "PDF Viewer – Optimierter Export",
            "FilterType": 1,
            "Domains": [
                "Applications": true,
                "Printing": true
            ],
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "ImageCompression": "ImageJPEGCompress",
                        "Compression Quality": 0.72,
                        "ImageScaleSettings": [
                            "ImageResolution": 150,
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": 3000,
                            "ImageSizeMin": 0
                        ]
                    ]
                ]
            ]
        ]
    }

    /// Reads `sourceData` as a PDF and writes an optimized copy to `destination`, overwriting
    /// any existing file there. Runs synchronously; call it off the main actor for large files.
    static func writeOptimizedPDF(sourceData: Data, to destination: URL) throws {
        guard let provider = CGDataProvider(data: sourceData as CFData),
              let source = CGPDFDocument(provider),
              source.numberOfPages > 0,
              let firstPage = source.page(at: 1) else {
            throw CompressionError.cannotReadSource
        }

        guard let filter = QuartzFilter(properties: filterProperties) else {
            throw CompressionError.cannotCreateFilter
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        var mediaBox = firstPage.getBoxRect(.mediaBox)
        guard let context = CGContext(destination as CFURL, mediaBox: &mediaBox, nil) else {
            throw CompressionError.cannotCreateContext
        }

        filter.apply(to: context)
        defer {
            filter.remove(from: context)
            context.closePDF()
        }

        for pageNumber in 1...source.numberOfPages {
            guard let page = source.page(at: pageNumber) else { continue }
            var box = page.getBoxRect(.mediaBox)
            context.beginPage(mediaBox: &box)
            context.drawPDFPage(page)
            context.endPage()
        }
    }
}
