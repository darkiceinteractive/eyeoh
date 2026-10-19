import Foundation

@MainActor
protocol CameraDeviceControlling: AnyObject {
    func cameras() -> [CameraDevice]
    func preferredCameraID() -> String?
    /// The raw `AVCaptureDevice.userPreferredCamera`, without falling back to the system choice.
    func userPreferredCameraID() -> String?
    func systemPreferredCameraID() -> String?
    func setPreferredCamera(_ id: String) throws
    /// Calls `onChange` when cameras connect or disconnect, the Mac wakes, or the
    /// system or user preferred camera changes. Calls may be bursty; callers coalesce.
    func startMonitoring(_ onChange: @escaping @MainActor () -> Void)
}

extension CameraDeviceControlling {
    func userPreferredCameraID() -> String? { preferredCameraID() }
    func systemPreferredCameraID() -> String? { nil }
    func startMonitoring(_ onChange: @escaping @MainActor () -> Void) {}
}
