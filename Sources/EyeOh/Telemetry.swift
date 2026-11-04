import Foundation
import Sentry

struct TelemetryConfiguration: Equatable {
    static let ownedStatisticsEndpoint = URL(string: "https://eyeoh-telemetry.darkice.workers.dev/events")!
    let statisticsEndpoint: URL?
    let sentryDSN: String?
    let distributionChannel: String

    var hasStatisticsProvider: Bool {
        isReleaseChannel && statisticsEndpoint == Self.ownedStatisticsEndpoint
    }

    var hasCrashReportingProvider: Bool {
        guard isReleaseChannel, let value = nonEmpty(sentryDSN), let url = URL(string: value) else { return false }
        return url.scheme == "https" && (url.host?.hasSuffix(".ingest.de.sentry.io") == true)
            && url.user?.isEmpty == false && url.password == nil && url.port == nil
            && url.path.range(of: "^/[0-9]+$", options: .regularExpression) != nil
            && url.query == nil && url.fragment == nil
    }

    init(bundle: Bundle = .main) {
        statisticsEndpoint = (bundle.object(forInfoDictionaryKey: "EyeOhStatisticsEndpoint") as? String)
            .flatMap(URL.init(string:))
        sentryDSN = bundle.object(forInfoDictionaryKey: "EyeOhSentryDSN") as? String
        distributionChannel = (bundle.object(forInfoDictionaryKey: "EyeOhDistributionChannel") as? String)
            .flatMap(Self.nonEmpty) ?? "source"
    }

    init(
        statisticsEndpoint: URL? = nil,
        sentryDSN: String? = nil,
        distributionChannel: String = "source"
    ) {
        self.statisticsEndpoint = statisticsEndpoint
        self.sentryDSN = sentryDSN
        self.distributionChannel = distributionChannel
    }

    private var isReleaseChannel: Bool { ["direct", "mas"].contains(distributionChannel) }

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
protocol StatisticsTransport {
    func send(_ request: URLRequest, body: Data)
    func cancel()
}

@MainActor
final class URLSessionStatisticsTransport: StatisticsTransport {
    private let session: URLSession

    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest, body: Data) {
        session.uploadTask(with: request, from: body).resume()
    }

    func cancel() { session.invalidateAndCancel() }
}

@MainActor
final class Telemetry {
    static let shared = Telemetry()

    private let configuration: TelemetryConfiguration
    private let defaults: UserDefaults
    private let makeStatisticsTransport: (URLSessionConfiguration) -> any StatisticsTransport
    private var statisticsTransport: (any StatisticsTransport)?
    private var sentryStarted = false

    var hasStatisticsProvider: Bool { configuration.hasStatisticsProvider }
    var hasCrashReportingProvider: Bool { configuration.hasCrashReportingProvider }
    var supportAnalyticsIdentifier: String? {
        defaults.string(forKey: "privacy.analyticsInstallationIdentifier")
    }

    init(
        configuration: TelemetryConfiguration = TelemetryConfiguration(),
        defaults: UserDefaults = .standard,
        makeStatisticsTransport: @escaping (URLSessionConfiguration) -> any StatisticsTransport = {
            URLSessionStatisticsTransport(configuration: $0)
        }
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.makeStatisticsTransport = makeStatisticsTransport
    }

    func configure(statisticsEnabled: Bool, crashReportingEnabled: Bool) {
        setStatisticsEnabled(statisticsEnabled)
        setCrashReportingEnabled(crashReportingEnabled)
    }

    func setStatisticsEnabled(_ enabled: Bool) {
        guard configuration.hasStatisticsProvider else { return }
        if enabled {
            startStatisticsIfNeeded()
        } else if let statisticsTransport {
            statisticsTransport.cancel()
            self.statisticsTransport = nil
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
        guard let statisticsTransport,
              let endpoint = configuration.statisticsEndpoint else { return }

        let payload = StatisticsPayloadBuilder.make(
            event: event,
            distinctID: analyticsInstallationIdentifier,
            properties: minimalEventProperties
        )
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        statisticsTransport.send(request, body: body)
    }

    private func startStatisticsIfNeeded() {
        guard statisticsTransport == nil else { return }
        _ = analyticsInstallationIdentifier
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieStorage = nil
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        statisticsTransport = makeStatisticsTransport(sessionConfiguration)
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

enum StatisticsPayloadBuilder {
    static let commonPropertyKeys: Set<String> = [
        "app_version",
        "app_build",
        "distribution",
    ]

    static func make(
        event: Diagnostics.Event,
        distinctID: String,
        properties: [String: Any],
        uuid: UUID = UUID()
    ) -> [String: Any] {
        let allowlistedProperties = properties.filter { commonPropertyKeys.contains($0.key) }
        return [
            "event": event.rawValue,
            "distinct_id": distinctID,
            "properties": allowlistedProperties,
            "uuid": uuid.uuidString.lowercased(),
        ]
    }
}
