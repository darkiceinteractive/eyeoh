import Foundation
import Testing
@testable import EyeOh

@Suite("Telemetry configuration")
struct TelemetryConfigurationTests {
    @Test("Source builds have no providers")
    func sourceBuildIsOffline() {
        let configuration = TelemetryConfiguration(
            statisticsEndpoint: TelemetryConfiguration.ownedStatisticsEndpoint,
            sentryDSN: "https://public@example.ingest.de.sentry.io/1"
        )

        #expect(!configuration.hasStatisticsProvider)
        #expect(!configuration.hasCrashReportingProvider)
    }

    @Test("Both release providers require valid complete configuration")
    func releaseProviders() {
        let configuration = TelemetryConfiguration(
            statisticsEndpoint: TelemetryConfiguration.ownedStatisticsEndpoint,
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
            statisticsEndpoint: URL(string: "https://unrelated.example/events"),
            sentryDSN: "http://public@example.test/1",
            distributionChannel: "direct"
        )

        #expect(!configuration.hasStatisticsProvider)
        #expect(!configuration.hasCrashReportingProvider)
    }

    @Test("Statistics accept only the owned gateway with no URL overrides")
    func gatewayBoundary() {
        for endpoint in [
            "http://eyeoh-telemetry.darkice.workers.dev/events",
            "https://eyeoh-telemetry.darkice.workers.dev/events?token=other",
            "https://eyeoh-telemetry.darkice.workers.dev/events#other",
            "https://eyeoh-telemetry.darkice.workers.dev/other",
            "https://eu.i.posthog.com/batch/",
        ] {
            #expect(!TelemetryConfiguration(statisticsEndpoint: URL(string: endpoint), distributionChannel: "direct").hasStatisticsProvider)
        }
    }

    @Test("Crash configuration requires an EU ingestion DSN and numeric project")
    func crashBoundary() {
        for dsn in [
            "https://example.ingest.de.sentry.io/1",
            "https://public@example.ingest.de.sentry.io/private",
            "https://public@example.ingest.us.sentry.io/1",
            "https://public@example.ingest.de.sentry.io/1?other=private",
            "https://public:private@example.ingest.de.sentry.io/1",
        ] {
            #expect(!TelemetryConfiguration(sentryDSN: dsn, distributionChannel: "direct").hasCrashReportingProvider)
        }
    }

    @Test("Gateway payload strips every property outside the privacy allowlist")
    func statisticsPayloadAllowlist() throws {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let payload = StatisticsPayloadBuilder.make(
            event: .cameraChanged,
            distinctID: "installation-test",
            properties: [
                "app_version": "0.3.0",
                "app_build": "5",
                "distribution": "direct",
                "device_name": "must-not-leave",
                "free_text": "must-not-leave",
            ],
            uuid: uuid
        )

        let properties = try #require(payload["properties"] as? [String: Any])
        #expect(payload["event"] as? String == "camera_changed")
        #expect(Set(payload.keys) == ["event", "distinct_id", "uuid", "properties"])
        #expect(Set(properties.keys) == StatisticsPayloadBuilder.commonPropertyKeys)
        #expect(properties["device_name"] == nil)
        #expect(properties["free_text"] == nil)
    }
}
