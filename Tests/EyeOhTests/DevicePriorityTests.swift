import AudioToolbox
import XCTest
@testable import EyeOh

final class DevicePriorityResolverTests: XCTestCase {
    private let builtIn = AudioDevice(id: 1, uid: "built-in", name: "MacBook Pro Microphone", transport: .builtIn, channelCount: 1)
    private let usb = AudioDevice(id: 2, uid: "usb", name: "AIRHUG 11", transport: .usb, channelCount: 2)
    private let pods = AudioDevice(id: 3, uid: "pods", name: "AirPods", transport: .bluetooth, channelCount: 1)

    private func entries(_ uids: String...) -> [PriorityEntry] {
        uids.map { PriorityEntry(uid: $0, name: $0) }
    }

    func testPicksHighestRankedAvailableDevice() {
        let result = DevicePriorityResolver.preferred(
            in: entries("pods", "usb", "built-in"),
            available: [builtIn, usb]
        )
        XCTAssertEqual(result?.uid, "usb")
    }

    func testIgnoresDisconnectedEntriesAndUnrankedDevices() {
        XCTAssertNil(DevicePriorityResolver.preferred(in: entries("pods"), available: [builtIn, usb]))
        XCTAssertNil(DevicePriorityResolver.preferred(in: [], available: [builtIn]))
    }

    func testMatchesByUIDNotByDeviceID() {
        let reconnected = AudioDevice(id: 99, uid: "pods", name: "AirPods", transport: .bluetooth, channelCount: 1)
        let result = DevicePriorityResolver.preferred(in: entries("pods"), available: [builtIn, reconnected])
        XCTAssertEqual(result?.id, 99)
    }

    func testDetectsHijackOnlyWhenDefaultDiffersFromPreferred() {
        XCTAssertTrue(DevicePriorityResolver.isHijacked(currentID: pods.id, preferred: usb))
        XCTAssertFalse(DevicePriorityResolver.isHijacked(currentID: usb.id, preferred: usb))
        XCTAssertFalse(DevicePriorityResolver.isHijacked(currentID: pods.id, preferred: nil))
        XCTAssertTrue(DevicePriorityResolver.isHijacked(currentID: nil, preferred: usb))
    }

    func testFallbackOrderIsPriorityThenLastHealthyThenBuiltIn() {
        XCTAssertEqual(
            DevicePriorityResolver.fallback(priority: entries("usb"), available: [builtIn, usb, pods], lastHealthyUID: "pods")?.uid,
            "usb"
        )
        XCTAssertEqual(
            DevicePriorityResolver.fallback(priority: [], available: [builtIn, usb, pods], lastHealthyUID: "pods")?.uid,
            "pods"
        )
        XCTAssertEqual(
            DevicePriorityResolver.fallback(priority: [], available: [usb, builtIn], lastHealthyUID: "gone")?.uid,
            "built-in"
        )
        XCTAssertEqual(
            DevicePriorityResolver.fallback(priority: [], available: [usb], lastHealthyUID: nil)?.uid,
            "usb"
        )
        XCTAssertNil(DevicePriorityResolver.fallback(priority: [], available: [], lastHealthyUID: nil))
    }

    func testPromotingMovesEntryToTopWithoutDuplicates() {
        let result = DevicePriorityResolver.promoting(
            PriorityEntry(uid: "usb", name: "AIRHUG 11"),
            in: entries("built-in", "usb", "pods")
        )
        XCTAssertEqual(result.map(\.uid), ["usb", "built-in", "pods"])
    }
}

