import AudioToolbox
import XCTest
@testable import EyeOh

@MainActor
final class AudioDeviceStoreTests: XCTestCase {
    func testLoadsDevicesAndSelectedDevice() {
        let controller = MockAudioController()
        controller.devices = [
            AudioDevice(
                id: 1,
                uid: "built-in",
                name: "MacBook Pro Microphone",
                transport: .builtIn,
                channelCount: 1
            ),
            AudioDevice(
                id: 2,
                uid: "usb",
                name: "AIRHUG 11",
                transport: .usb,
                channelCount: 2
            ),
        ]
        controller.selectedID = 2
        controller.outputs = [
            AudioDevice(
                id: 3,
                uid: "speakers",
                name: "MacBook Pro Speakers",
                transport: .builtIn,
                channelCount: 2
            ),
        ]
        controller.selectedOutputID = 3

        let store = AudioDeviceStore(controller: controller)

        XCTAssertEqual(store.devices.count, 2)
        XCTAssertEqual(store.menuBarTitle, "AIRHUG 11")
        XCTAssertEqual(store.selectedOutputDevice?.name, "MacBook Pro Speakers")
        XCTAssertNil(store.errorMessage)
    }

    func testMenuBarTitleUsesACompactRecognisableDeviceName() {
        XCTAssertEqual(
            AudioDeviceStore.compactDeviceName("MacBook Pro Microphone"),
            "MacBook"
        )
        XCTAssertEqual(AudioDeviceStore.compactDeviceName("Onyx Star"), "Onyx Star")
        XCTAssertEqual(AudioDeviceStore.compactDeviceName("AIRHUG 11"), "AIRHUG 11")
        XCTAssertEqual(
            AudioDeviceStore.compactDeviceName("A Very Long USB Microphone"),
            "A Very Lon…"
        )
    }

    func testSelectChangesDefaultInput() {
        let controller = MockAudioController()
        let builtIn = AudioDevice(
            id: 1,
            uid: "built-in",
            name: "MacBook Pro Microphone",
            transport: .builtIn,
            channelCount: 1
        )
        let onyx = AudioDevice(
            id: 2,
            uid: "onyx",
            name: "Onyx Star",
            transport: .bluetooth,
            channelCount: 1
        )
        controller.devices = [builtIn, onyx]
        controller.selectedID = builtIn.id
        controller.outputs = [onyx]
        controller.selectedOutputID = onyx.id
        let store = AudioDeviceStore(controller: controller)

        store.select(onyx)

        XCTAssertEqual(controller.selectedID, onyx.id)
        XCTAssertEqual(store.selectedDeviceID, onyx.id)
        XCTAssertEqual(store.menuBarTitle, "Onyx Star")
    }

    func testSelectOutputChangesDefaultOutput() {
        let controller = MockAudioController()
        let speakers = AudioDevice(
            id: 3,
            uid: "speakers",
            name: "MacBook Pro Speakers",
            transport: .builtIn,
            channelCount: 2
        )
        let display = AudioDevice(
            id: 4,
            uid: "display",
            name: "Studio Display",
            transport: .displayPort,
            channelCount: 2
        )
        controller.devices = [speakers]
        controller.selectedID = speakers.id
        controller.outputs = [speakers, display]
        controller.selectedOutputID = speakers.id
        let store = AudioDeviceStore(controller: controller)

        store.selectOutput(display)

        XCTAssertEqual(controller.selectedOutputID, display.id)
        XCTAssertEqual(store.selectedOutputDeviceID, display.id)
        XCTAssertEqual(store.selectedOutputDevice?.name, "Studio Display")
    }

    func testSelectionFailureLeavesAnError() {
        let controller = MockAudioController()
        let device = AudioDevice(
            id: 1,
            uid: "usb",
            name: "AIRHUG 11",
            transport: .usb,
            channelCount: 2
        )
        controller.devices = [device]
        controller.selectedID = 99
        controller.outputs = [device]
        controller.selectedOutputID = device.id
        let store = AudioDeviceStore(controller: controller)
        controller.setError = TestError.denied

        store.select(device)

        XCTAssertNotNil(store.errorMessage)
    }

