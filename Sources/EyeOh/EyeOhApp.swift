import SwiftUI

@main
@MainActor
struct EyeOhApp: App {
    @State private var store: AudioDeviceStore
    @State private var cameraStore: CameraDeviceStore

    init() {
        let store = AudioDeviceStore(controller: CoreAudioClient())
        store.startMonitoring()
        _store = State(initialValue: store)
        _cameraStore = State(initialValue: CameraDeviceStore(controller: AVCameraClient()))
    }

    var body: some Scene {
        MenuBarExtra {
            EyeOhMenuView(store: store, cameraStore: cameraStore)
        } label: {
            HStack(spacing: 4) {
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
    }
}