final class ReassertBackoffTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testAllowsReassertsUpToTheLimitThenPauses() {
        var backoff = ReassertBackoff()
        XCTAssertTrue(backoff.requestReassert(at: start))
        XCTAssertTrue(backoff.requestReassert(at: start.addingTimeInterval(1)))
        XCTAssertTrue(backoff.requestReassert(at: start.addingTimeInterval(2)))
        XCTAssertFalse(backoff.requestReassert(at: start.addingTimeInterval(3)))
        XCTAssertTrue(backoff.isPaused(at: start.addingTimeInterval(4)))
        XCTAssertFalse(backoff.requestReassert(at: start.addingTimeInterval(30)))
    }

    func testResumesAfterThePauseExpires() {
        var backoff = ReassertBackoff()
        for offset in 0..<4 { _ = backoff.requestReassert(at: start.addingTimeInterval(Double(offset))) }
        let later = start.addingTimeInterval(3 + backoff.pauseDuration + 1)
        XCTAssertFalse(backoff.isPaused(at: later))
        XCTAssertTrue(backoff.requestReassert(at: later))
    }

    func testSlowReassertsNeverTriggerThePause() {
        var backoff = ReassertBackoff()
        for index in 0..<10 {
            XCTAssertTrue(backoff.requestReassert(at: start.addingTimeInterval(Double(index) * 20)))
        }
        XCTAssertFalse(backoff.isPaused(at: start.addingTimeInterval(200)))
    }
}

@MainActor
final class PriorityLockStoreTests: XCTestCase {
    private let builtIn = AudioDevice(id: 1, uid: "built-in", name: "MacBook Pro Microphone", transport: .builtIn, channelCount: 1)
    private let usb = AudioDevice(id: 2, uid: "usb", name: "AIRHUG 11", transport: .usb, channelCount: 2)
    private let pods = AudioDevice(id: 3, uid: "pods", name: "AirPods", transport: .bluetooth, channelCount: 1)
    private let speakers = AudioDevice(id: 10, uid: "speakers", name: "MacBook Pro Speakers", transport: .builtIn, channelCount: 2)
    private let podsOut = AudioDevice(id: 11, uid: "pods-out", name: "AirPods", transport: .bluetooth, channelCount: 2)

    private var suites: [String] = []
    private var clock = Date(timeIntervalSince1970: 5_000)

    override func tearDown() {
        for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        suites = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "EyeOhTests.\(UUID().uuidString)"
        suites.append(name)
        return UserDefaults(suiteName: name)!
    }

    private func makeStore(
        controller: PriorityMockController,
        defaults: UserDefaults? = nil
    ) -> AudioDeviceStore {
        let defaults = defaults ?? makeDefaults()
        return AudioDeviceStore(
            controller: controller,
            volumePresets: DeviceVolumePresets(defaults: defaults),
            rememberedBluetoothDevices: RememberedBluetoothDevices(defaults: defaults),
            priorityPreferences: DevicePriorityPreferences(defaults: defaults),
            now: { [unowned self] in self.clock }
        )
    }

    func testLockIsOffByDefaultAndDoesNotChangeTheDefault() {
        let controller = PriorityMockController(inputs: [builtIn, pods], selected: builtIn.id)
        let store = makeStore(controller: controller)
        store.addToPriority(pods, direction: .input)

        store.settle()

        XCTAssertFalse(store.locksInput)
        XCTAssertFalse(store.locksOutput)
        XCTAssertEqual(controller.selectedID, builtIn.id)
    }

    func testLockReassertsHighestRankedInputWhenSomethingHijacksTheDefault() {
        let controller = PriorityMockController(inputs: [builtIn, usb, pods], selected: usb.id)
        let store = makeStore(controller: controller)
        store.addToPriority(usb, direction: .input)
        store.addToPriority(builtIn, direction: .input)
        store.locksInput = true

        controller.selectedID = pods.id
        store.settle()

        XCTAssertEqual(controller.selectedID, usb.id)
        XCTAssertEqual(store.selectedDeviceID, usb.id)
    }

    func testLockRestoresRankedDeviceWhenItComesBackWithANewID() {
        let controller = PriorityMockController(inputs: [builtIn], selected: builtIn.id)
        let store = makeStore(controller: controller)
        store.addToPriority(PriorityEntry(uid: "pods", name: "AirPods"), direction: .input)
        store.addToPriority(builtIn, direction: .input)
        store.locksInput = true

        let reconnected = AudioDevice(id: 77, uid: "pods", name: "AirPods", transport: .bluetooth, channelCount: 1)
        controller.inputs = [builtIn, reconnected]
        store.settle()

        XCTAssertEqual(controller.selectedID, 77)
    }

    func testOutputLockIsIndependentOfInputLock() {
        let controller = PriorityMockController(
            inputs: [builtIn], selected: builtIn.id,
            outputs: [speakers, podsOut], selectedOutput: podsOut.id
        )
        let store = makeStore(controller: controller)
        store.addToPriority(speakers, direction: .output)
        store.locksOutput = true

        store.settle()

        XCTAssertEqual(controller.selectedOutputID, speakers.id)
        XCTAssertEqual(controller.selectedID, builtIn.id)
    }

