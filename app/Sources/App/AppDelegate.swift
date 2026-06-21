import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let usageService = UsageService()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindow: NSWindow?
    private var previousSnapshot: UsageSnapshot?
    private var iconUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationService.shared.requestAuthorization()
        UpdateService.shared.startPeriodicChecks()
        setupStatusItem()
        setupObservers()
        startIconUpdates()

        Task {
            await usageService.refresh()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        iconUpdateTimer?.invalidate()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemTitle()

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupObservers() {
        usageService.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                NotificationService.shared.handle(snapshot: snapshot, previous: self.previousSnapshot)
                self.previousSnapshot = snapshot
                self.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: .openSettings,
            object: nil
        )
    }

    private var cancellables = Set<AnyCancellable>()

    private func startIconUpdates() {
        iconUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItemTitle()
            }
        }
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }

        if let snapshot = usageService.snapshot {
            let session = Int(snapshot.session.percent.rounded())
            let weekly = Int(snapshot.weekly.percent.rounded())
            let maxUsage = max(session, weekly)

            let symbol: String
            if usageService.isSyncingAfterReset {
                symbol = "⏳"
            } else {
                switch maxUsage {
                case 90...: symbol = "🔴"
                case 75..<90: symbol = "🟠"
                case 50..<75: symbol = "🟡"
                default: symbol = "🟢"
                }
            }

            let sessionLabel = usageService.isSyncingAfterReset && snapshot.session.isStaleAtCap
                ? "sync"
                : "\(session)%"
            button.title = "\(symbol) \(sessionLabel)"
            button.toolTip = usageService.isSyncingAfterReset
                ? "Reset time passed — syncing latest usage from Claude…"
                : "Headroom 5h: \(session)% · Weekly: \(weekly)% · Resets \(ResetTimeFormatter.exact(snapshot.session.resetsAt))"
        } else if usageService.hasCookie {
            button.title = "⏳ …"
            button.toolTip = "Fetching usage"
        } else {
            button.title = "◎"
            button.toolTip = "Headroom — set session cookie in Settings"
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: UsagePopoverView(usageService: usageService)
        )
        self.popover = popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Headroom Settings"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView(usageService: usageService))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
