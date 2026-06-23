import SwiftUI

struct UsageBarView: View {
    let title: String
    let percent: Double
    let resetsAt: Date
    var isStale: Bool = false

    private var barColor: Color {
        switch percent {
        case 90...: return .red
        case 75..<90: return .orange
        case 50..<75: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(isStale ? "Syncing…" : "\(Int(percent.rounded()))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(barColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geometry.size.width * CGFloat(min(percent, 100) / 100))
                }
            }
            .frame(height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Resets: \(ResetTimeFormatter.exact(resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("In \(ResetTimeFormatter.countdown(to: resetsAt))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if isStale {
                    Text("Reset time passed — fetching updated usage")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct UsagePopoverView: View {
    @ObservedObject var usageService: UsageService
    @ObservedObject private var updateService = UpdateService.shared
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Headroom")
                    .font(.title3.bold())
                Spacer()
                if usageService.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let update = updateService.availableUpdate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Update \(update.version) available")
                        .font(.subheadline.bold())
                    Button(updateService.isDownloading ? "Updating…" : "Update & Restart") {
                        Task { await updateService.downloadAndInstall() }
                    }
                    .disabled(updateService.isDownloading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let snapshot = usageService.snapshot {
                UsageBarView(
                    title: "5-hour window",
                    percent: snapshot.session.percent,
                    resetsAt: snapshot.session.resetsAt,
                    isStale: snapshot.session.isStaleAtCap
                )
                UsageBarView(
                    title: "Weekly limit",
                    percent: snapshot.weekly.percent,
                    resetsAt: snapshot.weekly.resetsAt,
                    isStale: snapshot.weekly.isStaleAtCap
                )

                if let sonnet = snapshot.weeklySonnet {
                    UsageBarView(
                        title: "Weekly Sonnet",
                        percent: sonnet.percent,
                        resetsAt: sonnet.resetsAt
                    )
                }

                if let opus = snapshot.weeklyOpus {
                    UsageBarView(
                        title: "Weekly Opus",
                        percent: opus.percent,
                        resetsAt: opus.resetsAt
                    )
                }

                Text("Updated \(ResetTimeFormatter.exact(snapshot.lastUpdated))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if let error = usageService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Set your session cookie in Settings to begin tracking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Refresh") {
                    Task { await usageService.refresh() }
                }
                Spacer()
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onReceive(tick) { value in
            now = value
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("HeadroomOpenSettings")
}
