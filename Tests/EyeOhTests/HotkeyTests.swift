import AudioToolbox
import Carbon.HIToolbox
import XCTest
@testable import EyeOh

@MainActor
final class HotkeyTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, () -> Void) {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
    }

    func testBindingEncodesAndMasksUnknownModifierBits() throws {
        let binding = HotkeyBinding(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | optionKey) | 0x1_0000)
        XCTAssertEqual(binding.modifiers, UInt32(cmdKey | optionKey))

        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: JSONEncoder().encode(binding))
        XCTAssertEqual(decoded, binding)
        XCTAssertEqual(binding.displayString, "⌥⌘M")
    }

    func testBindingRequiresCommandControlOrOption() {
        XCTAssertFalse(HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: 0).isValid)
        XCTAssertFalse(HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).isValid)
        XCTAssertTrue(HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey)).isValid)
    }

    func testAllShortcutsAreUnsetByDefault() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let preferences = HotkeyPreferences(defaults: defaults)
        for action in HotkeyAction.allCases {
            XCTAssertNil(preferences.binding(for: action))
        }
    }

    func testBindingsPersistAndClear() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let binding = HotkeyBinding(keyCode: UInt32(kVK_ANSI_M), modifiers: UInt32(cmdKey | shiftKey))

        let first = HotkeyPreferences(defaults: defaults)
        XCTAssertEqual(first.set(binding, for: .toggleMicMute), .assigned)
        XCTAssertEqual(HotkeyPreferences(defaults: defaults).binding(for: .toggleMicMute), binding)

        first.set(nil, for: .toggleMicMute)
        XCTAssertNil(HotkeyPreferences(defaults: defaults).binding(for: .toggleMicMute))
    }

    func testConflictsAndInvalidBindingsAreRejected() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let preferences = HotkeyPreferences(defaults: defaults)
        let binding = HotkeyBinding(keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(controlKey))

        XCTAssertEqual(preferences.set(binding, for: .nextInput), .assigned)
        XCTAssertEqual(preferences.set(binding, for: .nextOutput), .conflict(.nextInput))
        XCTAssertNil(preferences.binding(for: .nextOutput))
        XCTAssertEqual(preferences.set(binding, for: .nextInput), .assigned)
        XCTAssertEqual(
            preferences.set(HotkeyBinding(keyCode: 0, modifiers: 0), for: .openMenu),
            .invalid
        )
    }

    func testCorruptStoredDataIsIgnored() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        defaults.set(Data("not json".utf8), forKey: HotkeyAction.openMenu.preferenceKey)
        XCTAssertNil(HotkeyPreferences(defaults: defaults).binding(for: .openMenu))
    }

    func testOnChangeFiresWhenBindingsChange() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let preferences = HotkeyPreferences(defaults: defaults)
        var calls = 0
        preferences.onChange = { calls += 1 }
        preferences.set(HotkeyBinding(keyCode: 1, modifiers: UInt32(cmdKey)), for: .openMenu)
        preferences.set(nil, for: .openMenu)
        XCTAssertEqual(calls, 2)
    }

    func testCyclerWrapsAndHandlesEdges() {
        func device(_ id: AudioDeviceID) -> AudioDevice {
            AudioDevice(id: id, uid: "\(id)", name: "D\(id)", transport: .usb, channelCount: 1)
        }
        let devices = [device(1), device(2), device(3)]

        XCTAssertEqual(DeviceCycler.next(in: devices, after: 1)?.id, 2)
        XCTAssertEqual(DeviceCycler.next(in: devices, after: 3)?.id, 1)
        XCTAssertEqual(DeviceCycler.next(in: devices, after: 99)?.id, 1)
        XCTAssertEqual(DeviceCycler.next(in: devices, after: nil)?.id, 1)
        XCTAssertNil(DeviceCycler.next(in: [], after: 1))
        XCTAssertNil(DeviceCycler.next(in: [device(1)], after: 1))
        XCTAssertEqual(DeviceCycler.next(in: [device(1)], after: 5)?.id, 1)
    }
}

@MainActor
final class MicMuteControllerTests: XCTestCase {
    func testMutesAndUnmutesWithMuteProperty() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        let controller = MicMuteController(client: client)

        controller.toggle()
        XCTAssertTrue(controller.isMuted)
        XCTAssertTrue(controller.isGlobalMuteActive)
        XCTAssertEqual(client.muted[1], true)

