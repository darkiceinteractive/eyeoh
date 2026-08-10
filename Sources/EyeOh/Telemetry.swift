import Foundation
import Sentry

struct TelemetryConfiguration: Equatable {
    let postHogProjectToken: String?
    let postHogHost: String?
    let sentryDSN: String?
    let distributionChannel: String

    var hasStatisticsProvider: Bool {
        guard nonEmpty(postHogProjectToken) != nil,
              let value = nonEmpty(postHogHost),
              let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.host == "eu.i.posthog.com"
    }

    var hasCrashReportingProvider: Bool {
        guard let value = nonEmpty(sentryDSN), let url = URL(string: value) else { return false }
        return url.scheme == "https" && (url.host?.hasSuffix(".ingest.de.sentry.io") == true)
    }

    init(bundle: Bundle = .main) {
        postHogProjectToken = bundle.object(forInfoDictionaryKey: "EyeOhPostHogProjectToken") as? String
        postHogHost = bundle.object(forInfoDictionaryKey: "EyeOhPostHogHost") as? String
        sentryDSN = bundle.object(forInfoDictionaryKey: "EyeOhSentryDSN") as? String
        distributionChannel = (bundle.object(forInfoDictionaryKey: "EyeOhDistributionChannel") as? String)
            .flatMap(Self.nonEmpty) ?? "source"
    }

    init(
        postHogProjectToken: String?,
        postHogHost: String?,
        sentryDSN: String?,
        distributionChannel: String = "source"
    ) {
        self.postHogProjectToken = postHogProjectToken
        self.postHogHost = postHogHost
        self.sentryDSN = sentryDSN
        self.distributionChannel = distributionChannel
    }

    private func nonEmpty(_ value: String?) -> String? {
        Self.nonEmpty(value)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

@MainActor
final class Telemetry {
    static let shared = Telemetry()

    private let configuration: TelemetryConfiguration
    private let defaults: UserDefaults
    private var postHogSession: URLSession?
    private var sentryStarted = false

    var hasStatisticsProvider: Bool { configuration.hasStatisticsProvider }
    var hasCrashReportingProvider: Bool { configuration.hasCrashReportingProvider }
    var supportAnalyticsIdentifier: String? {
        defaults.string(forKey: "privacy.analyticsInstallationIdentifier")
    }

    init(
        configuration: TelemetryConfiguration = TelemetryConfiguration(),
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.defaults = defaults
    }

    func configure(statisticsEnabled: Bool, crashReportingEnabled: Bool) {
        setStatisticsEnabled(statisticsEnabled)
        setCrashReportingEnabled(crashReportingEnabled)
    }

    func setStatisticsEnabled(_ enabled: Bool) {
        guard configuration.hasStatisticsProvider else { return }
        if enabled {
            startPostHogIfNeeded()
        } else if let postHogSession {
            postHogSession.invalidateAndCancel()
            self.postHogSession = nil
        }
    }

    func setCrashReportingEnabled(_ enabled: Bool) {
        guard configuration.hasCrashReportingProvider else { return }
        if enabled {
            startSentryIfNeeded()
        } else if sentryStarted {
            SentrySDK.close()
            sentryStarted = false
            try? FileManager.default.removeItem(at: sentryCacheURL)
        }
    }

    func capture(_ event: Diagnostics.Event) {
        guard let postHogSession,
              let token = configuration.postHogProjectToken,
              let host = configuration.postHogHost,
              let endpoint = URL(string: host)?.appendingPathComponent("batch") else { return }

        let payload = PostHogPayloadBuilder.make(
            event: event,
            token: token,
            distinctID: analyticsInstallationIdentifier,
            properties: minimalEventProperties
        )
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postHogSession.uploadTask(with: request, from: body).resume()
    }

    private func startPostHogIfNeeded() {
        guard postHogSession == nil else { return }
        _ = analyticsInstallationIdentifier
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        postHogSession = URLSession(configuration: sessionConfiguration)
    }

    private func startSentryIfNeeded() {
        guard !sentryStarted, let dsn = configuration.sentryDSN else { return }
        let cachePath = sentryCacheURL.path
        let channel = configuration.distributionChannel
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = channel
            options.sendDefaultPii = false
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true
            options.enableAutoSessionTracking = false
            options.enableAutoPerformanceTracing = false
            options.enableNetworkTracking = false
            options.enableNetworkBreadcrumbs = false
            options.enableFileIOTracing = false
            options.enableDataSwizzling = false
            options.enableSwizzling = false
            options.enableAutoBreadcrumbTracking = false
            options.enableLogs = false
            options.enableMemoryIntrospection = false
            options.attachStacktrace = true
            options.attachAllThreads = false
            options.tracesSampleRate = 0
            options.sampleRate = 1
            options.maxBreadcrumbs = 0
            options.cacheDirectoryPath = cachePath
            options.shutdownTimeInterval = 0
            options.beforeSend = { event in
                event.user = nil
                event.request = nil
                event.breadcrumbs = nil
                event.extra = nil
                return event
            }
        }
        sentryStarted = true
    }

    private var minimalEventProperties: [String: Any] {
        let bundle = Bundle.main
        return [
            "$process_person_profile": false,
            "$geoip_disable": true,
            "schema_version": 1,
            "app_version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "app_build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "distribution": configuration.distributionChannel,
        ]
    }

    private var sentryCacheURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EyeOh/Sentry", isDirectory: true)
    }

    private var analyticsInstallationIdentifier: String {
        let key = "privacy.analyticsInstallationIdentifier"
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: key)
        return created
    }
}

enum PostHogPayloadBuilder {
    static let commonPropertyKeys: Set<String> = [
        "$process_person_profile",
        "$geoip_disable",
        "schema_version",
        "app_version",
        "app_build",
        "distribution",
        "distinct_id",
    ]

    static func make(
        event: Diagnostics.Event,
        token: String,
        distinctID: String,
        properties: [String: Any],
        date: Date = Date(),
        uuid: UUID = UUID()
    ) -> [String: Any] {
        var allowlistedProperties = properties.filter { commonPropertyKeys.contains($0.key) }
        allowlistedProperties["distinct_id"] = distinctID
        let timestamp = ISO8601DateFormatter().string(from: date)
        return [
            "api_key": token,
            "batch": [[
                "event": event.rawValue,
                "distinct_id": distinctID,
                "properties": allowlistedProperties,
                "timestamp": timestamp,
                "uuid": uuid.uuidString.lowercased(),
            ]],
            "sent_at": timestamp,
        ]
    }
}