    func testInputVolumeIsSavedAndReappliedForTheDevice() {
        let defaultsName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let presets = DeviceVolumePresets(defaults: defaults)

        let controller = MockAudioController()
        let builtIn = AudioDevice(
            id: 1,
            uid: "built-in",
            name: "MacBook Pro Microphone",
            transport: .builtIn,
            channelCount: 1,
            volume: 0.25,
            isVolumeSettable: true
        )
        let usb = AudioDevice(
            id: 2,
            uid: "usb",
            name: "AIRHUG 11",
            transport: .usb,
            channelCount: 2,
            volume: 0.5,
            isVolumeSettable: true
        )
        controller.devices = [builtIn, usb]
        controller.selectedID = builtIn.id
        controller.outputs = [builtIn]
        controller.selectedOutputID = builtIn.id
        let store = AudioDeviceStore(controller: controller, volumePresets: presets)

        store.setSelectedInputVolume(0.6)
        XCTAssertEqual(controller.inputVolumes[builtIn.id], 0.6)
        XCTAssertEqual(presets.value(for: builtIn.uid, direction: .input), 0.6)

        presets.setValue(0.4, for: usb.uid, direction: .input)
        store.select(usb)
        XCTAssertEqual(controller.selectedID, usb.id)
        XCTAssertEqual(controller.inputVolumes[usb.id], 0.4)
    }

    func testDisconnectedBluetoothInputReconnectsWithoutChangingOutput() async {
        let defaultsName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let remembered = RememberedBluetoothDevices(defaults: defaults)
        let builtIn = AudioDevice(
            id: 1,
            uid: "built-in",
            name: "MacBook Pro Microphone",
            transport: .builtIn,
            channelCount: 1
        )
        let onyxInput = AudioDevice(
            id: 2,
            uid: "BC-87-FA-9C-65-E0:input",
            name: "Onyx Star",
            transport: .bluetooth,
            channelCount: 1
        )
        let speakers = AudioDevice(
            id: 3,
            uid: "speakers",
            name: "MacBook Pro Speakers",
            transport: .builtIn,
            channelCount: 2
        )
        let onyxOutput = AudioDevice(
            id: 4,
            uid: "BC-87-FA-9C-65-E0:output",
            name: "Onyx Star",
            transport: .bluetooth,
            channelCount: 2
        )
        remembered.remember(onyxInput, direction: .input)

        let controller = MockAudioController()
        controller.devices = [builtIn]
        controller.selectedID = builtIn.id
        controller.outputs = [speakers]
        controller.selectedOutputID = speakers.id
        controller.selectedSystemOutputID = speakers.id
        let connector = MockBluetoothConnector { address in
            XCTAssertEqual(address, "BC-87-FA-9C-65-E0")
            controller.devices = [builtIn, onyxInput]
            controller.outputs = [speakers, onyxOutput]
            // Reproduces macOS switching both routes as the Bluetooth audio
            // profile becomes available.
            controller.selectedID = onyxInput.id
            controller.selectedOutputID = onyxOutput.id
            controller.selectedSystemOutputID = onyxOutput.id
        }
        let store = AudioDeviceStore(
            controller: controller,
            bluetoothConnector: connector,
            rememberedBluetoothDevices: remembered
        )

        XCTAssertEqual(store.rememberedInputDevices.first?.name, "Onyx Star")
        await store.connectInput(store.rememberedInputDevices[0])

        XCTAssertEqual(controller.selectedID, onyxInput.id)
        XCTAssertEqual(controller.selectedOutputID, speakers.id)
        XCTAssertEqual(controller.selectedSystemOutputID, speakers.id)
        XCTAssertEqual(store.selectedDeviceID, onyxInput.id)
        XCTAssertTrue(store.rememberedInputDevices.isEmpty)
        XCTAssertNil(store.errorMessage)
    }

    func testFailedBluetoothReconnectLeavesUsefulError() async {
        let defaultsName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }
        let remembered = RememberedBluetoothDevices(defaults: defaults)
        let onyx = AudioDevice(
            id: 2,
            uid: "BC-87-FA-9C-65-E0:output",
            name: "Onyx Star",
            transport: .bluetooth,
            channelCount: 2
        )
        remembered.remember(onyx, direction: .output)

