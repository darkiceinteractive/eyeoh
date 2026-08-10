import OSLog

/// Privacy-safe instrumentation boundary. Events are recorded locally only
/// after the user opts in. The current build has no network reporting provider.
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

    static let hasStatisticsProvider = false
    static let hasCrashReportingProvider = false

    static func record(_ event: Event) {
        guard UserDefaults.standard.bool(forKey: AppPreferenceKeys.anonymousStatistics) else {
            return
        }
        logger.info("Event: \(event.rawValue, privacy: .public)")
    }
}
