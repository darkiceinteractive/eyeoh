import SwiftUI

@main
@MainActor
struct EyeOhApp: App {
    @State private var store: AudioDeviceStore
    @State private var cameraStore: CameraDeviceStore
    @State private var preferences: AppPreferences
    @State private var launchAtLogin: LaunchAtLoginController
    @State private var softwareUpdater: SoftwareUpdateController

    init() {
        let store = AudioDeviceStore(controller: CoreAudioClient())
        store.startMonitoring()
        let preferences = AppPreferences()
        preferences.reconcileProviderAvailability(
            statisticsAvailable: Telemetry.shared.hasStatisticsProvider,
            crashReportingAvailable: Telemetry.shared.hasCrashReportingProvider
        )
        preferences.activateTelemetry()
        Diagnostics.record(.appLaunched)
        _store = State(initialValue: store)
        _cameraStore = State(initialValue: CameraDeviceStore(controller: AVCameraClient()))
        _preferences = State(initialValue: preferences)
        _launchAtLogin = State(initialValue: LaunchAtLoginController())
        _softwareUpdater = State(initialValue: SoftwareUpdateController())
    }

    var body: some Scene {
        MenuBarExtra {
            EyeOhMenuView(
                store: store,
                cameraStore: cameraStore,
                preferences: preferences,
                softwareUpdater: softwareUpdater
            )
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: IORouteStatusIcon.image)
                    .opacity(store.selectedDevice == nil ? 0.48 : 1)
                Text(store.menuBarTitle)
            }
            .accessibilityLabel(
                "\(store.statusAccessibilityLabel) Preferred camera: \(cameraStore.selectedCamera?.name ?? "No camera")."
            )
        }
        .menuBarExtraStyle(.window)

        Window("Camera Preview", id: "camera-preview") {
            CameraPreviewWindow(cameraStore: cameraStore)
        }
        .defaultSize(width: 680, height: 500)
        .windowResizability(.contentMinSize)

        Settings {
            EyeOhSettingsView(
                store: store,
                cameraStore: cameraStore,
                preferences: preferences,
                launchAtLogin: launchAtLogin,
                softwareUpdater: softwareUpdater
            )
        }
        .defaultSize(width: 620, height: 540)
    }
}
