import Foundation
import UniformTypeIdentifiers

public struct MediaConverter: Sendable {
    public init() {}

    private var ffmpegPath: String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
    }

    /// Converts video/audio file to target format using ffmpeg.
    @discardableResult
    public func convert(sourceURL: URL, targetType: UTType) throws -> URL {
        guard let ffmpeg = ffmpegPath else {
            throw ConversionError.unsupportedTargetType(targetType)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = targetType.preferredFilenameExtension ?? targetType.identifier
        let destinationURL = directory.appendingPathComponent("\(baseName).\(ext)")

        var arguments = ["-y", "-i", sourceURL.path]

        if targetType == .gif {
            // High-quality palette/scaled GIF
            arguments += ["-vf", "fps=12,scale=480:-1:flags=lanczos", destinationURL.path]
        } else if targetType == .mp3 {
            // Audio extraction or transcode to MP3
            arguments += ["-vn", "-c:a", "libmp3lame", "-q:a", "2", destinationURL.path]
        } else if targetType == .wav {
            arguments += ["-vn", destinationURL.path]
        } else if targetType == .mpeg4Audio {
            arguments += ["-vn", "-c:a", "aac", destinationURL.path]
        } else {
            // Generic video container (mp4, mov)
            arguments += ["-c:v", "libx264", "-c:a", "aac", destinationURL.path]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }
}