    func testManualPickThroughEyeOhPromotesTheDeviceWhileLocked() {
        let controller = PriorityMockController(inputs: [builtIn, usb, pods], selected: usb.id)
        let store = makeStore(controller: controller)
        store.addToPriority(usb, direction: .input)
        store.addToPriority(builtIn, direction: .input)
        store.locksInput = true

        store.select(pods)
        store.settle()

        XCTAssertEqual(store.inputPriority.map(\.uid), ["pods", "usb", "built-in"])
        XCTAssertEqual(controller.selectedID, pods.id)
    }

    func testManualPickDoesNotReorderListWhenLockIsOff() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        let store = makeStore(controller: controller)
        store.addToPriority(usb, direction: .input)

        store.select(builtIn)

        XCTAssertEqual(store.inputPriority.map(\.uid), ["usb"])
    }

    func testLoopBackOffPausesTheLockAfterRepeatedHijacks() {
        let controller = PriorityMockController(inputs: [builtIn, usb, pods], selected: usb.id)
        let store = makeStore(controller: controller)
        store.addToPriority(usb, direction: .input)
        store.locksInput = true

        for _ in 0..<3 {
            controller.selectedID = pods.id
            store.settle()
            XCTAssertEqual(controller.selectedID, usb.id)
            clock = clock.addingTimeInterval(1)
        }

        controller.selectedID = pods.id
        store.settle()

        XCTAssertEqual(controller.selectedID, pods.id, "fourth hijack inside the window must not be fought")
        XCTAssertEqual(store.inputLockStatus, .paused)

        clock = clock.addingTimeInterval(120)
        store.settle()
        XCTAssertEqual(controller.selectedID, usb.id)
        XCTAssertEqual(store.inputLockStatus, .active)
    }

    func testPriorityAndLocksPersistByUIDIncludingDisconnectedDevices() {
        let defaults = makeDefaults()
        let controller = PriorityMockController(inputs: [builtIn], selected: builtIn.id)
        let first = makeStore(controller: controller, defaults: defaults)
        first.addToPriority(PriorityEntry(uid: "pods", name: "AirPods"), direction: .input)
        first.addToPriority(builtIn, direction: .input)
        first.locksInput = true

        let second = makeStore(controller: controller, defaults: defaults)

        XCTAssertEqual(second.inputPriority.map(\.uid), ["pods", "built-in"])
        XCTAssertTrue(second.locksInput)
        XCTAssertFalse(second.isConnected(second.inputPriority[0], direction: .input))
        XCTAssertTrue(second.isConnected(second.inputPriority[1], direction: .input))
    }

    func testMoveAndRemoveEntries() {
        let controller = PriorityMockController(inputs: [builtIn, usb, pods], selected: builtIn.id)
        let store = makeStore(controller: controller)
        store.addToPriority(builtIn, direction: .input)
        store.addToPriority(usb, direction: .input)
        store.addToPriority(pods, direction: .input)

        store.movePriority(from: IndexSet(integer: 2), to: 0, direction: .input)
        XCTAssertEqual(store.inputPriority.map(\.uid), ["pods", "built-in", "usb"])

        store.removeFromPriority(uid: "built-in", direction: .input)
        XCTAssertEqual(store.inputPriority.map(\.uid), ["pods", "usb"])
    }

    // MARK: Stale input mute (another app muted the device)

    func testMutedActiveInputIsSurfacedButNeverClearedSilently() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: builtIn.id)
        controller.muted = [builtIn.id]
        let store = makeStore(controller: controller)

        store.settle()

        XCTAssertEqual(store.inputSilence, .muted)
        XCTAssertTrue(controller.muted.contains(builtIn.id))

        store.unmuteSelectedInput()
        XCTAssertNil(store.inputSilence)
        XCTAssertTrue(controller.muted.isEmpty)
    }

    func testZeroInputVolumeIsSurfaced() {
        let controller = PriorityMockController(inputs: [builtIn], selected: builtIn.id)
        controller.volumes = [builtIn.id: 0]
        let store = makeStore(controller: controller)

        XCTAssertEqual(store.inputSilence, .zeroVolume)
        store.unmuteSelectedInput()
        XCTAssertNil(store.inputSilence)
    }

    func testStaleMuteIsClearedOnSwitchOnlyWhenOptedIn() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        controller.muted = [builtIn.id]
        let store = makeStore(controller: controller)

        store.select(builtIn)
        XCTAssertTrue(controller.muted.contains(builtIn.id), "off by default")

        controller.selectedID = usb.id
        store.refresh()
        store.clearsStaleMuteOnSwitch = true
        store.select(builtIn)
        XCTAssertFalse(controller.muted.contains(builtIn.id))
    }

    func testStaleMuteIsNotClearedWhileGlobalMuteIsActive() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        controller.muted = [builtIn.id]
        let store = makeStore(controller: controller)
        store.clearsStaleMuteOnSwitch = true
        store.globalMuteActive = true

        store.select(builtIn)

        XCTAssertTrue(controller.muted.contains(builtIn.id))
    }

    // MARK: Bluetooth transition repair (bug fix)

    func testDefaultInputWithoutAUsableStreamIsRepairedToTheLastHealthyDevice() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        let store = makeStore(controller: controller)

        // AirPods become the default before their input stream exists, so they
        // are absent from the usable input list.
        controller.selectedID = pods.id
        store.settle()

        XCTAssertEqual(controller.selectedID, usb.id)
        XCTAssertEqual(store.selectedDeviceID, usb.id)
    }

    func testDeadDefaultFallsBackToBuiltInWhenNothingWasHealthy() {
        let controller = PriorityMockController(inputs: [usb, builtIn], selected: 0)
        let store = makeStore(controller: controller)

        store.settle()

        XCTAssertEqual(controller.selectedID, builtIn.id)
    }

    func testHealthyDefaultIsLeftAloneWhenLockIsOff() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        let store = makeStore(controller: controller)

        store.settle()

        XCTAssertEqual(controller.selectedID, usb.id)
        XCTAssertEqual(controller.setInputCalls, 0)
    }

    func testRepairIsRateLimited() {
        let controller = PriorityMockController(inputs: [builtIn, usb], selected: usb.id)
        let store = makeStore(controller: controller)

        for _ in 0..<6 {
            controller.selectedID = pods.id
            store.settle()
            clock = clock.addingTimeInterval(1)
        }

        XCTAssertEqual(controller.setInputCalls, 3)
    }
}

