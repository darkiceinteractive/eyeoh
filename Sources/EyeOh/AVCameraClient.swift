import AppKit
import AVFoundation
import Foundation

@MainActor
final class AVCameraClient: CameraDeviceControlling {
    enum CameraError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "That camera is no longer available."
        }
    }

    private var monitor: CameraChangeMonitor?

    func cameras() -> [CameraDevice] {
        discoverySession.devices.map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                kind: kind(for: device),
                modelID: device.modelID
            )
        }
    }

    func preferredCameraID() -> String? {
        AVCaptureDevice.userPreferredCamera?.uniqueID
            ?? AVCaptureDevice.systemPreferredCamera?.uniqueID
            ?? AVCaptureDevice.default(for: .video)?.uniqueID
    }

    func userPreferredCameraID() -> String? {
        AVCaptureDevice.userPreferredCamera?.uniqueID
    }

    func systemPreferredCameraID() -> String? {
        AVCaptureDevice.systemPreferredCamera?.uniqueID
    }

    func startMonitoring(_ onChange: @escaping @MainActor () -> Void) {
        monitor = CameraChangeMonitor(onChange: onChange)
    }

    func setPreferredCamera(_ id: String) throws {
        guard let device = AVCaptureDevice(uniqueID: id) else {
            throw CameraError.unavailable
        }
        AVCaptureDevice.userPreferredCamera = device
    }

    private var discoverySession: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .external,
                .continuityCamera,
                .deskViewCamera,
            ],
            mediaType: .video,
            position: .unspecified
        )
    }

    private func kind(for device: AVCaptureDevice) -> CameraDevice.Kind {
        if device.isContinuityCamera || device.deviceType == .continuityCamera {
            return .continuity
        }
        switch device.deviceType {
        case .deskViewCamera:
            return .deskView
        case .builtInWideAngleCamera:
            return .builtIn
        default:
            return .external
        }
    }
}

/// Class-level KVO on `AVCaptureDevice` (Apple documents observing
/// `systemPreferredCamera` this way) plus connect/disconnect and wake notifications.
private final class CameraChangeMonitor: NSObject, @unchecked Sendable {
    private static let keyPaths = ["systemPreferredCamera", "userPreferredCamera"]
    private let onChange: @MainActor () -> Void
    private var tokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
        for keyPath in Self.keyPaths {
            AVCaptureDevice.self.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil)
        }
        let names: [(NotificationCenter, Notification.Name)] = [
            (.default, AVCaptureDevice.wasConnectedNotification),
            (.default, AVCaptureDevice.wasDisconnectedNotification),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
        ]
        for (center, name) in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.notify()
            }
            tokens.append((center, token))
        }
    }

    deinit {
        for keyPath in Self.keyPaths {
            AVCaptureDevice.self.removeObserver(self, forKeyPath: keyPath)
        }
        for entry in tokens {
            entry.center.removeObserver(entry.token)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        notify()
    }

    private func notify() {
        let onChange = onChange
        Task { @MainActor in onChange() }
    }
}
