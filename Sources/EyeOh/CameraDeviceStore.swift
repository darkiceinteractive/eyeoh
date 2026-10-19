import Foundation
import Observation

@MainActor
@Observable
final class CameraDeviceStore {
    private let controller: any CameraDeviceControlling
    private let persistence: CameraPersistence?
    private let now: () -> Date
    private var rateLimiter = CameraApplyRateLimiter()
    private var reconcileTask: Task<Void, Never>?

    private(set) var cameras: [CameraDevice] = []
    private(set) var selectedCameraID: String?
    private(set) var errorMessage: String?
    private(set) var savedCamera: SavedCamera?
    var holdsSelection: Bool {
        didSet {
            persistence?.holdsSelection = holdsSelection
            if holdsSelection { reconcile() }
        }
    }

    init(
        controller: any CameraDeviceControlling,
        persistence: CameraPersistence? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.controller = controller
        self.persistence = persistence
        self.now = now
        savedCamera = persistence?.savedCamera
        holdsSelection = persistence?.holdsSelection ?? false
        refresh()
        reconcile()
    }

    var selectedCamera: CameraDevice? {
        cameras.first { $0.id == selectedCameraID }
    }

    /// Menu hint while the saved camera is being held, nil when hold does not apply.
    var holdHint: String? {
        guard holdsSelection, let savedCamera else { return nil }
        if CameraMatcher.match(savedCamera, in: cameras) != nil {
            return "Keeping \(savedCamera.name) selected"
        }
        return "\(savedCamera.name) is not connected. EyeOh will restore it when it returns."
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
            savedCamera = SavedCamera(camera)
            persistence?.savedCamera = savedCamera
            refresh()
            Diagnostics.record(.cameraChanged)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Re-applies the saved camera on camera connect/disconnect, wake, and preferred-camera changes.
    func startMonitoring() {
        guard persistence != nil else { return }
        controller.startMonitoring { [weak self] in
            self?.scheduleReconcile()
        }
    }

    /// Returns true when the saved camera was re-applied.
    @discardableResult
    func reconcile() -> Bool {
        let available = controller.cameras()
        cameras = available
        defer { selectedCameraID = controller.preferredCameraID() }

        guard let target = CameraHoldPolicy.cameraToApply(
            saved: savedCamera,
            holdEnabled: holdsSelection,
            available: available,
            userPreferredID: controller.userPreferredCameraID(),
            systemPreferredID: controller.systemPreferredCameraID()
        ) else {
            return false
        }
        guard rateLimiter.allow(at: now()) else { return false }

        do {
            try controller.setPreferredCamera(target.id)
        } catch {
            return false
        }
        if let savedCamera, savedCamera.id != target.id {
            self.savedCamera = SavedCamera(target)
            persistence?.savedCamera = self.savedCamera
        }
        return true
    }

    private func scheduleReconcile() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            // Devices and the system choice settle shortly after connect or wake.
            for delay in [Duration.milliseconds(500), .seconds(3)] {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self else { return }
                self.reconcile()
            }
        }
    }
}
