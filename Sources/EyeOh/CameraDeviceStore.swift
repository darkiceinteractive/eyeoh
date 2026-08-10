import Foundation
import Observation

@MainActor
@Observable
final class CameraDeviceStore {
    private let controller: any CameraDeviceControlling

    private(set) var cameras: [CameraDevice] = []
    private(set) var selectedCameraID: String?
    private(set) var errorMessage: String?

    init(controller: any CameraDeviceControlling) {
        self.controller = controller
        refresh()
    }

    var selectedCamera: CameraDevice? {
        cameras.first { $0.id == selectedCameraID }
    }

    func refresh() {
        cameras = controller.cameras()
        selectedCameraID = controller.preferredCameraID()
        errorMessage = nil
    }

    func select(_ camera: CameraDevice) {
        guard camera.id != selectedCameraID else { return }
        do {
            try controller.setPreferredCamera(camera.id)
            refresh()
            Diagnostics.record(.cameraChanged)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
