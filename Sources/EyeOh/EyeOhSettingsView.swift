import AppKit
import SwiftUI

struct EyeOhSettingsView: View {
    let store: AudioDeviceStore
    let cameraStore: CameraDeviceStore
    let preferences: AppPreferences
    let launchAtLogin: LaunchAtLoginController
    let softwareUpdater: SoftwareUpdateController

    var body: some View {
        TabView {
            GeneralSettingsView(
                store: store,
                cameraStore: cameraStore,
                preferences: preferences,
                launchAtLogin: launchAtLogin,
                softwareUpdater: softwareUpdater
            )
            .tabItem { Label("General", systemImage: "gearshape") }

            PrivacySettingsView(preferences: preferences)
                .tabItem { Label("Privacy", systemImage: "hand.raised") }

            EyeOhHelpView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }

            EyeOhAboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 620, height: 540)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var store: AudioDeviceStore
    let cameraStore: CameraDeviceStore
    @Bindable var preferences: AppPreferences
    @Bindable var launchAtLogin: LaunchAtLoginController
    @Bindable var softwareUpdater: SoftwareUpdateController
    @State private var confirmsClearingBluetoothDevices = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Launch EyeOh at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { enabled in launchAtLogin.setEnabled(enabled) }
                    )
                )

                if launchAtLogin.requiresApproval {
                    LabeledContent {
                        Button("Open Login Items…") {
                            launchAtLogin.openLoginItemsSettings()
                        }
                    } label: {
                        Label("Approval required", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("EyeOh starts quietly in the menu bar. macOS may show it under General → Login Items.")
            }

            if softwareUpdater.isAvailable {
                Section {
                    Toggle(
                        "Automatically check for updates",
                        isOn: Binding(
                            get: { softwareUpdater.automaticallyChecksForUpdates },
                            set: { enabled in
                                softwareUpdater.setAutomaticallyChecksForUpdates(enabled)
                            }
                        )
                    )

                    Toggle(
                        "Download updates automatically",
                        isOn: Binding(
                            get: { softwareUpdater.automaticallyDownloadsUpdates },
                            set: { enabled in
                                softwareUpdater.setAutomaticallyDownloadsUpdates(enabled)
                            }
                        )
                    )
                    .disabled(!softwareUpdater.automaticallyChecksForUpdates)

                    Button("Check for Updates Now…", systemImage: "arrow.triangle.2.circlepath") {
                        softwareUpdater.checkForUpdates()
                    }
                    .disabled(!softwareUpdater.canCheckForUpdates)
                } header: {
                    Text("Software updates")
                } footer: {
                    Text("Direct-download editions use signed EyeOh updates. Mac App Store editions update only through the App Store.")
                }
            }

            Section {
                Button("Refresh Devices", systemImage: "arrow.clockwise") {
                    store.refresh()
                    cameraStore.refresh()
                }

                Button("Open Sound Settings…", systemImage: "speaker.wave.2") {
                    SystemSettingsLinks.openSound()
                }

                Button("Open Bluetooth Settings…", systemImage: "wave.3.right") {
                    SystemSettingsLinks.openBluetooth()
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("Audio devices normally refresh automatically. Use Refresh Devices after reconnecting a camera or unusual virtual device.")
            }

            Section {
                Toggle("Keep my camera selected", isOn: Binding(get: { cameraStore.holdsSelection }, set: { cameraStore.holdsSelection = $0 }))
            } header: {
                Text("Camera")
            } footer: {
                Text("Restores your chosen camera after a restart, wake, or when an iPhone camera appears. Apps that choose their own camera, such as Zoom or Teams, still override this.")
            }

            Section {
                Toggle("Show input volume in menu bar", isOn: $preferences.showsInputVolumeInMenu)
            } header: {
                Text("Menu controls")
            } footer: {
                Text("Output volume is always available for a quick adjustment. Turn this on if you also want microphone input gain in the menu.")
            }


            Section {
                Toggle(
                    "Show disconnected Bluetooth audio devices",
                    isOn: $store.showsDisconnectedBluetoothDevices
                )

                if store.rememberedBluetoothDeviceCount > 0 {
                    Button("Clear Remembered Bluetooth Devices…", role: .destructive) {
                        confirmsClearingBluetoothDevices = true
                    }
                }
            } header: {
                Text("Bluetooth shortcuts")
            } footer: {
                Text("EyeOh remembers only Bluetooth audio devices that have appeared as a Mac input or output. Clicking a disconnected device asks macOS to connect it; EyeOh never pairs new devices automatically.")
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
        .alert("Clear Remembered Bluetooth Devices?", isPresented: $confirmsClearingBluetoothDevices) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearRememberedBluetoothDevices()
            }
        } message: {
            Text("This removes EyeOh's local shortcuts. It does not unpair devices from your Mac or remove their saved volume presets.")
        }
    }
}

private struct PrivacySettingsView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        Form {
            Section("Usage statistics") {
                Toggle("Share private usage statistics", isOn: $preferences.anonymousStatisticsEnabled)
                    .disabled(!Diagnostics.hasStatisticsProvider)

                Text("Allows counts such as app launches, device switches and camera previews. Events use a random installation identifier. EyeOh never includes device names, hardware identifiers, audio, video or free text.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if Diagnostics.hasStatisticsProvider {
                    providerNotice("PostHog is available in this official build. Nothing is sent unless this switch is on.")

                    if preferences.anonymousStatisticsEnabled,
                       let identifier = Telemetry.shared.supportAnalyticsIdentifier {
                        LabeledContent("Analytics ID") {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(identifier, forType: .string)
                            }
                        }
                        Text("Use this random ID only if asking Dark Ice to find or delete your statistics.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    providerNotice("No statistics service is connected in this build, so nothing is sent from your Mac.")
                }
            }

            Section("Crash reporting") {
                Toggle("Share crash reports", isOn: $preferences.crashReportingEnabled)
                    .disabled(!Diagnostics.hasCrashReportingProvider)

                Text("Allows technical crash diagnostics to be submitted without recordings, device lists or contact details.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if Diagnostics.hasCrashReportingProvider {
                    providerNotice("Sentry is available in this official build. Nothing is sent unless this switch is on.")
                } else {
                    providerNotice("No crash-reporting service is connected in this build. You can still send feedback and attach a macOS crash report.")
                }
            }

            Section {
                Button("Send Feedback…", systemImage: "envelope") {
                    FeedbackMail.open()
                    Diagnostics.record(.feedbackOpened)
                }

                Link(
                    "Read Privacy Policy…",
                    destination: URL(string: "https://eyeoh.app/privacy/")!
                )
            } footer: {
                Text("Both reporting choices are off by default and can be changed at any time.")
            }
        }
        .formStyle(.grouped)
    }

    private func providerNotice(_ text: String) -> some View {
        Label(text, systemImage: "lock.shield")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

enum SystemSettingsLinks {
    static func openSound() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    static func openBluetooth() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
