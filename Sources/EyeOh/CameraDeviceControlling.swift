import Foundation

@MainActor
protocol CameraDeviceControlling: AnyObject {
    func cameras() -> [CameraDevice]
    func preferredCameraID() -> String?
    func setPreferredCamera(_ id: String) throws
}
