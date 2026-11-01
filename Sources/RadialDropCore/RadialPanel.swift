import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Custom NSView that registers for drag types and forwards all dragging destination events to RadialPanel.
public final class RadialDropView: NSView {
    public weak var panel: RadialPanel?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }

    // MARK: - NSDraggingDestination

    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return panel?.handleDraggingEntered(sender) ?? []
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        return panel?.handleDraggingUpdated(sender) ?? []
    }

    public override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        panel?.handleDraggingExited(sender)
    }

    public override func draggingEnded(_ sender: any NSDraggingInfo) {
        panel?.handleDraggingEnded(sender)
    }

    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        return panel?.handlePerformDragOperation(sender) ?? false
    }
}

@MainActor
public final class RadialPanel: NSPanel {
    private var dropView: RadialDropView!
    private var hostingView: NSHostingView<AnyView>?
    private var currentItems: [RadialItem] = []
    private var hoveredIndex: Int? = nil
    private var sourceURLs: [URL] = []
    public private(set) var isProcessing = false

    private let innerRadius: CGFloat = 45
    private let outerRadius: CGFloat = 135

    public var onFileConverted: ((URL, URL) -> Void)?

    public init() {
        let contentRect = NSRect(x: 0, y: 0, width: 300, height: 300)
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false

        dropView = RadialDropView(frame: contentRect)
        dropView.panel = self
        self.contentView = dropView
    }

    public func configure(items: [RadialItem], sourceURLs: [URL] = []) {
        self.currentItems = items
        self.sourceURLs = sourceURLs
        self.hoveredIndex = nil
        updateContentView()
    }

    private func updateContentView() {
        let view = RadialWheelView(
            items: currentItems,
            hoveredIndex: hoveredIndex,
            onSelect: { [weak self] item in
                self?.handleSelection(item: item)
            }
        )

        if let hosting = hostingView {
            hosting.rootView = AnyView(view)
        } else {
            let hosting = NSHostingView(rootView: AnyView(view))
            hosting.frame = dropView.bounds
            hosting.autoresizingMask = [.width, .height]
            dropView.addSubview(hosting)
            self.hostingView = hosting
        }
    }

    public func show(at screenPoint: CGPoint, items: [RadialItem], urls: [URL]) {
        configure(items: items, sourceURLs: urls)
        let panelSize: CGFloat = 300
        let origin = CGPoint(
            x: screenPoint.x - panelSize / 2,
            y: screenPoint.y - panelSize / 2
        )
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    public func hide() {
        orderOut(nil)
        hoveredIndex = nil
        sourceURLs.removeAll()
        isProcessing = false
    }

    // MARK: - Drag Destination Handlers

    public func handleDraggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if let urls = getDraggedURLs(from: sender), !urls.isEmpty {
            self.sourceURLs = urls
            let inspector = FileInspector()
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            let items = inspector.getConversionItems(for: urls[0], isAdvancedMode: isOptionDown)
            configure(items: items, sourceURLs: urls)
        }

        let localPoint = dropView.convert(sender.draggingLocation, from: nil)
        updateHover(for: localPoint)
        return .copy
    }

