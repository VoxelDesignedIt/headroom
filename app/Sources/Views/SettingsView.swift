import SwiftUI

struct SettingsView: View {
    @ObservedObject var usageService: UsageService
    @ObservedObject private var updateService = UpdateService.shared
    @State private var cookieInput = ""
    @State private var refreshSeconds = 60.0
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            if let update = updateService.availableUpdate {
                Section("Update Available") {
                    Text("Headroom \(update.version) is available. You are on \(AppConfig.currentVersion). Your session cookie is kept automatically.")
                        .font(.caption)
                    HStack {
                        Button(updateService.isDownloading ? "Updating…" : "Update & Restart") {
                            Task { await updateService.downloadAndInstall() }
                        }
                        .disabled(updateService.isDownloading)

                        Button("Release Notes") {
                            NSWorkspace.shared.open(update.releasePageURL)
                        }
                    }
                    if let error = updateService.downloadError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("Session Cookie") {
                Text("Copy your `sessionKey` from claude.ai (DevTools → Application → Cookies). Saved once — it carries over when you update Headroom.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("sessionKey value or full cookie", text: $cookieInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Cookie") {
                        usageService.saveCookie(cookieInput)
                        cookieInput = ""
                    }
                    .disabled(cookieInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear", role: .destructive) {
                        usageService.clearCookie()
                        cookieInput = ""
                    }
                    .disabled(!usageService.hasCookie)
                }
            }

            Section("Refresh") {
                Slider(value: $refreshSeconds, in: 30...300, step: 30) {
                    Text("Poll every \(Int(refreshSeconds))s")
                }
                .onChange(of: refreshSeconds) { newValue in
                    usageService.updateRefreshInterval(seconds: newValue)
                }
            }

            Section("Notifications") {
                Text("Banner alerts at 50%, 75%, 85%, 95%, and 100%. Reset alerts include your weekly usage and stay in Notification Center until dismissed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Notification Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        LaunchAtLoginService.setEnabled(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .onAppear {
            refreshSeconds = usageService.refreshInterval
            launchAtLogin = LaunchAtLoginService.isEnabled()
            Task { await updateService.checkForUpdates(notifyIfAvailable: false) }
        }
    }
}
