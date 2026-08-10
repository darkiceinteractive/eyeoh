import OSLog

/// Privacy-safe instrumentation boundary. The current free build records only
/// local, non-identifying operational events in Unified Logging. No device
/// names, identifiers, audio, video or network requests are included.
enum Diagnostics {
    enum Event: String {
        case appLaunched = "app_launched"
        case feedbackOpened = "feedback_opened"
        case previewOpened = "preview_opened"
        case inputChanged = "input_changed"
        case outputChanged = "output_changed"
        case cameraChanged = "camera_changed"
    }

    private static let logger = Logger(
        subsystem: "au.com.darkice.eyeoh",
        category: "product-events"
    )

    static func record(_ event: Event) {
        logger.info("Event: \(event.rawValue, privacy: .public)")
    }
}