        controller.toggle()
        XCTAssertFalse(controller.isMuted)
        XCTAssertFalse(controller.isGlobalMuteActive)
        XCTAssertEqual(client.muted[1], false)
    }

    func testFallsBackToVolumeAndRestoresPreviousLevel() {
        let client = MockMuteClient()
        client.methods[1] = .volumeScalar
        client.volumes[1] = 0.6
        let controller = MicMuteController(client: client)

        controller.mute()
        XCTAssertEqual(client.volumes[1], 0)
        controller.unmute()
        XCTAssertEqual(client.volumes[1], 0.6)
    }

    func testVolumeAlreadyZeroIsNotOwnedAndForceUnmuteRestoresFull() {
        let client = MockMuteClient()
        client.methods[1] = .volumeScalar
        client.volumes[1] = 0
        let controller = MicMuteController(client: client)

        controller.mute()
        controller.unmute()
        XCTAssertEqual(client.volumes[1], 0)
        controller.forceUnmute()
        XCTAssertEqual(client.volumes[1], 1)
    }

    func testUnsupportedDeviceReportsInsteadOfMuting() {
        let client = MockMuteClient()
        let controller = MicMuteController(client: client)

        XCTAssertFalse(controller.isSupported)
        controller.toggle()
        XCTAssertFalse(controller.isMuted)
        XCTAssertNotNil(controller.errorMessage)
    }

    func testMuteFollowsDefaultInputChange() {
        let client = MockMuteClient()
        client.methods = [1: .muteProperty, 2: .volumeScalar]
        client.volumes[2] = 0.5
        let controller = MicMuteController(client: client)
        controller.mute()

        client.defaultID = 2
        controller.refresh()

        XCTAssertTrue(controller.isMuted)
        XCTAssertEqual(client.muted[1], false)
        XCTAssertEqual(client.volumes[2], 0)
    }

    func testMuteClearsWhenNewInputCannotBeMuted() {
        let client = MockMuteClient()
        client.methods = [1: .muteProperty]
        let controller = MicMuteController(client: client)
        controller.mute()

        client.defaultID = 2
        controller.refresh()

        XCTAssertFalse(controller.isMuted)
        XCTAssertEqual(client.muted[1], false)
        XCTAssertNotNil(controller.errorMessage)
    }

    func testExternalUnmuteIsDetected() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        let controller = MicMuteController(client: client)
        controller.mute()

        client.muted[1] = false
        controller.refresh()
        XCTAssertFalse(controller.isMuted)
    }

    func testAlreadyMutedDeviceIsReportedSeparatelyNotOwned() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        client.muted[1] = true
        let controller = MicMuteController(client: client)
        XCTAssertFalse(controller.isMuted)
        XCTAssertTrue(controller.isDeviceMuted)
        XCTAssertTrue(controller.isSilenced)
    }

    func testUnmuteLeavesPreExistingMuteAlone() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        client.muted[1] = true
        let controller = MicMuteController(client: client)

        controller.mute()
        XCTAssertTrue(controller.isMuted)
        controller.unmute()
        XCTAssertFalse(controller.isMuted)
        XCTAssertEqual(client.muted[1], true)
        XCTAssertTrue(controller.isDeviceMuted)
    }

    func testToggleClearsForeignMuteExplicitly() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        client.muted[1] = true
        let controller = MicMuteController(client: client)

        controller.toggle()
        XCTAssertEqual(client.muted[1], false)
        XCTAssertFalse(controller.isDeviceMuted)
    }

    func testUnmuteDoesNotTouchVolumeChangedByAnotherApp() {
        let client = MockMuteClient()
        client.methods[1] = .volumeScalar
        client.volumes[1] = 0.6
        let controller = MicMuteController(client: client)
        controller.mute()

        client.volumes[1] = 0.3
        controller.unmute()
        XCTAssertEqual(client.volumes[1], 0.3)
    }

    func testRestoreOnQuitUnmutes() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        let controller = MicMuteController(client: client)
        controller.mute()
        controller.restoreOnQuit()
        XCTAssertEqual(client.muted[1], false)
        XCTAssertFalse(controller.isMuted)
    }

    func testSetFailureLeavesStateUnmuted() {
        let client = MockMuteClient()
        client.methods[1] = .muteProperty
        client.failSet = true
        let controller = MicMuteController(client: client)
        controller.mute()
        XCTAssertFalse(controller.isMuted)
        XCTAssertNotNil(controller.errorMessage)
    }
}

private final class MockMuteClient: MicMuteControlling, @unchecked Sendable {
    var defaultID: AudioDeviceID = 1
    var methods: [AudioDeviceID: MicMuteMethod] = [:]
    var muted: [AudioDeviceID: Bool] = [:]
    var volumes: [AudioDeviceID: Float32] = [:]
    var failSet = false

    func defaultInputDeviceID() throws -> AudioDeviceID { defaultID }
    func uid(for id: AudioDeviceID) -> String? { "uid-\(id)" }
    func deviceID(forUID uid: String) -> AudioDeviceID? { AudioDeviceID(uid.dropFirst(4)) }
    func muteMethod(for id: AudioDeviceID) -> MicMuteMethod? { methods[id] }
    func isMuted(_ id: AudioDeviceID) -> Bool? { methods[id] == .muteProperty ? (muted[id] ?? false) : nil }

    func setMuted(_ value: Bool, for id: AudioDeviceID) throws {
        if failSet { throw CoreAudioError(operation: "mute", status: -1) }
        muted[id] = value
    }

    func inputVolume(for id: AudioDeviceID) -> Float32? { volumes[id] }

    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        if failSet { throw CoreAudioError(operation: "volume", status: -1) }
        volumes[id] = scalar
    }

    func inputChanges() -> AsyncStream<Void> { AsyncStream { _ in } }
}
