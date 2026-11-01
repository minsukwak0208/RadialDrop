import Foundation
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AppKit

public enum ConversionError: LocalizedError {
    case fileNotFound(URL)
    case invalidSourceImage(URL)
    case unsupportedTargetType(UTType)
    case destinationCreationFailed(URL)
    case destinationFinalizationFailed(URL)
    case pdfGenerationFailed

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at: \(url.path)"
        case .invalidSourceImage(let url):
            return "Failed to read image source from: \(url.path)"
        case .unsupportedTargetType(let type):
            return "Unsupported target format: \(type.identifier)"
        case .destinationCreationFailed(let url):
            return "Failed to create destination at: \(url.path)"
        case .destinationFinalizationFailed(let url):
            return "Failed to finalize and save image to: \(url.path)"
        case .pdfGenerationFailed:
            return "Failed to create PDF from image."
        }
    }
}

public struct ImageConverter: Sendable {
    public init() {}

    /// Dynamically locates an executable binary in PATH or standard system directories.
    public static func findBinary(named name: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var searchPaths = envPath.split(separator: ":").map { String($0) }
        searchPaths.append(contentsOf: ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"])

        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Converts an image file at `sourceURL` to the target format specified by `targetType`.
    @discardableResult
    public func convert(sourceURL: URL, to targetType: UTType, quality: Double = 0.9) throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ConversionError.fileNotFound(sourceURL)
        }

        if targetType == .pdf {
            return try convertImageToPDF(sourceURL: sourceURL)
        }

        if targetType == .webP {
            return try convertImageToWebP(sourceURL: sourceURL, quality: quality)
        }

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let destinationExtension = targetType.preferredFilenameExtension ?? targetType.identifier
        let destinationURL = generateUniqueDestinationURL(for: sourceURL, newExtension: destinationExtension)

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            targetType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed(destinationURL)
        }

        var options: [CFString: Any] = [:]
        if targetType == .jpeg || targetType == .heic {
            options[kCGImageDestinationLossyCompressionQuality] = quality as CFNumber
        }

        CGImageDestinationAddImageFromSource(destination, imageSource, 0, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }

    /// High-performance memory-efficient image compression (direct CGImage pipeline without TIFF serialization).
    @discardableResult
    public func compress(sourceURL: URL, quality: Double = 0.5) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = directory.appendingPathComponent("\(baseName)_compressed.\(ext)")

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
        guard let data = jpegData ?? bitmap.representation(using: .png, properties: [:]) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        try data.write(to: destinationURL)
        return destinationURL
    }

    /// Strips all EXIF metadata from the image.
    @discardableResult
    public func stripExif(sourceURL: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.lowercased()
        let destinationURL = directory.appendingPathComponent("\(baseName)_no_exif.\(ext)")

        let utType = UTType(filenameExtension: ext) ?? .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed(destinationURL)
        }

        // Add pure image without any metadata dictionary
        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }

    /// Converts an image to grayscale using CoreGraphics DeviceGray color space.
    @discardableResult
    public func convertToGrayscale(sourceURL: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw ConversionError.destinationCreationFailed(sourceURL)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let grayCGImage = context.makeImage() else {
            throw ConversionError.destinationFinalizationFailed(sourceURL)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let destinationURL = directory.appendingPathComponent("\(baseName)_grayscale.\(ext)")

        let utType = UTType(filenameExtension: ext) ?? .jpeg
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed(destinationURL)
        }

        CGImageDestinationAddImage(destination, grayCGImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }

    /// Converts an image to WebP using available local binary (cwebp or ffmpeg).
    private func convertImageToWebP(sourceURL: URL, quality: Double) throws -> URL {
        let destinationURL = generateUniqueDestinationURL(for: sourceURL, newExtension: "webp")

        if let cwebpBinary = Self.findBinary(named: "cwebp") {
            let qualityInt = max(1, min(100, Int(quality * 100)))
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cwebpBinary)
            process.arguments = ["-q", "\(qualityInt)", sourceURL.path, "-o", destinationURL.path]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationURL.path) {
                return destinationURL
            }
        }

        // Fallback to ffmpeg
        if let ffmpegBinary = Self.findBinary(named: "ffmpeg") {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegBinary)
            process.arguments = ["-y", "-i", sourceURL.path, destinationURL.path]

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationURL.path) {
                return destinationURL
            }
        }

        throw ConversionError.unsupportedTargetType(.webP)
    }

    /// Converts an image to a single-page PDF document.
    private func convertImageToPDF(sourceURL: URL) throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ConversionError.invalidSourceImage(sourceURL)
        }

        let destinationURL = generateUniqueDestinationURL(for: sourceURL, newExtension: "pdf")
        let pdfDocument = PDFDocument()
        let imageSize = NSSize(width: cgImage.width, height: cgImage.height)
        let pdfPage = PDFPage(image: NSImage(cgImage: cgImage, size: imageSize))

        if let page = pdfPage {
            pdfDocument.insert(page, at: 0)
        } else {
            throw ConversionError.pdfGenerationFailed
        }

        guard pdfDocument.write(to: destinationURL) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }

    /// Generates a unique destination URL in the same folder as `sourceURL` with `newExtension`.
    public func generateUniqueDestinationURL(for sourceURL: URL, newExtension: String) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var targetURL = directory.appendingPathComponent("\(baseName).\(newExtension)")

        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = directory.appendingPathComponent("\(baseName) (\(counter)).\(newExtension)")
            counter += 1
        }

        return targetURL
    }
}
