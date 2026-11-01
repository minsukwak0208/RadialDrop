import Foundation
import UniformTypeIdentifiers

public struct RadialItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let iconName: String
    public let targetType: UTType?
    public let actionTag: String?

    public init(
        id: String,
        title: String,
        iconName: String,
        targetType: UTType? = nil,
        actionTag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.targetType = targetType
        self.actionTag = actionTag
    }
}

public enum FileCategory: Sendable {
    case image
    case video
    case audio
    case pdf
    case hwp
    case generic
}

public struct FileInspector: Sendable {
    public init() {}

    /// Categorizes the file at URL using UTType and file extensions.
    public func categorize(url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        if ext == "hwp" || ext == "hwpx" {
            return .hwp
        }

        guard let utType = UTType(filenameExtension: ext) else {
            return .generic
        }

        if utType.conforms(to: .image) {
            return .image
        } else if utType.conforms(to: .movie) {
            return .video
        } else if utType.conforms(to: .audio) {
            return .audio
        } else if utType.conforms(to: .pdf) {
            return .pdf
        }
        return .generic
    }

    /// Returns standard conversion items for the file.
    public func getConversionItems(for url: URL, isAdvancedMode: Bool = false) -> [RadialItem] {
        let category = categorize(url: url)

        if isAdvancedMode {
            return getAdvancedActionItems(category: category)
        }

        switch category {
        case .hwp:
            return [
                RadialItem(id: "pdf", title: "To PDF", iconName: "doc.text.fill", targetType: .pdf),
                RadialItem(id: "docx", title: "To Word", iconName: "doc.richtext", actionTag: "to_docx")
            ]

        case .image:
            return [
                RadialItem(id: "png", title: "PNG", iconName: "photo", targetType: .png),
                RadialItem(id: "jpeg", title: "JPG", iconName: "photo.artframe", targetType: .jpeg),
                RadialItem(id: "webp", title: "WebP", iconName: "sparkles", targetType: .webP),
                RadialItem(id: "heic", title: "HEIC", iconName: "camera.viewfinder", targetType: .heic),
                RadialItem(id: "tiff", title: "TIFF", iconName: "doc.richtext", targetType: .tiff),
                RadialItem(id: "pdf", title: "PDF", iconName: "doc.text.fill", targetType: .pdf)
            ]

        case .video:
            return [
                RadialItem(id: "mp4", title: "MP4", iconName: "film", targetType: .mpeg4Movie),
                RadialItem(id: "mov", title: "MOV", iconName: "video", targetType: .quickTimeMovie),
                RadialItem(id: "gif", title: "GIF", iconName: "play.square", targetType: .gif),
                RadialItem(id: "mp3", title: "MP3 Audio", iconName: "waveform", targetType: .mp3)
            ]

        case .audio:
            return [
                RadialItem(id: "mp3", title: "MP3", iconName: "waveform", targetType: .mp3),
                RadialItem(id: "wav", title: "WAV", iconName: "waveform.path", targetType: .wav),
                RadialItem(id: "m4a", title: "M4A", iconName: "music.note", targetType: .mpeg4Audio),
                RadialItem(id: "flac", title: "FLAC", iconName: "headphones", targetType: .audio)
            ]

        case .pdf:
            return [
                RadialItem(id: "png", title: "To PNG", iconName: "photo", targetType: .png),
                RadialItem(id: "jpeg", title: "To JPG", iconName: "photo.artframe", targetType: .jpeg),
                RadialItem(id: "split", title: "Split Pages", iconName: "rectangle.split.2x1", actionTag: "split"),
                RadialItem(id: "compress", title: "Compress", iconName: "arrow.down.right.and.arrow.up.left", actionTag: "compress")
            ]

        case .generic:
            return [
                RadialItem(id: "zip", title: "ZIP", iconName: "archivebox.fill", targetType: .zip)
            ]
        }
    }

    /// Advanced actions shown when Shift + Option is pressed
    private func getAdvancedActionItems(category: FileCategory) -> [RadialItem] {
        switch category {
        case .hwp:
            return [
                RadialItem(id: "pdf", title: "To PDF", iconName: "doc.text.fill", targetType: .pdf),
                RadialItem(id: "docx", title: "To Word", iconName: "doc.richtext", actionTag: "to_docx")
            ]
        case .image:
            return [
                RadialItem(id: "compress", title: "Compress 50%", iconName: "arrow.down.right.and.arrow.up.left", actionTag: "compress_50"),
                RadialItem(id: "strip_exif", title: "Strip EXIF", iconName: "eye.slash", actionTag: "strip_exif"),
                RadialItem(id: "resize_2x", title: "Resize 2x", iconName: "arrow.up.left.and.down.right.magnifyingglass", actionTag: "resize_2x"),
                RadialItem(id: "grayscale", title: "Grayscale", iconName: "circle.lefthalf.filled", actionTag: "grayscale")
            ]
        default:
            return [
                RadialItem(id: "compress", title: "Compress", iconName: "arrow.down.right.and.arrow.up.left", actionTag: "compress")
            ]
        }
    }
}
