import Foundation
import PDFKit
import AppKit
import UniformTypeIdentifiers

public struct PDFProcessor: Sendable {
    public init() {}

    /// Splits a multi-page PDF into individual single-page PDF files.
    @discardableResult
    public func split(sourceURL: URL) throws -> [URL] {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        var outputURLs: [URL] = []
        let count = doc.pageCount
        guard count > 0 else { return [] }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        for index in 0..<count {
            guard let page = doc.page(at: index) else { continue }
            let singleDoc = PDFDocument()
            singleDoc.insert(page, at: 0)

            let pageNum = String(format: "%02d", index + 1)
            let outURL = directory.appendingPathComponent("\(baseName)_page_\(pageNum).pdf")
            singleDoc.write(to: outURL)
            outputURLs.append(outURL)
        }

        return outputURLs
    }

    /// High-performance memory-efficient PDF compression (direct CGImage pipeline without TIFF serialization).
    @discardableResult
    public func compress(sourceURL: URL, quality: Double = 0.5) throws -> URL {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outURL = directory.appendingPathComponent("\(baseName)_compressed.pdf")

        let compressedDoc = PDFDocument()
        let scale: CGFloat = 1.5

        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)

            guard width > 0, height > 0 else { continue }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            // Fill background white
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)

            guard let cgImage = context.makeImage() else { continue }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]),
                  let compImage = NSImage(data: jpegData),
                  let newPage = PDFPage(image: compImage) else { continue }

            compressedDoc.insert(newPage, at: compressedDoc.pageCount)
        }

        guard compressedDoc.write(to: outURL) else {
            throw ConversionError.destinationFinalizationFailed(outURL)
        }

        return outURL
    }

    /// Converts pages of a PDF document to PNG or JPEG image files directly without TIFF serialization.
    @discardableResult
    public func convertToImages(sourceURL: URL, targetType: UTType) throws -> [URL] {
        guard let doc = PDFDocument(url: sourceURL) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        var outputURLs: [URL] = []
        let count = doc.pageCount
        guard count > 0 else { return [] }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = (targetType == .jpeg) ? "jpg" : "png"
        let scale: CGFloat = 2.0 // Retina 2x rendering

        for index in 0..<count {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)

            guard width > 0, height > 0 else { continue }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)

            guard let cgImage = context.makeImage() else { continue }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let imageData: Data?
            if targetType == .jpeg {
                imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            } else {
                imageData = bitmap.representation(using: .png, properties: [:])
            }

            guard let data = imageData else { continue }

            let outURL: URL
            if count == 1 {
                outURL = directory.appendingPathComponent("\(baseName).\(ext)")
            } else {
                let pageNum = String(format: "%02d", index + 1)
                outURL = directory.appendingPathComponent("\(baseName)_page_\(pageNum).\(ext)")
            }

            try data.write(to: outURL)
            outputURLs.append(outURL)
        }

        return outputURLs
    }
}
