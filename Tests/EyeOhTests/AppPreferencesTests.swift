import XCTest
@testable import EyeOh

@MainActor
final class AppPreferencesTests: XCTestCase {
    func testReportingChoicesDefaultToOffAndPersist() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = AppPreferences(defaults: defaults)
        XCTAssertFalse(initial.anonymousStatisticsEnabled)
        XCTAssertFalse(initial.crashReportingEnabled)

        initial.anonymousStatisticsEnabled = true
        initial.crashReportingEnabled = true

        let restored = AppPreferences(defaults: defaults)
        XCTAssertTrue(restored.anonymousStatisticsEnabled)
        XCTAssertTrue(restored.crashReportingEnabled)
    }

    func testEarlierPlaceholderChoicesDoNotBecomeNetworkConsent() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: AppPreferenceKeys.anonymousStatistics)
        defaults.set(true, forKey: AppPreferenceKeys.crashReporting)

        let migrated = AppPreferences(defaults: defaults)

        XCTAssertFalse(migrated.anonymousStatisticsEnabled)
        XCTAssertFalse(migrated.crashReportingEnabled)
    }

    func testUnavailableProvidersCannotLeaveConsentEnabled() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.anonymousStatisticsEnabled = true
        preferences.crashReportingEnabled = true

        preferences.reconcileProviderAvailability(
            statisticsAvailable: false,
            crashReportingAvailable: false
        )

        XCTAssertFalse(preferences.anonymousStatisticsEnabled)
        XCTAssertFalse(preferences.crashReportingEnabled)
    }

    func testInputVolumeMenuControlDefaultsToOffAndPersists() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = AppPreferences(defaults: defaults)
        XCTAssertFalse(initial.showsInputVolumeInMenu)

        initial.showsInputVolumeInMenu = true

        XCTAssertTrue(AppPreferences(defaults: defaults).showsInputVolumeInMenu)
    }
}
