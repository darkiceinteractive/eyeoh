import Foundation
import Testing
@testable import EyeOh

@Suite("Telemetry configuration")
struct TelemetryConfigurationTests {
    @Test("Source builds have no providers")
    func sourceBuildIsOffline() {
        let configuration = TelemetryConfiguration(
            postHogProjectToken: nil,
            postHogHost: nil,
            sentryDSN: nil
        )

        #expect(!configuration.hasStatisticsProvider)
        #expect(!configuration.hasCrashReportingProvider)
    }

    @Test("Both release providers require valid complete configuration")
    func releaseProviders() {
        let configuration = TelemetryConfiguration(
            postHogProjectToken: "phc_public_ingestion_token",
            postHogHost: "https://eu.i.posthog.com",
            sentryDSN: "https://public@example.ingest.de.sentry.io/1",
            distributionChannel: "direct"
        )

        #expect(configuration.hasStatisticsProvider)
        #expect(configuration.hasCrashReportingProvider)
        #expect(configuration.distributionChannel == "direct")
    }

    @Test("Partial or insecure provider configuration remains disabled")
    func invalidProviders() {
        let configuration = TelemetryConfiguration(
            postHogProjectToken: "token",
            postHogHost: nil,
            sentryDSN: "http://public@example.test/1"
        )

        #expect(!configuration.hasStatisticsProvider)
        #expect(!configuration.hasCrashReportingProvider)
    }

    @Test("PostHog payload strips every property outside the privacy allowlist")
    func postHogPayloadAllowlist() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let payload = PostHogPayloadBuilder.make(
            event: .cameraChanged,
            token: "phc_test",
            distinctID: "installation-test",
            properties: [
                "$geoip_disable": true,
                "$process_person_profile": false,
                "schema_version": 1,
                "app_version": "0.3.0",
                "app_build": "5",
                "distribution": "test",
                "device_name": "must-not-leave",
                "free_text": "must-not-leave",
            ],
            date: date,
            uuid: uuid
        )

        let batch = try #require(payload["batch"] as? [[String: Any]])
        let event = try #require(batch.first)
        let properties = try #require(event["properties"] as? [String: Any])
        #expect(event["event"] as? String == "camera_changed")
        #expect(Set(properties.keys) == PostHogPayloadBuilder.commonPropertyKeys)
        #expect(properties["device_name"] == nil)
        #expect(properties["free_text"] == nil)
    }
}
