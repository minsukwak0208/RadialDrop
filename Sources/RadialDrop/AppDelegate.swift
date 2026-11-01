import AppKit
import RadialDropCore
import UserNotifications

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var permissionMenuItem: NSMenuItem!
    private var soundMenuItem: NSMenuItem!
    private var updateMenuItem: NSMenuItem!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        setupStatusBar()
        checkPermissionsAndStart()

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

        let titleItem = NSMenuItem(title: "RadialDrop (v\(AppUpdater.currentVersionString))", action: nil, keyEquivalent: "")
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

        // Sound Toggle Menu Item
        let isSoundOn = EventMonitor.shared.panel.isSoundEnabled
        soundMenuItem = NSMenuItem(
            title: isSoundOn ? "✓ Sound Effects" : "Sound Effects (Muted)",
            action: #selector(toggleSoundClicked),
            keyEquivalent: "s"
        )
        soundMenuItem.target = self
        menu.addItem(soundMenuItem)

        let testWheelItem = NSMenuItem(
            title: "Show Demo Wheel at Cursor",
            action: #selector(showDemoWheelClicked),
            keyEquivalent: "d"
        )
        testWheelItem.target = self
        menu.addItem(testWheelItem)

        updateMenuItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdatesClicked),
            keyEquivalent: "u"
        )
        updateMenuItem.target = self
        menu.addItem(updateMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit RadialDrop",
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
            EventMonitor.shared.start()
        }
    }

    @objc private func toggleSoundClicked() {
        let current = EventMonitor.shared.panel.isSoundEnabled
        EventMonitor.shared.panel.isSoundEnabled = !current
        soundMenuItem.title = (!current) ? "✓ Sound Effects" : "Sound Effects (Muted)"
    }

    @objc private func requestPermissionClicked() {
        EventMonitor.requestAccessibilityPermissions()
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

    @objc private func checkForUpdatesClicked() {
        updateMenuItem.title = "Checking for Updates..."
        updateMenuItem.isEnabled = false

        AppUpdater.shared.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateMenuItem.title = "Check for Updates..."
                self.updateMenuItem.isEnabled = true

                NSApp.activate(ignoringOtherApps: true)

                switch result {
                case .upToDate(let version):
                    let alert = NSAlert()
                    alert.messageText = "최신 버전을 사용 중입니다"
                    alert.informativeText = "현재 설치된 RadialDrop v\(version)은(는) 최신 버전입니다."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "확인")
                    alert.runModal()

                case .updateAvailable(let latestVersion, let release):
                    let alert = NSAlert()
                    alert.messageText = "새로운 버전이 출시되었습니다: \(latestVersion)"
                    var message = "현재 버전: v\(AppUpdater.currentVersionString)\n최신 버전: \(latestVersion)\n\n지금 바로 업데이트하시겠습니까?"
                    if let body = release.body, !body.isEmpty {
                        message += "\n\n[릴리즈 노트]\n" + body
                    }
                    alert.informativeText = message
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "지금 업데이트")
                    alert.addButton(withTitle: "GitHub에서 보기")
                    alert.addButton(withTitle: "나중에")

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        self.performUpdate(release: release)
                    } else if response == .alertSecondButtonReturn {
                        if let url = URL(string: release.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                case .error(let errorMsg):
                    let alert = NSAlert()
                    alert.messageText = "업데이트 확인 실패"
                    alert.informativeText = "업데이트 서버에 연결할 수 없습니다:\n\(errorMsg)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "확인")
                    alert.runModal()
                }
            }
        }
    }

    private func performUpdate(release: GitHubRelease) {
        let content = UNMutableNotificationContent()
        content.title = "RadialDrop 업데이트 중"
        content.body = "새 버전(\(release.tagName))을 다운로드하여 적용하고 있습니다..."
        let request = UNNotificationRequest(identifier: "RadialDropUpdate", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)

        AppUpdater.shared.downloadAndInstall(release: release) { progress in
            print("[RadialDrop Updater] \(progress)")
        } completion: { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    NSApp.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = "업데이트 적용 실패"
                    alert.informativeText = "자동 업데이트를 완료하지 못했습니다:\n\(error.localizedDescription)\n\nHomebrew (`brew upgrade --cask radialdrop`)를 통해 업데이트할 수도 있습니다."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "GitHub 릴리즈 열기")
                    alert.addButton(withTitle: "닫기")
                    if alert.runModal() == .alertFirstButtonReturn {
                        if let url = URL(string: release.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    @objc private func quitClicked() {
        EventMonitor.shared.stop()
        NSApp.terminate(nil)
    }
}
