import Foundation
import AppKit

public struct HWPConverter: Sendable {
    public init() {}

    public static var isHancomInstalled: Bool {
        return FileManager.default.fileExists(atPath: "/Applications/Hancom Office HWP.app")
    }

    /// Converts an HWP/HWPX file to PDF using the installed Hancom Office HWP.
    @discardableResult
    public func convertToPDF(sourceURL: URL) throws -> URL {
        guard HWPConverter.isHancomInstalled else {
            throw ConversionError.unsupportedTargetType(.pdf)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = directory.appendingPathComponent("\(baseName).pdf")

        let appleScript = """
        set sourcePath to "\(sourceURL.path)"
        set destPath to "\(destinationURL.path)"

        tell application "Hancom Office HWP"
            activate
            open POSIX file sourcePath
        end tell

        delay 1.0

        tell application "System Events"
            tell process "Hancom Office HWP"
                try
                    click menu item "PDF로 저장하기..." of menu "파일" of menu bar 1
                on error
                    try
                        click menu item "Save as PDF..." of menu "File" of menu bar 1
                    end try
                end try

                delay 0.8
                -- Open Go to Folder sheet in the save panel
                keystroke "g" using {command down, shift down}
                delay 0.5
                keystroke destPath
                delay 0.4
                keystroke return
                delay 0.5
                keystroke return
            end tell
        end tell

        delay 1.0

        tell application "Hancom Office HWP"
            close front window saving no
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("[HWPConverter] AppleScript error: \(error)")
            }
        }

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }

    /// Converts an HWP/HWPX file to Microsoft Word (DOCX) using Hancom Office HWP.
    @discardableResult
    public func convertToWord(sourceURL: URL) throws -> URL {
        guard HWPConverter.isHancomInstalled else {
            throw ConversionError.unsupportedTargetType(.data)
        }

        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let destinationURL = directory.appendingPathComponent("\(baseName).docx")

        let appleScript = """
        set sourcePath to "\(sourceURL.path)"
        set destPath to "\(destinationURL.path)"

        tell application "Hancom Office HWP"
            activate
            open POSIX file sourcePath
        end tell

        delay 1.0

        tell application "System Events"
            tell process "Hancom Office HWP"
                try
                    click menu item "다른 이름으로 저장..." of menu "파일" of menu bar 1
                on error
                    try
                        click menu item "Save As..." of menu "File" of menu bar 1
                    end try
                end try

                delay 0.8
                -- Select Word (.docx) format from popup button if accessible
                try
                    set formatPopUp to pop up button 1 of group 1 of sheet 1 of window 1
                    click formatPopUp
                    delay 0.3
                    click menu item "워드 문서 (*.docx)" of menu 1 of formatPopUp
                end try

                delay 0.5
                -- Go to folder and save
                keystroke "g" using {command down, shift down}
                delay 0.5
                keystroke destPath
                delay 0.4
                keystroke return
                delay 0.5
                keystroke return
            end tell
        end tell

        delay 1.0

        tell application "Hancom Office HWP"
            close front window saving no
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("[HWPConverter] AppleScript error: \(error)")
            }
        }

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ConversionError.destinationFinalizationFailed(destinationURL)
        }

        return destinationURL
    }
}
