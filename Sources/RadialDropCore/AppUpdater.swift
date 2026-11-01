import Foundation
import AppKit

public struct AppVersion: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let rawString: String

    public init(_ string: String) {
        self.rawString = string
        let cleaned = string.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        self.major = parts.indices.contains(0) ? parts[0] : 0
        self.minor = parts.indices.contains(1) ? parts[1] : 0
        self.patch = parts.indices.contains(2) ? parts[2] : 0
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

public struct GitHubRelease: Decodable, Sendable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlUrl: String
    public let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

public struct GitHubAsset: Decodable, Sendable {
    public let name: String
    public let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

public enum UpdateCheckResult: Sendable {
    case updateAvailable(latestVersion: String, release: GitHubRelease)
    case upToDate(currentVersion: String)
    case error(String)
}

public final class AppUpdater: @unchecked Sendable {
    public static let shared = AppUpdater()

    public static var currentVersionString: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !version.isEmpty {
            return version
        }
        return "1.0.3"
    }

    private let repoOwner = "minsukwak0208"
    private let repoName = "RadialDrop"

    private init() {}

    public func checkForUpdates(completion: @escaping @Sendable (UpdateCheckResult) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            completion(.error("Invalid GitHub API URL"))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("RadialDrop-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.error(error.localizedDescription))
                return
            }

            guard let data = data else {
                completion(.error("No data received from GitHub"))
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let latestVersion = AppVersion(release.tagName)
                let currentVersion = AppVersion(Self.currentVersionString)

                if latestVersion > currentVersion {
                    completion(.updateAvailable(latestVersion: release.tagName, release: release))
                } else {
                    completion(.upToDate(currentVersion: Self.currentVersionString))
                }
            } catch {
                completion(.error("Failed to parse release information: \(error.localizedDescription)"))
            }
        }
        task.resume()
    }

    public func downloadAndInstall(release: GitHubRelease, progressHandler: @escaping @Sendable (String) -> Void, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) ??
                release.assets.first else {
            completion(.failure(NSError(domain: "RadialDropUpdater", code: 404, userInfo: [NSLocalizedDescriptionKey: "Release zip asset not found."])))
            return
        }

        guard let downloadUrl = URL(string: zipAsset.browserDownloadUrl) else {
            completion(.failure(NSError(domain: "RadialDropUpdater", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL."])))
            return
        }

        progressHandler("Downloading update package...")

        let downloadTask = URLSession.shared.downloadTask(with: downloadUrl) { tempLocation, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let tempLocation = tempLocation else {
                completion(.failure(NSError(domain: "RadialDropUpdater", code: 500, userInfo: [NSLocalizedDescriptionKey: "Download failed."])))
                return
            }

            do {
                let fileManager = FileManager.default
                let updateDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RadialDropUpdate_\(UUID().uuidString)")
                try fileManager.createDirectory(at: updateDir, withIntermediateDirectories: true)

                let localZipPath = updateDir.appendingPathComponent("RadialDrop.zip")
                try fileManager.moveItem(at: tempLocation, to: localZipPath)

                progressHandler("Extracting update package...")

                // Unzip using ditto
                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-xk", localZipPath.path, updateDir.path]
                try ditto.run()
                ditto.waitUntilExit()

                let newAppURL = updateDir.appendingPathComponent("RadialDrop.app")
                guard fileManager.fileExists(atPath: newAppURL.path) else {
                    completion(.failure(NSError(domain: "RadialDropUpdater", code: 502, userInfo: [NSLocalizedDescriptionKey: "Extracted update is missing RadialDrop.app"])))
                    return
                }

                // Remove quarantine flag
                let xattr = Process()
                xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattr.arguments = ["-dr", "com.apple.quarantine", newAppURL.path]
                try? xattr.run()
                xattr.waitUntilExit()

                // Target bundle URL (e.g. /Applications/RadialDrop.app)
                var targetURL = Bundle.main.bundleURL
                if !targetURL.path.hasSuffix(".app") || !fileManager.fileExists(atPath: targetURL.path) {
                    targetURL = URL(fileURLWithPath: "/Applications/RadialDrop.app")
                }

                progressHandler("Applying update and restarting...")

                let currentPID = ProcessInfo.processInfo.processIdentifier
                let scriptContent = """
                #!/bin/sh
                sleep 0.5
                while kill -0 \(currentPID) 2>/dev/null; do
                    sleep 0.2
                done
                rm -rf "\(targetURL.path)"
                cp -R "\(newAppURL.path)" "\(targetURL.path)"
                rm -rf "\(updateDir.path)"
                open "\(targetURL.path)"
                """

                let scriptURL = updateDir.appendingPathComponent("restart.sh")
                try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

                let chmod = Process()
                chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
                chmod.arguments = ["+x", scriptURL.path]
                try chmod.run()
                chmod.waitUntilExit()

                // Launch helper script detached
                let launchProcess = Process()
                launchProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
                launchProcess.arguments = ["-c", "\(scriptURL.path) > /dev/null 2>&1 &"]
                try launchProcess.run()

                completion(.success(()))

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.terminate(nil)
                }
            } catch {
                completion(.failure(error))
            }
        }
        downloadTask.resume()
    }
}
