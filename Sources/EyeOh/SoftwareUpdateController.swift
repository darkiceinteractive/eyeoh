import Foundation
import Observation

#if EYEOH_DIRECT_UPDATER
import Combine
import Sparkle
#endif

/// Owns software-update behavior without exposing Sparkle to non-direct builds.
///
/// The package manifest only links Sparkle when `EYEOH_DISTRIBUTION_CHANNEL=direct`.
/// Mac App Store and source builds compile the no-op half of this type instead.
@MainActor
@Observable
final class SoftwareUpdateController {
    private(set) var canCheckForUpdates = false
    private(set) var automaticallyChecksForUpdates = false
    private(set) var automaticallyDownloadsUpdates = false

#if EYEOH_DIRECT_UPDATER
    @ObservationIgnored
    private let updaterController: SPUStandardUpdaterController

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()
#endif

    var isAvailable: Bool {
#if EYEOH_DIRECT_UPDATER
        true
#else
        false
#endif
    }

    init() {
#if EYEOH_DIRECT_UPDATER
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
            .store(in: &cancellables)

        updaterController.updater.publisher(
            for: \.automaticallyChecksForUpdates,
            options: [.initial, .new]
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] value in self?.automaticallyChecksForUpdates = value }
        .store(in: &cancellables)

        updaterController.updater.publisher(
            for: \.automaticallyDownloadsUpdates,
            options: [.initial, .new]
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] value in self?.automaticallyDownloadsUpdates = value }
        .store(in: &cancellables)
#endif
    }

    func checkForUpdates() {
#if EYEOH_DIRECT_UPDATER
        updaterController.checkForUpdates(nil)
#endif
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
#if EYEOH_DIRECT_UPDATER
        updaterController.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
        if !enabled {
            setAutomaticallyDownloadsUpdates(false)
        }
#endif
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
#if EYEOH_DIRECT_UPDATER
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloadsUpdates = enabled
#endif
    }
}
