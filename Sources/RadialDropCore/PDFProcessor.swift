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

    /// Compresses a PDF by re-encoding pages at optimized resolution and JPEG quality.
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
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()

            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
            }
            image.unlockFocus()

            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]),
                  let compImage = NSImage(data: jpegData),
                  let newPage = PDFPage(image: compImage) else { continue }

            compressedDoc.insert(newPage, at: compressedDoc.pageCount)
        }

        guard compressedDoc.write(to: outURL) else {
            throw ConversionError.destinationFinalizationFailed(outURL)
        }

        return outURL
    }

    /// Converts pages of a PDF document to PNG or JPEG image files.
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
        let scale: CGFloat = 2.0 // High DPI rendering

        for index in 0..<count {
            guard let page = doc.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()

            if let ctx = NSGraphicsContext.current?.cgContext {
                ctx.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: ctx)
            }
            image.unlockFocus()

            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else { continue }

            let data: Data?
            if targetType == .jpeg {
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            } else {
                data = bitmap.representation(using: .png, properties: [:])
            }

            guard let imageData = data else { continue }

            let outURL: URL
            if count == 1 {
                outURL = directory.appendingPathComponent("\(baseName).\(ext)")
            } else {
                let pageNum = String(format: "%02d", index + 1)
                outURL = directory.appendingPathComponent("\(baseName)_page_\(pageNum).\(ext)")
            }

            try imageData.write(to: outURL)
            outputURLs.append(outURL)
        }

        return outputURLs
    }
}
