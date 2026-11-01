import AppKit
import Foundation

@MainActor
public final class EventMonitor {
    public static let shared = EventMonitor()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isDraggingWithShift = false

    public let panel = RadialPanel()

    private init() {}

    /// Checks if Accessibility permissions are granted.
    public static func isAccessibilityTrusted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility permissions in System Settings.
    public static func requestAccessibilityPermissions() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Starts monitoring for Shift + Drag events.
    public func start() {
        stop()

        let eventMask: NSEvent.EventTypeMask = [
            .leftMouseDragged,
            .flagsChanged,
            .leftMouseUp
        ]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
            return event
        }
    }

    public func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        panel.hide()
        isDraggingWithShift = false
    }

    private func handleEvent(_ event: NSEvent) {
        let isLeftMouseDown = (NSEvent.pressedMouseButtons & 1) != 0
        let modifiers = NSEvent.modifierFlags
        let isShiftDown = modifiers.contains(.shift)
        let isOptionDown = modifiers.contains(.option)

        switch event.type {
        case .leftMouseDragged:
            if isLeftMouseDown && isShiftDown {
                triggerWheelIfNeeded(isOptionDown: isOptionDown)
            }

        case .flagsChanged:
            if isShiftDown && isLeftMouseDown {
                triggerWheelIfNeeded(isOptionDown: isOptionDown)
            } else if !isShiftDown {
                if !panel.isProcessing {
                    dismissWheel()
                }
            }

        case .leftMouseUp:
            // Delay dismissal slightly to allow AppKit performDragOperation to complete
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                if !self.panel.isProcessing {
                    self.dismissWheel()
                }
            }

        default:
            break
        }
    }

    private func triggerWheelIfNeeded(isOptionDown: Bool) {
        let mouseLocation = NSEvent.mouseLocation

        let dragPasteboard = NSPasteboard(name: .drag)
        var draggedURLs: [URL] = []
        if let nsUrls = dragPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
            draggedURLs = nsUrls.map { ($0 as URL).resolvingSymlinksInPath().standardizedFileURL }
        }
        if draggedURLs.isEmpty, let files = dragPasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            draggedURLs = files.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL }
        }

        let inspector = FileInspector()
        let items: [RadialItem]
        if let first = draggedURLs.first {
            items = inspector.getConversionItems(for: first, isAdvancedMode: isOptionDown)
        } else {
            items = [
                RadialItem(id: "png", title: "PNG", iconName: "photo", targetType: .png),
                RadialItem(id: "jpeg", title: "JPG", iconName: "photo.artframe", targetType: .jpeg),
                RadialItem(id: "webp", title: "WebP", iconName: "sparkles", targetType: .webP),
                RadialItem(id: "heic", title: "HEIC", iconName: "camera.viewfinder", targetType: .heic),
                RadialItem(id: "tiff", title: "TIFF", iconName: "doc.richtext", targetType: .tiff),
                RadialItem(id: "pdf", title: "PDF", iconName: "doc.text.fill", targetType: .pdf)
            ]
        }

        if !isDraggingWithShift {
            isDraggingWithShift = true
            panel.show(at: mouseLocation, items: items, urls: draggedURLs)
        }
    }

    private func dismissWheel() {
        if isDraggingWithShift {
            isDraggingWithShift = false
            panel.hide()
        }
    }
}
