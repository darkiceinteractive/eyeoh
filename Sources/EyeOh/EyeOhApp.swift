import SwiftUI

@main
@MainActor
struct EyeOhApp: App {
    @State private var store: AudioDeviceStore
    @State private var cameraStore: CameraDeviceStore
    @State private var preferences: AppPreferences
    @State private var launchAtLogin: LaunchAtLoginController

    init() {
        Diagnostics.record(.appLaunched)
        let store = AudioDeviceStore(controller: CoreAudioClient())
        store.startMonitoring()
        _store = State(initialValue: store)
        _cameraStore = State(initialValue: CameraDeviceStore(controller: AVCameraClient()))
        _preferences = State(initialValue: AppPreferences())
        _launchAtLogin = State(initialValue: LaunchAtLoginController())
    }

    var body: some Scene {
        MenuBarExtra {
            EyeOhMenuView(store: store, cameraStore: cameraStore)
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
        .menuBarExtraStyle(.menu)

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
                launchAtLogin: launchAtLogin
            )
        }
        .defaultSize(width: 620, height: 540)
    }
}
