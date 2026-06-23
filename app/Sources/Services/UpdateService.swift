import AppKit
import Combine
import Foundation
import UserNotifications

struct AppUpdate: Equatable {
    let version: String
    let releaseNotes: String
    let downloadURL: URL
    let releasePageURL: URL
}

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published var availableUpdate: AppUpdate?
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadError: String?

    private var checkTimer: Timer?

    private init() {}

    func startPeriodicChecks() {
        Task { await checkForUpdates(notifyIfAvailable: false) }

        checkTimer?.invalidate()
        checkTimer = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates(notifyIfAvailable: true)
            }
        }
        RunLoop.main.add(checkTimer!, forMode: .common)
    }

    func checkForUpdates(notifyIfAvailable: Bool) async {
        isChecking = true
        defer { isChecking = false }

        do {
            guard let update = try await fetchLatestRelease() else {
                availableUpdate = nil
                return
            }

            if isNewerVersion(update.version, than: AppConfig.currentVersion) {
                let isFresh = availableUpdate?.version != update.version
                availableUpdate = update
                if notifyIfAvailable && isFresh {
                    NotificationService.shared.notifyUpdateAvailable(update)
                }
            } else {
                availableUpdate = nil
            }
        } catch {
            print("Update check failed: \(error.localizedDescription)")
        }
    }

    func downloadAndInstall() async {
        guard let update = availableUpdate else { return }

        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }

        do {
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let zipURL = downloads.appendingPathComponent("Headroom-\(update.version).zip")
            let extractDir = downloads.appendingPathComponent("Headroom-\(update.version)", isDirectory: true)

            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
            }
            if FileManager.default.fileExists(atPath: extractDir.path) {
                try FileManager.default.removeItem(at: extractDir)
            }

            let (tempURL, _) = try await URLSession.shared.download(from: update.downloadURL)
            try FileManager.default.moveItem(at: tempURL, to: zipURL)
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipURL.path, "-d", extractDir.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "HeadroomUpdate", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not unzip the update."
                ])
            }

            let appURL = extractDir.appendingPathComponent("Headroom.app")
            guard FileManager.default.fileExists(atPath: appURL.path) else {
                throw NSError(domain: "HeadroomUpdate", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Downloaded update did not contain Headroom.app."
                ])
            }

            KeychainService.shared.ensurePortableBackup()
            removeQuarantine(from: appURL)
            try installAndRelaunch(replacing: Bundle.main.bundleURL, with: appURL)
            NotificationService.shared.notifyUpdateDownloaded(version: update.version, at: Bundle.main.bundleURL)
        } catch {
            downloadError = error.localizedDescription
        }
    }

    private func installAndRelaunch(replacing currentApp: URL, with newApp: URL) throws {
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("headroom-update-\(UUID().uuidString).sh")
        let script = """
        #!/bin/bash
        sleep 1.5
        xattr -dr com.apple.quarantine "\(newApp.path)" 2>/dev/null || true
        ditto "\(newApp.path)" "\(currentApp.path)"
        xattr -dr com.apple.quarantine "\(currentApp.path)" 2>/dev/null || true
        open "\(currentApp.path)"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        try process.run()

        NSApp.terminate(nil)
    }

    private func removeQuarantine(from url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? process.run()
        process.waitUntilExit()
    }

    private func fetchLatestRelease() async throws -> AppUpdate? {
        guard let url = URL(string: "https://api.github.com/repos/\(AppConfig.githubRepo)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Headroom/\(AppConfig.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlURLString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlURLString),
              let assets = json["assets"] as? [[String: Any]],
              let asset = assets.first(where: { ($0["name"] as? String) == AppConfig.releaseAssetName }),
              let downloadURLString = asset["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadURLString) else {
            return nil
        }

        let notes = (json["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

        return AppUpdate(
            version: version,
            releaseNotes: notes,
            downloadURL: downloadURL,
            releasePageURL: htmlURL
        )
    }

    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        compareVersions(remote, local) == .orderedDescending
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
