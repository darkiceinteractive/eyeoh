import Foundation
import Observation
import ServiceManagement

enum AppPreferenceKeys {
    static let anonymousStatistics = "privacy.anonymousStatistics"
    static let crashReporting = "privacy.crashReporting"
    static let telemetryConsentVersion = "privacy.telemetryConsentVersion"
}

@MainActor
@Observable
final class AppPreferences {
    private static let currentConsentVersion = 1
    private let defaults: UserDefaults

    var anonymousStatisticsEnabled: Bool {
        didSet {
            defaults.set(anonymousStatisticsEnabled, forKey: AppPreferenceKeys.anonymousStatistics)
            Telemetry.shared.setStatisticsEnabled(anonymousStatisticsEnabled)
        }
    }

    var crashReportingEnabled: Bool {
        didSet {
            defaults.set(crashReportingEnabled, forKey: AppPreferenceKeys.crashReporting)
            Telemetry.shared.setCrashReportingEnabled(crashReportingEnabled)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.integer(forKey: AppPreferenceKeys.telemetryConsentVersion) >= Self.currentConsentVersion {
            anonymousStatisticsEnabled = defaults.bool(forKey: AppPreferenceKeys.anonymousStatistics)
            crashReportingEnabled = defaults.bool(forKey: AppPreferenceKeys.crashReporting)
        } else {
            anonymousStatisticsEnabled = false
            crashReportingEnabled = false
            defaults.set(false, forKey: AppPreferenceKeys.anonymousStatistics)
            defaults.set(false, forKey: AppPreferenceKeys.crashReporting)
            defaults.set(Self.currentConsentVersion, forKey: AppPreferenceKeys.telemetryConsentVersion)
        }
    }

    func reconcileProviderAvailability(statisticsAvailable: Bool, crashReportingAvailable: Bool) {
        if !statisticsAvailable {
            anonymousStatisticsEnabled = false
        }
        if !crashReportingAvailable {
            crashReportingEnabled = false
        }
    }

    func activateTelemetry() {
        Telemetry.shared.configure(
            statisticsEnabled: anonymousStatisticsEnabled,
            crashReportingEnabled: crashReportingEnabled
        )
    }
}

@MainActor
@Observable
final class LaunchAtLoginController {
    private let service: SMAppService

    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var errorMessage: String?

    init(service: SMAppService = .mainApp) {
        self.service = service
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
