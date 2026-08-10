import Foundation
import Observation
import ServiceManagement

enum AppPreferenceKeys {
    static let anonymousStatistics = "privacy.anonymousStatistics"
    static let crashReporting = "privacy.crashReporting"
}

@MainActor
@Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var anonymousStatisticsEnabled: Bool {
        didSet { defaults.set(anonymousStatisticsEnabled, forKey: AppPreferenceKeys.anonymousStatistics) }
    }

    var crashReportingEnabled: Bool {
        didSet { defaults.set(crashReportingEnabled, forKey: AppPreferenceKeys.crashReporting) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        anonymousStatisticsEnabled = defaults.bool(forKey: AppPreferenceKeys.anonymousStatistics)
        crashReportingEnabled = defaults.bool(forKey: AppPreferenceKeys.crashReporting)
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
