import Foundation

enum AppConfig {
    static let githubRepo = "VoxelDesignedIt/headroom"
    static let releaseAssetName = "Headroom-macOS.zip"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
