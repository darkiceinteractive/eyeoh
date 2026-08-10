import OSLog

/// Privacy-safe instrumentation boundary. Only this fixed vocabulary can leave
/// the app, and only after the corresponding preference is enabled.
enum Diagnostics {
    enum Event: String, CaseIterable {
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

    @MainActor static var hasStatisticsProvider: Bool {
        Telemetry.shared.hasStatisticsProvider
    }

    @MainActor static var hasCrashReportingProvider: Bool {
        Telemetry.shared.hasCrashReportingProvider
    }

    @MainActor
    static func record(_ event: Event) {
        guard UserDefaults.standard.bool(forKey: AppPreferenceKeys.anonymousStatistics) else {
            return
        }
        logger.info("Event: \(event.rawValue, privacy: .public)")
        Telemetry.shared.capture(event)
    }
}
