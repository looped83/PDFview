import CoreGraphics
import Foundation
import ImageIO
import Quartz
import UniformTypeIdentifiers

/// Writes a size-optimized copy of a PDF.
///
/// Two strategies are offered (see `ExportMethod`):
/// - `.preserveText`: re-draw every page through a Quartz filter that downsamples and
///   JPEG-recompresses embedded images. Vector text and line art are left untouched, so the
///   result stays selectable and searchable — only the image payload shrinks.
/// - `.rasterize`: render each page to a bitmap at the target resolution and embed it as a
///   JPEG. This drops text selection but reliably reaches the smallest sizes, which is what
///   scans and image-only PDFs need.
///
/// Either way the optimized bytes are produced in memory and compared with the source;
/// whichever is smaller is written, so the export is never larger than the input. (Filtering
/// can otherwise *inflate* PDFs whose images are already efficiently coded or shared across
/// pages, and rasterizing a text page can be larger than its vector form.)
enum PDFCompressionService {

    enum CompressionError: LocalizedError {
        case cannotReadSource
        case cannotCreateFilter
        case cannotCreateContext

        var errorDescription: String? {
            String(localized: "Der optimierte Export ist fehlgeschlagen.")
        }
    }

    /// The outcome of an export, so the UI can report what actually happened.
    enum Result {
        /// The optimized copy was smaller and was written.
        case compressed(originalBytes: Int, optimizedBytes: Int)
        /// Optimization did not reduce the size; the unchanged original was written instead.
        case alreadyOptimal(bytes: Int)
    }

    /// Reads `sourceData` as a PDF, produces an optimized copy using `settings`, and writes
    /// whichever of the two is smaller to `destination` (overwriting any existing file).
    /// Runs synchronously; call it off the main actor for large files.
    @discardableResult
    static func writeOptimizedPDF(
        sourceData: Data,
        to destination: URL,
        settings: PDFExportSettings
    ) throws -> Result {
        let optimized: Data
        switch settings.method {
        case .preserveText:
            optimized = try recompressImages(sourceData: sourceData, settings: settings)
        case .rasterize:
            optimized = try rasterizePages(sourceData: sourceData, settings: settings)
        }

        let dataToWrite: Data
        let result: Result
        if optimized.count < sourceData.count {
            dataToWrite = optimized
            result = .compressed(originalBytes: sourceData.count, optimizedBytes: optimized.count)
        } else {
            dataToWrite = sourceData
            result = .alreadyOptimal(bytes: sourceData.count)
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try dataToWrite.write(to: destination)
        return result
    }

    // MARK: - Strategies

    /// Quartz filter matching the plist layout of the system `/System/Library/Filters`
    /// files (the only documented format for these).
    private static func filterProperties(dpi: Int, quality: Double) -> [AnyHashable: Any] {
        [
            "Name": "PDF Viewer – Optimierter Export",
            "FilterType": 1,
            "Domains": ["Applications": true, "Printing": true],
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "ImageCompression": "ImageJPEGCompress",
                        "Compression Quality": quality,
                        "ImageScaleSettings": [
                            "ImageResolution": dpi,
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": 3000,
                            "ImageSizeMin": 0
                        ]
                    ]
                ]
            ]
        ]
    }

    private static func recompressImages(sourceData: Data, settings: PDFExportSettings) throws -> Data {
        let (source, firstBox) = try openDocument(sourceData)
        guard let filter = QuartzFilter(properties: filterProperties(
            dpi: settings.quality.dpi, quality: settings.quality.jpegQuality)
        ) else {
            throw CompressionError.cannotCreateFilter
        }

        return try renderPDF(mediaBox: firstBox) { context in
            filter.apply(to: context)
            for pageNumber in 1...source.numberOfPages {
                guard let page = source.page(at: pageNumber) else { continue }
                var box = page.getBoxRect(.mediaBox)
                context.beginPage(mediaBox: &box)
                context.drawPDFPage(page)
                context.endPage()
            }
            filter.remove(from: context)
        }
    }

    private static func rasterizePages(sourceData: Data, settings: PDFExportSettings) throws -> Data {
        let (source, firstBox) = try openDocument(sourceData)
        let scale = CGFloat(settings.quality.dpi) / 72.0

        return try renderPDF(mediaBox: firstBox) { context in
            for pageNumber in 1...source.numberOfPages {
                guard let page = source.page(at: pageNumber) else { continue }
                let box = page.getBoxRect(.mediaBox)
                var pageBox = box
                context.beginPage(mediaBox: &pageBox)
                if let jpeg = rasterizePage(page, box: box, scale: scale, quality: settings.quality.jpegQuality) {
                    context.draw(jpeg, in: box)
                } else {
                    // Fall back to vector drawing if rasterization fails for a page.
                    context.drawPDFPage(page)
                }
                context.endPage()
            }
        }
    }

    /// Renders one page to a bitmap at `scale`, then round-trips it through JPEG at `quality`
    /// so the image embedded into the output PDF carries the compressed encoding.
    private static func rasterizePage(_ page: CGPDFPage, box: CGRect, scale: CGFloat, quality: Double) -> CGImage? {
        let pixelWidth = Int((box.width * scale).rounded())
        let pixelHeight = Int((box.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0,
              let bitmap = CGContext(
                data: nil, width: pixelWidth, height: pixelHeight,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            return nil
        }
        bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        bitmap.scaleBy(x: scale, y: scale)
        bitmap.translateBy(x: -box.origin.x, y: -box.origin.y)
        bitmap.drawPDFPage(page)

        guard let raw = bitmap.makeImage() else { return nil }

        // Encode to JPEG and decode back, so the resulting CGImage is JPEG-backed.
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            return raw
        }
        CGImageDestinationAddImage(dest, raw, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest),
              let src = CGImageSourceCreateWithData(out as CFData, nil),
              let jpeg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return raw
        }
        return jpeg
    }

    // MARK: - Helpers

    private static func openDocument(_ data: Data) throws -> (CGPDFDocument, CGRect) {
        guard let provider = CGDataProvider(data: data as CFData),
              let source = CGPDFDocument(provider),
              source.numberOfPages > 0,
              let firstPage = source.page(at: 1) else {
            throw CompressionError.cannotReadSource
        }
        return (source, firstPage.getBoxRect(.mediaBox))
    }

    /// Creates an in-memory PDF context and runs `draw`, returning the produced bytes.
    private static func renderPDF(mediaBox: CGRect, _ draw: (CGContext) -> Void) throws -> Data {
        let buffer = NSMutableData()
        guard let consumer = CGDataConsumer(data: buffer as CFMutableData) else {
            throw CompressionError.cannotCreateContext
        }
        var box = mediaBox
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw CompressionError.cannotCreateContext
        }
        draw(context)
        context.closePDF()
        return buffer as Data
    }
}