private final class PriorityMockController: AudioDeviceControlling, @unchecked Sendable {
    var inputs: [AudioDevice]
    var selectedID: AudioDeviceID
    var outputs: [AudioDevice]
    var selectedOutputID: AudioDeviceID
    var setInputCalls = 0

    init(
        inputs: [AudioDevice],
        selected: AudioDeviceID,
        outputs: [AudioDevice] = [],
        selectedOutput: AudioDeviceID = 0
    ) {
        self.inputs = inputs
        self.selectedID = selected
        self.outputs = outputs
        self.selectedOutputID = selectedOutput
    }

    var muted: Set<AudioDeviceID> = []

    func inputDevices() throws -> [AudioDevice] {
        inputs.map {
            AudioDevice(id: $0.id, uid: $0.uid, name: $0.name, transport: $0.transport,
                        channelCount: $0.channelCount, volume: volumes[$0.id],
                        isVolumeSettable: volumes[$0.id] != nil, isMuted: muted.contains($0.id))
        }
    }

    var volumes: [AudioDeviceID: Float32] = [:]

    func setInputMute(_ value: Bool, for id: AudioDeviceID) throws {
        if value { muted.insert(id) } else { muted.remove(id) }
    }
    func outputDevices() throws -> [AudioDevice] { outputs }
    func defaultInputDeviceID() throws -> AudioDeviceID { selectedID }
    func defaultOutputDeviceID() throws -> AudioDeviceID { selectedOutputID }

    func setDefaultInputDevice(_ id: AudioDeviceID) throws {
        setInputCalls += 1
        selectedID = id
    }

    func setDefaultOutputDevice(_ id: AudioDeviceID) throws { selectedOutputID = id }
    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws { volumes[id] = scalar }
    func setOutputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {}
}
