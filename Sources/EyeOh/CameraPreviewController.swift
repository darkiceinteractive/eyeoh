import AVFoundation
import Foundation

protocol CameraPreviewControlling: AnyObject, Sendable {
    var session: AVCaptureSession { get }
    func start(cameraID: String, completion: @escaping @Sendable (String?) -> Void)
    func stop()
}

final class CameraPreviewController: CameraPreviewControlling, @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "au.com.darkice.eyeoh.camera-preview")

    func start(cameraID: String, completion: @escaping @Sendable (String?) -> Void) {
        queue.async { [self] in
            do {
                if session.isRunning {
                    session.stopRunning()
                }

                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                session.sessionPreset = .high

                guard let device = AVCaptureDevice(uniqueID: cameraID) else {
                    session.commitConfiguration()
                    throw PreviewError.unavailable
                }
                let input: AVCaptureDeviceInput
                do {
                    input = try AVCaptureDeviceInput(device: device)
                } catch {
                    session.commitConfiguration()
                    throw error
                }
                guard session.canAddInput(input) else {
                    session.commitConfiguration()
                    throw PreviewError.cannotConnect
                }
                session.addInput(input)
                session.commitConfiguration()
                session.startRunning()
                completion(nil)
            } catch {
                if session.isRunning {
                    session.stopRunning()
                }
                completion(error.localizedDescription)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.commitConfiguration()
        }
    }

    private enum PreviewError: LocalizedError {
        case unavailable
        case cannotConnect

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "That camera disconnected."
            case .cannotConnect:
                "The camera could not be connected to the preview."
            }
        }
    }
}
