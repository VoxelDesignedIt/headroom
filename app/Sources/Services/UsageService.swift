import Foundation
import Combine

@MainActor
final class UsageService: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCookie = false
    @Published var isSyncingAfterReset = false

    private var organizationID: String?
    private var refreshTimer: Timer?
    private var resetTimers: [Timer] = []
    private var overdueBurstTimer: Timer?
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    var refreshInterval: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: "refreshIntervalSeconds")
        return stored > 0 ? stored : 60
    }

    init() {
        KeychainService.shared.migrateStoredCredentialsIfNeeded()
        hasCookie = KeychainService.shared.getCookie() != nil
        if hasCookie {
            startAutoRefresh()
            Task { await refresh() }
        }
    }

    func saveCookie(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let cookie: String
        if trimmed.contains("sessionKey=") {
            cookie = trimmed
        } else {
            cookie = "sessionKey=\(trimmed)"
        }

        guard KeychainService.shared.saveCookie(cookie) else {
            errorMessage = "Failed to save cookie to Keychain."
            return
        }

        organizationID = nil
        hasCookie = true
        startAutoRefresh()
        Task { await refresh() }
    }

    func clearCookie() {
        KeychainService.shared.deleteCookie()
        hasCookie = false
        snapshot = nil
        organizationID = nil
        errorMessage = nil
        isSyncingAfterReset = false
        stopAutoRefresh()
        stopOverdueBurst()
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func updateRefreshInterval(seconds: TimeInterval) {
        UserDefaults.standard.set(seconds, forKey: "refreshIntervalSeconds")
        if hasCookie {
            startAutoRefresh()
        }
    }

    func refresh() async {
        guard let cookie = KeychainService.shared.getCookie() else {
            hasCookie = false
            errorMessage = UsageServiceError.missingCookie.localizedDescription
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if organizationID == nil {
                organizationID = try await fetchOrganizationID(cookie: cookie)
            }
            guard let organizationID else {
                throw UsageServiceError.organizationNotFound
            }
            let usage = try await fetchUsage(cookie: cookie, organizationID: organizationID)
            snapshot = usage
            errorMessage = nil
            updateSyncingState(for: usage)
            scheduleResetRefreshes(for: usage)
        } catch let error as UsageServiceError {
            errorMessage = error.localizedDescription
            if case .unauthorized = error {
                organizationID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateSyncingState(for usage: UsageSnapshot) {
        let stale = usage.session.isStaleAtCap || usage.weekly.isStaleAtCap
        isSyncingAfterReset = stale
        if stale {
            startOverdueBurst()
        } else {
            stopOverdueBurst()
        }
    }

    private func fetchOrganizationID(cookie: String) async throws -> String {
        guard let url = cacheBustedURL("https://claude.ai/api/organizations") else {
            throw UsageServiceError.invalidURL
        }

        let (data, response) = try await session.data(for: makeRequest(url: url, cookie: cookie))
        try validate(response: response, data: data)

        guard let organizations = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = organizations.first,
              let uuid = first["uuid"] as? String else {
            throw UsageServiceError.organizationNotFound
        }
        return uuid
    }

    private func fetchUsage(cookie: String, organizationID: String) async throws -> UsageSnapshot {
        guard let url = cacheBustedURL("https://claude.ai/api/organizations/\(organizationID)/usage") else {
            throw UsageServiceError.invalidURL
        }

        let (data, response) = try await session.data(for: makeRequest(url: url, cookie: cookie))
        try validate(response: response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageServiceError.invalidResponse
        }

        guard let sessionWindow = parseWindow(json["five_hour"]),
              let weeklyWindow = parseWindow(json["seven_day"]) else {
            if let raw = String(data: data, encoding: .utf8) {
                print("Headroom parse failure: \(raw.prefix(300))")
            }
            throw UsageServiceError.invalidResponse
        }

        return UsageSnapshot(
            session: sessionWindow,
            weekly: weeklyWindow,
            weeklySonnet: parseWindow(json["seven_day_sonnet"]),
            weeklyOpus: parseWindow(json["seven_day_opus"]),
            lastUpdated: Date()
        )
    }

    private func cacheBustedURL(_ string: String) -> URL? {
        guard var components = URLComponents(string: string) else { return nil }
        components.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
        return components.url
    }

    private func scheduleResetRefreshes(for usage: UsageSnapshot) {
        resetTimers.forEach { $0.invalidate() }
        resetTimers.removeAll()

        let windows: [(LimitKind, UsageWindow)] = [
            (.session, usage.session),
            (.weekly, usage.weekly)
        ]

        for (kind, window) in windows {
            let secondsUntilReset = window.resetsAt.timeIntervalSinceNow

            if secondsUntilReset <= 0 {
                NotificationService.shared.resetDeadlineElapsed(
                    kind: kind,
                    resetsAt: window.resetsAt,
                    snapshot: usage,
                    usageStillHigh: window.percent >= 90
                )
                startOverdueBurst()
                continue
            }

            let fireAtReset = Timer(fire: window.resetsAt, interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                    if let snapshot = self?.snapshot {
                        NotificationService.shared.resetDeadlineElapsed(
                            kind: kind,
                            resetsAt: window.resetsAt,
                            snapshot: snapshot,
                            usageStillHigh: snapshot.session.percent >= 90 || snapshot.weekly.percent >= 90
                        )
                    }
                    self?.startOverdueBurst()
                }
            }
            RunLoop.main.add(fireAtReset, forMode: .common)
            resetTimers.append(fireAtReset)

            let leadUp = max(0, secondsUntilReset - 45)
            let preResetTimer = Timer(timeInterval: leadUp, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                    self?.startOverdueBurst()
                }
            }
            RunLoop.main.add(preResetTimer, forMode: .common)
            resetTimers.append(preResetTimer)
        }
    }

    private func startOverdueBurst() {
        guard overdueBurstTimer == nil else { return }

        var polls = 0
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] timer in
            polls += 1
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refresh()
                if !self.isSyncingAfterReset || polls >= 40 {
                    timer.invalidate()
                    self.overdueBurstTimer = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        overdueBurstTimer = timer
    }

    private func stopOverdueBurst() {
        overdueBurstTimer?.invalidate()
        overdueBurstTimer = nil
    }

    private func makeRequest(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "Referer")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw UsageServiceError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw UsageServiceError.unauthorized
        default:
            if let body = String(data: data, encoding: .utf8) {
                print("Claude API error \(http.statusCode): \(body.prefix(200))")
            }
            throw UsageServiceError.serverError(http.statusCode)
        }
    }

    private func parseWindow(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let utilization = parseUtilization(dict["utilization"]),
              let resetString = parseResetString(dict["resets_at"]),
              let resetsAt = parseISO8601(resetString) else {
            return nil
        }
        return UsageWindow(utilization: utilization, resetsAt: resetsAt)
    }

    private func parseResetString(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        return nil
    }

    private func parseUtilization(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
