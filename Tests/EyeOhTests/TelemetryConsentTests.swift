import Foundation
import XCTest
@testable import EyeOh

@MainActor
private final class RecordingStatisticsTransport: StatisticsTransport {
    var requests: [URLRequest] = []
    var bodies: [Data] = []
    var cancelled = false

    func send(_ request: URLRequest, body: Data) {
        requests.append(request)
        bodies.append(body)
    }

    func cancel() { cancelled = true }
}

@MainActor
final class TelemetryConsentTests: XCTestCase {
    func testNoRequestsOrIdentifierBeforeConsentAndImmediateStopAfterOptOut() throws {
        let suite = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = RecordingStatisticsTransport()
        var sessionsCreated = 0
        let telemetry = Telemetry(
            configuration: TelemetryConfiguration(
                statisticsEndpoint: TelemetryConfiguration.ownedStatisticsEndpoint,
                distributionChannel: "direct"
            ),
            defaults: defaults,
            makeStatisticsTransport: { configuration in
                XCTAssertNil(configuration.httpCookieStorage)
                XCTAssertFalse(configuration.httpShouldSetCookies)
                XCTAssertNil(configuration.urlCache)
                sessionsCreated += 1
                return session
            }
        )

        telemetry.configure(statisticsEnabled: false, crashReportingEnabled: false)
        telemetry.capture(.appLaunched)
        XCTAssertEqual(sessionsCreated, 0)
        XCTAssertTrue(session.requests.isEmpty)
        XCTAssertNil(telemetry.supportAnalyticsIdentifier)

        telemetry.setStatisticsEnabled(true)
        telemetry.capture(.inputChanged)
        XCTAssertEqual(sessionsCreated, 1)
        XCTAssertEqual(session.requests.count, 1)
        XCTAssertEqual(session.requests.first?.url, TelemetryConfiguration.ownedStatisticsEndpoint)
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(telemetry.supportAnalyticsIdentifier)))
        let body = try XCTUnwrap(session.bodies.first)
        let payload = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(payload?["event"] as? String, "input_changed")
        XCTAssertNil(payload?["api_key"])

        telemetry.setStatisticsEnabled(false)
        telemetry.capture(.outputChanged)
        XCTAssertTrue(session.cancelled)
        XCTAssertEqual(session.requests.count, 1)
    }
}
