import XCTest
@testable import EyeOh

@MainActor
final class CameraPersistenceTests: XCTestCase {
    private let builtIn = CameraDevice(id: "built-in", name: "MacBook Pro Camera", kind: .builtIn, modelID: "FaceTime HD")
    private let usb = CameraDevice(id: "usb-1", name: "AIRHUG 11", kind: .external, modelID: "UVC Camera VendorID_1")
    private let phone = CameraDevice(id: "phone", name: "Matt's iPhone Camera", kind: .continuity, modelID: "iPhone15,3")

    private func defaults() -> (UserDefaults, () -> Void) {
        let name = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, { defaults.removePersistentDomain(forName: name) })
    }

    func testSavedCameraAndHoldPreferencePersist() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let initial = CameraPersistence(defaults: defaults)
        XCTAssertNil(initial.savedCamera)
        XCTAssertTrue(initial.holdsSelection)

        initial.savedCamera = SavedCamera(usb)
        initial.holdsSelection = false

        let restored = CameraPersistence(defaults: defaults)
        XCTAssertEqual(restored.savedCamera, SavedCamera(usb))
        XCTAssertFalse(restored.holdsSelection)
    }

    func testMatcherPrefersExactID() {
        let saved = SavedCamera(usb)
        XCTAssertEqual(CameraMatcher.match(saved, in: [builtIn, usb]), usb)
    }

    func testMatcherFallsBackToModelAndNameWhenIDChanges() {
        let moved = CameraDevice(id: "usb-2", name: usb.name, kind: .external, modelID: usb.modelID)
        XCTAssertEqual(CameraMatcher.match(SavedCamera(usb), in: [builtIn, moved]), moved)
    }

    func testMatcherFallsBackToNameWhenModelUnknown() {
        let renamedModel = CameraDevice(id: "usb-2", name: usb.name, kind: .external, modelID: nil)
        XCTAssertEqual(CameraMatcher.match(SavedCamera(usb), in: [renamedModel]), renamedModel)
    }

    func testMatcherRejectsAmbiguousFallback() {
        let twinA = CameraDevice(id: "a", name: usb.name, kind: .external, modelID: usb.modelID)
        let twinB = CameraDevice(id: "b", name: usb.name, kind: .external, modelID: usb.modelID)
        XCTAssertNil(CameraMatcher.match(SavedCamera(usb), in: [twinA, twinB]))
    }

    func testMatcherReturnsNilWhenAbsent() {
        XCTAssertNil(CameraMatcher.match(SavedCamera(usb), in: [builtIn, phone]))
    }

    func testPolicyReappliesWhenUserPreferenceDiffers() {
        let target = CameraHoldPolicy.cameraToApply(
            saved: SavedCamera(usb), holdEnabled: true, available: [builtIn, usb],
            userPreferredID: builtIn.id, systemPreferredID: builtIn.id
        )
        XCTAssertEqual(target, usb)
    }

    func testPolicyReappliesWhenContinuityTakesSystemPreference() {
        let target = CameraHoldPolicy.cameraToApply(
            saved: SavedCamera(usb), holdEnabled: true, available: [builtIn, usb, phone],
            userPreferredID: usb.id, systemPreferredID: phone.id
        )
        XCTAssertEqual(target, usb)
    }

    func testPolicyDoesNothingWhenAlreadyAligned() {
        XCTAssertNil(CameraHoldPolicy.cameraToApply(
            saved: SavedCamera(usb), holdEnabled: true, available: [builtIn, usb],
            userPreferredID: usb.id, systemPreferredID: usb.id
        ))
    }

    func testPolicyKeepsCurrentWhenSavedCameraMissingOrDisabledOrUnsaved() {
        XCTAssertNil(CameraHoldPolicy.cameraToApply(
            saved: SavedCamera(usb), holdEnabled: true, available: [builtIn],
            userPreferredID: builtIn.id, systemPreferredID: builtIn.id
        ))
        XCTAssertNil(CameraHoldPolicy.cameraToApply(
            saved: SavedCamera(usb), holdEnabled: false, available: [builtIn, usb],
            userPreferredID: builtIn.id, systemPreferredID: builtIn.id
        ))
        XCTAssertNil(CameraHoldPolicy.cameraToApply(
            saved: nil, holdEnabled: true, available: [builtIn, usb],
            userPreferredID: builtIn.id, systemPreferredID: builtIn.id
        ))
    }

    func testRateLimiterBlocksBurstThenAllowsAfterWindow() {
        var limiter = CameraApplyRateLimiter(maxApplies: 2, window: 10)
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(limiter.allow(at: start))
        XCTAssertTrue(limiter.allow(at: start.addingTimeInterval(1)))
        XCTAssertFalse(limiter.allow(at: start.addingTimeInterval(2)))
        XCTAssertTrue(limiter.allow(at: start.addingTimeInterval(11)))
    }

    func testSelectingSavesCameraAndLaunchRestoresAfterReset() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let controller = ReapplyController(devices: [builtIn, usb])
        controller.userPreferred = builtIn.id
        let store = CameraDeviceStore(controller: controller, persistence: CameraPersistence(defaults: defaults))
        store.select(usb)

        controller.userPreferred = builtIn.id
        controller.system = builtIn.id
        let relaunched = CameraDeviceStore(controller: controller, persistence: CameraPersistence(defaults: defaults))

        XCTAssertEqual(controller.userPreferred, usb.id)
        XCTAssertEqual(relaunched.selectedCameraID, usb.id)
        XCTAssertEqual(relaunched.holdHint, "Keeping AIRHUG 11 selected")
    }

    func testMissingCameraIsLeftAloneThenRestoredWhenItReturns() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let persistence = CameraPersistence(defaults: defaults)
        persistence.savedCamera = SavedCamera(usb)
        let controller = ReapplyController(devices: [builtIn])
        controller.userPreferred = builtIn.id
        let store = CameraDeviceStore(controller: controller, persistence: persistence)

        XCTAssertEqual(controller.setCalls, [])
        XCTAssertTrue(store.holdHint?.contains("not connected") == true)

        controller.devices = [builtIn, usb]
        XCTAssertTrue(store.reconcile())
        XCTAssertEqual(controller.userPreferred, usb.id)
    }

    func testReconcileIsRateLimitedAgainstOtherApps() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let persistence = CameraPersistence(defaults: defaults)
        persistence.savedCamera = SavedCamera(usb)
        let controller = ReapplyController(devices: [builtIn, usb])
        controller.userPreferred = builtIn.id
        controller.ignoresWrites = true
        let store = CameraDeviceStore(controller: controller, persistence: persistence, now: { Date(timeIntervalSince1970: 5000) })

        for _ in 0..<10 { store.reconcile() }

        XCTAssertEqual(controller.setCalls.count, 3)
    }

    func testDisablingHoldStopsReapplyAndEnablingRestores() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let persistence = CameraPersistence(defaults: defaults)
        persistence.savedCamera = SavedCamera(usb)
        persistence.holdsSelection = false
        let controller = ReapplyController(devices: [builtIn, usb])
        controller.userPreferred = builtIn.id
        let store = CameraDeviceStore(controller: controller, persistence: persistence)
        XCTAssertFalse(store.reconcile())
        XCTAssertNil(store.holdHint)

        store.holdsSelection = true

        XCTAssertEqual(controller.userPreferred, usb.id)
        XCTAssertTrue(CameraPersistence(defaults: defaults).holdsSelection)
    }

    func testChangedIDUpdatesSavedCamera() {
        let (defaults, cleanup) = defaults()
        defer { cleanup() }
        let persistence = CameraPersistence(defaults: defaults)
        persistence.savedCamera = SavedCamera(usb)
        let moved = CameraDevice(id: "usb-2", name: usb.name, kind: .external, modelID: usb.modelID)
        let controller = ReapplyController(devices: [builtIn, moved])
        controller.userPreferred = builtIn.id

        _ = CameraDeviceStore(controller: controller, persistence: persistence)

        XCTAssertEqual(controller.userPreferred, "usb-2")
        XCTAssertEqual(persistence.savedCamera?.id, "usb-2")
    }
}

@MainActor
private final class ReapplyController: CameraDeviceControlling {
    var devices: [CameraDevice]
    var userPreferred: String?
    var system: String?
    var ignoresWrites = false
    private(set) var setCalls: [String] = []

    init(devices: [CameraDevice]) {
        self.devices = devices
    }

    func cameras() -> [CameraDevice] { devices }
    func preferredCameraID() -> String? { userPreferred ?? system }
    func userPreferredCameraID() -> String? { userPreferred }
    func systemPreferredCameraID() -> String? { system ?? userPreferred }

    func setPreferredCamera(_ id: String) throws {
        setCalls.append(id)
        guard !ignoresWrites else { return }
        userPreferred = id
        system = id
    }
}
