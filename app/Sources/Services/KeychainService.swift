import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.headroom.app"
    private let accountName = "sessionCookie"
    private let legacyServiceNames = ["com.claudelimit.app"]

    private init() {}

    private var cookieFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent(serviceName, isDirectory: true)
            .appendingPathComponent("session.cookie")
    }

    /// Copies the session cookie to Application Support so updates survive ad-hoc rebuilds.
    func ensurePortableBackup() {
        guard readCookieFile() == nil else { return }

        if let cookie = readKeychain(service: serviceName) {
            _ = writeCookieFile(cookie)
            return
        }

        for legacy in legacyServiceNames {
            if let cookie = readKeychain(service: legacy) {
                _ = saveCookie(cookie)
                deleteKeychain(service: legacy)
                return
            }
        }
    }

    func migrateStoredCredentialsIfNeeded() {
        ensurePortableBackup()

        if readCookieFile() != nil {
            if readKeychain(service: serviceName) == nil, let cookie = readCookieFile() {
                _ = writeKeychain(cookie)
            }
            return
        }

        if let cookie = readKeychain(service: serviceName) {
            _ = writeCookieFile(cookie)
            return
        }

        for legacy in legacyServiceNames {
            if let cookie = readKeychain(service: legacy) {
                _ = saveCookie(cookie)
                deleteKeychain(service: legacy)
                return
            }
        }
    }

    func saveCookie(_ cookie: String) -> Bool {
        deleteCookie(skipFile: false)
        guard cookie.data(using: .utf8) != nil else { return false }

        let keychainSaved = writeKeychain(cookie)
        let fileSaved = writeCookieFile(cookie)
        return keychainSaved || fileSaved
    }

    func getCookie() -> String? {
        if let cookie = readCookieFile() {
            return cookie
        }
        if let cookie = readKeychain(service: serviceName) {
            _ = writeCookieFile(cookie)
            return cookie
        }
        for legacy in legacyServiceNames {
            if let cookie = readKeychain(service: legacy) {
                _ = saveCookie(cookie)
                deleteKeychain(service: legacy)
                return cookie
            }
        }
        return nil
    }

    @discardableResult
    func deleteCookie(skipFile: Bool = false) -> Bool {
        deleteKeychain(service: serviceName)
        for legacy in legacyServiceNames {
            deleteKeychain(service: legacy)
        }
        if !skipFile {
            deleteCookieFile()
        }
        return true
    }

    // MARK: - Keychain

    @discardableResult
    private func writeKeychain(_ cookie: String) -> Bool {
        guard let data = cookie.data(using: .utf8) else { return false }
        deleteKeychain(service: serviceName)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func readKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let cookie = String(data: data, encoding: .utf8) else {
            return nil
        }
        return cookie
    }

    @discardableResult
    private func deleteKeychain(service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountName
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Application Support

    @discardableResult
    private func writeCookieFile(_ cookie: String) -> Bool {
        guard let data = cookie.data(using: .utf8) else { return false }

        let directory = cookieFileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: cookieFileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: cookieFileURL.path
            )
            return true
        } catch {
            print("Failed to save session cookie backup: \(error.localizedDescription)")
            return false
        }
    }

    private func readCookieFile() -> String? {
        guard let data = try? Data(contentsOf: cookieFileURL),
              let cookie = String(data: data, encoding: .utf8),
              !cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return cookie
    }

    private func deleteCookieFile() {
        try? FileManager.default.removeItem(at: cookieFileURL)
    }
}
