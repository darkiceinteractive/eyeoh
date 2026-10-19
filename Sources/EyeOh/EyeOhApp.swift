import AppKit
import SwiftUI

@main
@MainActor
struct EyeOhApp: App {
    @State private var store: AudioDeviceStore
    @State private var cameraStore: CameraDeviceStore
    @State private var preferences: AppPreferences
    @State private var launchAtLogin: LaunchAtLoginController
    @State private var softwareUpdater: SoftwareUpdateController
    @State private var micMute: MicMuteController
    @State private var hotkeyPreferences: HotkeyPreferences
    @State private var hotkeyCenter: HotkeyCenter
    @State private var shortcutCoordinator: ShortcutCoordinator

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
        let micMute = MicMuteController(client: CoreAudioMicMuteClient())
        micMute.startMonitoring()
        store.globalMuteSource = { micMute.isGlobalMuteActive }
        let hotkeyPreferences = HotkeyPreferences()
        let hotkeyCenter = HotkeyCenter(preferences: hotkeyPreferences)
        let coordinator = ShortcutCoordinator(store: store, micMute: micMute)
        hotkeyCenter.onAction = { coordinator.handle($0) }
        hotkeyCenter.start()
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { micMute.restoreOnQuit() }
        }
        _micMute = State(initialValue: micMute)
        _hotkeyPreferences = State(initialValue: hotkeyPreferences)
        _hotkeyCenter = State(initialValue: hotkeyCenter)
        _shortcutCoordinator = State(initialValue: coordinator)
        _store = State(initialValue: store)
        let cameraStore = CameraDeviceStore(controller: AVCameraClient(), persistence: CameraPersistence())
        cameraStore.startMonitoring()
        _cameraStore = State(initialValue: cameraStore)
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
                softwareUpdater: softwareUpdater,
                micMute: micMute
            )
        } label: {
            HStack(spacing: 3) {
                if micMute.isSilenced {
                    Image(systemName: "mic.slash.fill")
                } else {
                    Image(nsImage: IORouteStatusIcon.image)
                        .opacity(store.selectedDevice == nil ? 0.48 : 1)
                }
                Text(store.menuBarTitle)
            }
            .accessibilityLabel(
                "\(store.statusAccessibilityLabel)\(micMute.isSilenced ? " Microphone muted." : "") Preferred camera: \(cameraStore.selectedCamera?.name ?? "No camera")."
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
                softwareUpdater: softwareUpdater,
                hotkeyPreferences: hotkeyPreferences,
                hotkeyCenter: hotkeyCenter
            )
        }
        .defaultSize(width: 620, height: 540)
    }
}