        let controller = MockAudioController()
        controller.devices = [onyx]
        controller.selectedID = onyx.id
        controller.outputs = []
        controller.selectedOutputID = 99
        let connector = MockBluetoothConnector(error: BluetoothConnectionError.notPaired)
        let store = AudioDeviceStore(
            controller: controller,
            bluetoothConnector: connector,
            rememberedBluetoothDevices: remembered
        )

        await store.connectOutput(store.rememberedOutputDevices[0])

        XCTAssertTrue(store.errorMessage?.contains("Couldn't connect to Onyx Star") == true)
        XCTAssertNil(store.connectingBluetoothAddress)
    }

    func testCoreAudioCanReadAndReapplyCurrentDefault() throws {
        guard ProcessInfo.processInfo.environment["EYEOH_RUN_HARDWARE_TESTS"] == "1" else {
            throw XCTSkip("Set EYEOH_RUN_HARDWARE_TESTS=1 to run the state-changing hardware test.")
        }

        let client = CoreAudioClient()
        let devices = try client.inputDevices()
        let outputs = try client.outputDevices()
        let selectedID = try client.defaultInputDeviceID()
        let selectedOutputID = try client.defaultOutputDeviceID()
        let selectedSystemOutputID = try client.defaultSystemOutputDeviceID()

        defer {
            try? client.setDefaultInputDevice(selectedID)
            try? client.setDefaultOutputDevice(selectedOutputID)
            try? client.setSystemOutputDevice(selectedSystemOutputID)
        }

        XCTAssertFalse(devices.isEmpty)
        XCTAssertTrue(devices.contains { $0.id == selectedID })
        XCTAssertFalse(outputs.isEmpty)
        XCTAssertTrue(outputs.contains { $0.id == selectedOutputID })

        // This opt-in check writes and then restores every affected default.
        try client.setDefaultInputDevice(selectedID)
        XCTAssertEqual(try client.defaultInputDeviceID(), selectedID)

        try client.setDefaultOutputDevice(selectedOutputID)
        XCTAssertEqual(try client.defaultOutputDeviceID(), selectedOutputID)
    }
}

private extension AudioDeviceStoreTests {
    enum TestError: Error {
        case denied
    }
}

private final class MockAudioController: AudioDeviceControlling, @unchecked Sendable {
    var devices: [AudioDevice] = []
    var selectedID: AudioDeviceID = 0
    var outputs: [AudioDevice] = []
    var selectedOutputID: AudioDeviceID = 0
    var selectedSystemOutputID: AudioDeviceID = 0
    var setError: Error?
    var inputVolumes: [AudioDeviceID: Float32] = [:]
    var outputVolumes: [AudioDeviceID: Float32] = [:]

    func inputDevices() throws -> [AudioDevice] {
        devices
    }

    func defaultInputDeviceID() throws -> AudioDeviceID {
        selectedID
    }

    func outputDevices() throws -> [AudioDevice] {
        outputs
    }

    func defaultOutputDeviceID() throws -> AudioDeviceID {
        selectedOutputID
    }

    func defaultSystemOutputDeviceID() throws -> AudioDeviceID {
        selectedSystemOutputID == 0 ? selectedOutputID : selectedSystemOutputID
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) throws {
        if let setError { throw setError }
        selectedID = id
    }

    func setDefaultOutputDevice(_ id: AudioDeviceID) throws {
        if let setError { throw setError }
        selectedOutputID = id
        selectedSystemOutputID = id
    }

    func setSystemOutputDevice(_ id: AudioDeviceID) throws {
        if let setError { throw setError }
        selectedSystemOutputID = id
    }

    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        if let setError { throw setError }
        inputVolumes[id] = scalar
    }

    func setOutputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        if let setError { throw setError }
        outputVolumes[id] = scalar
    }
}

private final class MockBluetoothConnector: BluetoothDeviceConnecting, @unchecked Sendable {
    private let error: Error?
    private let onConnect: @Sendable (String) -> Void

    init(
        error: Error? = nil,
        onConnect: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.error = error
        self.onConnect = onConnect
    }

    convenience init(onConnect: @escaping @Sendable (String) -> Void) {
        self.init(error: nil, onConnect: onConnect)
    }

    func connect(address: String) async throws {
        if let error { throw error }
        onConnect(address)
    }
}
