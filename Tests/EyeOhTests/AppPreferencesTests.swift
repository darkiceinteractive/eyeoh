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
}