    public func handleDraggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let localPoint = dropView.convert(sender.draggingLocation, from: nil)
        updateHover(for: localPoint)
        return hoveredIndex != nil ? .copy : []
    }

    public func handleDraggingExited(_ sender: (any NSDraggingInfo)?) {
        hoveredIndex = nil
        updateContentView()
    }

    public func handleDraggingEnded(_ sender: any NSDraggingInfo) {
        if !isProcessing {
            hide()
        }
    }

    public func handlePerformDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let hovered = hoveredIndex, hovered >= 0, hovered < currentItems.count else {
            hide()
            return false
        }

        let selectedItem = currentItems[hovered]
        let extractedURLs = getDraggedURLs(from: sender) ?? []
        let urlsToProcess = !sourceURLs.isEmpty ? sourceURLs : extractedURLs

        guard !urlsToProcess.isEmpty else {
            hide()
            return false
        }

        isProcessing = true
        handleConversion(item: selectedItem, urls: urlsToProcess)
        return true
    }

    private func updateHover(for point: CGPoint) {
        let center = CGPoint(x: dropView.bounds.midX, y: dropView.bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        var newHovered: Int? = nil
        if distance >= innerRadius && distance <= (outerRadius + 20) {
            let degrees = atan2(dy, dx) * 180.0 / .pi
            var clockAngle = 90.0 - degrees
            if clockAngle < 0 { clockAngle += 360.0 }

            let count = currentItems.count
            if count > 0 {
                let sliceAngle = 360.0 / Double(count)
                let index = Int(clockAngle / sliceAngle) % count
                newHovered = index
            }
        }

        if newHovered != hoveredIndex {
            hoveredIndex = newHovered
            updateContentView()
        }
    }

    private func handleSelection(item: RadialItem) {
        guard !sourceURLs.isEmpty else { return }
        isProcessing = true
        handleConversion(item: item, urls: sourceURLs)
    }

    private func handleConversion(item: RadialItem, urls: [URL]) {
        let inspector = FileInspector()
        let imageConverter = ImageConverter()
        let pdfProcessor = PDFProcessor()
        let mediaConverter = MediaConverter()
        let hwpConverter = HWPConverter()

        Task.detached(priority: .userInitiated) {
            for url in urls {
                let category = inspector.categorize(url: url)

                do {
                    var outputURLs: [URL] = []

                    // 1. Action Tag Routing
                    if let action = item.actionTag {
                        switch action {
                        case "to_docx":
                            let out = try hwpConverter.convertToWord(sourceURL: url)
                            outputURLs = [out]

                        case "split":
                            outputURLs = try pdfProcessor.split(sourceURL: url)

                        case "compress", "compress_50":
                            if category == .pdf {
                                let out = try pdfProcessor.compress(sourceURL: url)
                                outputURLs = [out]
                            } else {
                                let out = try imageConverter.compress(sourceURL: url, quality: 0.5)
                                outputURLs = [out]
                            }

                        case "strip_exif":
                            let out = try imageConverter.stripExif(sourceURL: url)
                            outputURLs = [out]

                        case "grayscale":
                            let out = try imageConverter.convertToGrayscale(sourceURL: url)
                            outputURLs = [out]

                        default:
                            print("[RadialDrop] Unknown action tag: \(action)")
                        }
                    }
                    // 2. Target Format Routing
                    else if let targetType = item.targetType {
                        switch category {
                        case .hwp:
                            if targetType == .pdf {
                                let out = try hwpConverter.convertToPDF(sourceURL: url)
                                outputURLs = [out]
                            }

                        case .pdf:
                            if targetType == .png || targetType == .jpeg {
                                outputURLs = try pdfProcessor.convertToImages(sourceURL: url, targetType: targetType)
                            }

                        case .video, .audio:
                            let out = try mediaConverter.convert(sourceURL: url, targetType: targetType)
                            outputURLs = [out]

                        case .image:
                            let out = try imageConverter.convert(sourceURL: url, to: targetType)
                            outputURLs = [out]

                        default:
                            let out = try imageConverter.convert(sourceURL: url, to: targetType)
                            outputURLs = [out]
                        }
                    }

                    // Success Feedback for generated files
                    if !outputURLs.isEmpty {
                        await MainActor.run {
                            NSSound(named: "Glass")?.play()
                            for outURL in outputURLs {
                                print("[RadialDrop] Output created: \(outURL.path)")
                                self.deliverNotification(sourceURL: url, destinationURL: outURL)
                                self.onFileConverted?(url, outURL)
                            }
                        }
                    }
                } catch {
                    print("[RadialDrop] Processing failed for \(url.path): \(error)")
                }
            }

            await MainActor.run {
                self.hide()
            }
        }
    }

    private func deliverNotification(sourceURL: URL, destinationURL: URL) {
        let notification = NSUserNotification()
        notification.title = "RadialDrop Complete"
        notification.informativeText = "\(destinationURL.lastPathComponent)"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func getDraggedURLs(from info: any NSDraggingInfo) -> [URL]? {
        let pasteboard = info.draggingPasteboard
        var results: [URL] = []

        if let nsUrls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
            for u in nsUrls {
                let resolved = (u as URL).resolvingSymlinksInPath().standardizedFileURL
                if !results.contains(resolved) {
                    results.append(resolved)
                }
            }
        }

        if results.isEmpty, let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for f in files {
                let url = URL(fileURLWithPath: f).resolvingSymlinksInPath().standardizedFileURL
                if !results.contains(url) {
                    results.append(url)
                }
            }
        }

        return results.isEmpty ? nil : results
    }
}
