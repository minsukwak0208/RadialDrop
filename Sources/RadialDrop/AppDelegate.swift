import AppKit
import RadialDropCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var permissionMenuItem: NSMenuItem!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from showing in the Dock (agent app)
        NSApp.setActivationPolicy(.accessory)

        setupStatusBar()
        checkPermissionsAndStart()

        // Set callback for successful conversion
        EventMonitor.shared.panel.onFileConverted = { source, destination in
            print("[RadialDrop] Successfully converted: \(source.lastPathComponent) -> \(destination.lastPathComponent)")
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "RadialDrop")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "RadialDrop (Tangerine)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        statusMenuItem = NSMenuItem(title: "Checking status...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        permissionMenuItem = NSMenuItem(
            title: "Request Accessibility Permission...",
            action: #selector(requestPermissionClicked),
            keyEquivalent: ""
        )
        permissionMenuItem.target = self
        menu.addItem(permissionMenuItem)

        menu.addItem(NSMenuItem.separator())

        let testWheelItem = NSMenuItem(
            title: "Show Demo Wheel at Cursor",
            action: #selector(showDemoWheelClicked),
            keyEquivalent: "d"
        )
        testWheelItem.target = self
        menu.addItem(testWheelItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func checkPermissionsAndStart() {
        let isTrusted = EventMonitor.isAccessibilityTrusted()
        if isTrusted {
            statusMenuItem.title = "● Active (Hold Shift while dragging files)"
            permissionMenuItem.isHidden = true
            EventMonitor.shared.start()
        } else {
            statusMenuItem.title = "⚠ Needs Accessibility Permission"
            permissionMenuItem.isHidden = false
            EventMonitor.requestAccessibilityPermissions()
            // Even if not initially trusted, start monitor so it catches events once granted
            EventMonitor.shared.start()
        }
    }

    @objc private func requestPermissionClicked() {
        EventMonitor.requestAccessibilityPermissions()
        // Open System Settings -> Privacy & Security -> Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showDemoWheelClicked() {
        let mouseLocation = NSEvent.mouseLocation
        let items = [
            RadialItem(id: "png", title: "PNG", iconName: "photo", targetType: .png),
            RadialItem(id: "jpeg", title: "JPG", iconName: "photo.artframe", targetType: .jpeg),
            RadialItem(id: "webp", title: "WebP", iconName: "sparkles", targetType: .webP),
            RadialItem(id: "heic", title: "HEIC", iconName: "camera.viewfinder", targetType: .heic),
            RadialItem(id: "tiff", title: "TIFF", iconName: "doc.richtext", targetType: .tiff),
            RadialItem(id: "pdf", title: "PDF", iconName: "doc.text.fill", targetType: .pdf)
        ]
        EventMonitor.shared.panel.show(at: mouseLocation, items: items, urls: [])
    }

    @objc private func quitClicked() {
        EventMonitor.shared.stop()
        NSApp.terminate(nil)
    }
}
