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

    func cameras() -> [CameraDevice] {
        discoverySession.devices.map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                kind: kind(for: device)
            )
        }
    }

    func preferredCameraID() -> String? {
        AVCaptureDevice.userPreferredCamera?.uniqueID
            ?? AVCaptureDevice.systemPreferredCamera?.uniqueID
            ?? AVCaptureDevice.default(for: .video)?.uniqueID
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
