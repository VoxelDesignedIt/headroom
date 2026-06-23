import Foundation
import UserNotifications

enum LimitKind: String, CaseIterable {
    case session = "five_hour"
    case weekly = "seven_day"

    var title: String {
        switch self {
        case .session: return "5-hour limit"
        case .weekly: return "Weekly limit"
        }
    }

    var notificationPrefix: String {
        switch self {
        case .session: return "session"
        case .weekly: return "weekly"
        }
    }
}

@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var lastThresholdNotified: [String: Int] = [:]
    private var notifiedResetEpochs: Set<String> = []
    private var scheduledResetEpochs: [String: TimeInterval] = [:]

    private let warningThresholds = [50, 75, 85, 95, 100]

    private override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if !granted {
                print("Notification permission denied.")
            }
        }
    }

    func handle(snapshot: UsageSnapshot?, previous: UsageSnapshot?) {
        guard let snapshot else { return }

        evaluate(window: snapshot.session, kind: .session, snapshot: snapshot, previous: previous?.session)
        evaluate(window: snapshot.weekly, kind: .weekly, snapshot: snapshot, previous: previous?.weekly)

        scheduleExactResetNotification(for: snapshot.session, kind: .session, snapshot: snapshot)
        scheduleExactResetNotification(for: snapshot.weekly, kind: .weekly, snapshot: snapshot)
    }

    func resetDeadlineElapsed(kind: LimitKind, resetsAt: Date, snapshot: UsageSnapshot, usageStillHigh: Bool) {
        let epoch = Int(resetsAt.timeIntervalSince1970)
        let key = "\(kind.notificationPrefix)-deadline-\(epoch)"
        guard !notifiedResetEpochs.contains(key) else { return }
        notifiedResetEpochs.insert(key)

        deliverBanner(
            identifier: key,
            title: resetTitle(for: kind),
            body: resetBody(for: kind, snapshot: snapshot, usageStillHigh: usageStillHigh)
        )
    }

    func notifyUpdateAvailable(_ update: AppUpdate) {
        deliverBanner(
            identifier: "update-\(update.version)",
            title: "Headroom \(update.version) is available",
            body: "You are on \(AppConfig.currentVersion). Open Headroom to download the update.",
            category: "HEADROOM_UPDATE"
        )
    }

    func notifyUpdateDownloaded(version: String, at appURL: URL) {
        deliverBanner(
            identifier: "update-downloaded-\(version)",
            title: "Headroom \(version) installed",
            body: "Headroom is restarting. Your session cookie was kept.",
            category: "HEADROOM_UPDATE"
        )
        _ = appURL
    }

    private func evaluate(
        window: UsageWindow,
        kind: LimitKind,
        snapshot: UsageSnapshot,
        previous: UsageWindow?
    ) {
        let percent = Int(window.percent.rounded())
        let key = kind.rawValue

        for threshold in warningThresholds where percent >= threshold {
            if lastThresholdNotified[key, default: 0] < threshold {
                lastThresholdNotified[key] = threshold
                let weekly = Int(snapshot.weekly.percent.rounded())
                deliverBanner(
                    identifier: "\(key)-warn-\(threshold)",
                    title: "\(kind.title) at \(threshold)%",
                    body: "\(kind.title): \(percent)% · Weekly: \(weekly)% · Resets \(ResetTimeFormatter.exact(window.resetsAt))"
                )
            }
        }

        if percent < 40 {
            lastThresholdNotified[key] = 0
        }

        guard let previous, didWindowReset(current: window, previous: previous, kind: kind) else {
            return
        }

        let alertID = "\(kind.notificationPrefix)-api-reset-\(Int(window.resetsAt.timeIntervalSince1970))"
        guard !notifiedResetEpochs.contains(alertID) else { return }

        notifiedResetEpochs.insert(alertID)
        deliverBanner(
            identifier: alertID,
            title: resetTitle(for: kind),
            body: resetBody(for: kind, snapshot: snapshot, usageStillHigh: false)
        )
    }

    private func resetTitle(for kind: LimitKind) -> String {
        switch kind {
        case .session: return "5-hour limit has reset"
        case .weekly: return "Weekly limit has reset"
        }
    }

    private func resetBody(for kind: LimitKind, snapshot: UsageSnapshot, usageStillHigh: Bool) -> String {
        let weekly = Int(snapshot.weekly.percent.rounded())
        let session = Int(snapshot.session.percent.rounded())

        if usageStillHigh {
            return "Weekly usage: \(weekly)% · 5-hour: \(session)%. Headroom is syncing the latest numbers."
        }

        switch kind {
        case .session:
            return "Weekly usage: \(weekly)% · 5-hour: \(session)%. Next 5-hour reset: \(ResetTimeFormatter.exact(snapshot.session.resetsAt))."
        case .weekly:
            return "Weekly usage: \(weekly)% · 5-hour: \(session)%. Next weekly reset: \(ResetTimeFormatter.exact(snapshot.weekly.resetsAt))."
        }
    }

    private func didWindowReset(current: UsageWindow, previous: UsageWindow, kind: LimitKind) -> Bool {
        let usageDropped = previous.percent - current.percent >= 15
        let usageCleared = current.percent <= 35
        let wasHigh = previous.percent >= 45

        let minimumAdvance: TimeInterval = kind == .session ? 30 * 60 : 12 * 3600
        let resetAdvanced = current.resetsAt.timeIntervalSince(previous.resetsAt) >= minimumAdvance

        return wasHigh && usageCleared && usageDropped && resetAdvanced
    }

    private func scheduleExactResetNotification(
        for window: UsageWindow,
        kind: LimitKind,
        snapshot: UsageSnapshot
    ) {
        let identifier = "\(kind.notificationPrefix)-scheduled-reset"
        let epoch = window.resetsAt.timeIntervalSince1970

        if scheduledResetEpochs[kind.rawValue] == epoch {
            return
        }
        scheduledResetEpochs[kind.rawValue] = epoch

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let secondsUntilReset = window.resetsAt.timeIntervalSinceNow
        if secondsUntilReset <= 1 {
            if window.percent >= 45 {
                resetDeadlineElapsed(
                    kind: kind,
                    resetsAt: window.resetsAt,
                    snapshot: snapshot,
                    usageStillHigh: window.percent >= 90
                )
            }
            return
        }

        let content = UNMutableNotificationContent()
        content.title = resetTitle(for: kind)
        content.body = resetBody(for: kind, snapshot: snapshot, usageStillHigh: false)
        content.sound = .default
        content.categoryIdentifier = "HEADROOM_RESET"
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .active
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: window.resetsAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func deliverBanner(
        identifier: String,
        title: String,
        body: String,
        category: String = "HEADROOM_RESET"
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .active
        }

        let request = UNNotificationRequest(
            identifier: "\(identifier)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func registerCategories() {
        let updateAction = UNNotificationAction(
            identifier: "OPEN_HEADROOM",
            title: "Open Headroom",
            options: [.foreground]
        )
        let updateCategory = UNNotificationCategory(
            identifier: "HEADROOM_UPDATE",
            actions: [updateAction],
            intentIdentifiers: []
        )
        let resetCategory = UNNotificationCategory(
            identifier: "HEADROOM_RESET",
            actions: [],
            intentIdentifiers: []
        )
        center.setNotificationCategories([updateCategory, resetCategory])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == "OPEN_HEADROOM" else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .openSettings, object: nil)
        }
    }
}
