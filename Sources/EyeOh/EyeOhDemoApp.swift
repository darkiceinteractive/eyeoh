import AppKit
import AudioToolbox
import SwiftUI

/// Standalone fixture build. The regular app target excludes this entry point.
@main
@MainActor
struct EyeOhDemoApp: App {
    private let store: AudioDeviceStore
    private let cameraStore: CameraDeviceStore
    private let preferences: AppPreferences
    private let updater = SoftwareUpdateController()
    private let mute: MicMuteController

    init() {
        let defaults = UserDefaults(suiteName: "au.com.darkice.eyeoh.demo.\(UUID().uuidString)")!
        let cameraDisconnected = CommandLine.arguments.contains("--camera-disconnected")
        let audio = DemoAudio(cameraDisconnected: cameraDisconnected)
        let remembered = RememberedBluetoothDevices(defaults: defaults)
        for headset in DemoAudio.remembered {
            remembered.remember(headset, direction: .input)
            remembered.remember(headset, direction: .output)
        }
        store = AudioDeviceStore(
            controller: audio,
            volumePresets: DeviceVolumePresets(defaults: defaults),
            bluetoothConnector: audio,
            rememberedBluetoothDevices: remembered,
            priorityPreferences: DevicePriorityPreferences(defaults: defaults)
        )
        let mute = MicMuteController(client: audio)
        store.globalMuteSource = { mute.isGlobalMuteActive }
        self.mute = mute
        let cameras = DemoCamera(disconnected: cameraDisconnected)
        let persistence = CameraPersistence(defaults: defaults)
        persistence.savedCamera = SavedCamera(DemoCamera.c920)
        cameraStore = CameraDeviceStore(controller: cameras, persistence: persistence)
        preferences = AppPreferences(defaults: defaults)
        preferences.showsInputVolumeInMenu = true
    }

    var body: some Scene {
        WindowGroup("EyeOh Demo") {
            VStack {
                Menu("EyeOh Demo", systemImage: "switch.2") { menu }
                    .fixedSize()
                    .accessibilityIdentifier("eyeoh-demo-menu")
                    .padding(.top, 8)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.075, green: 0.14, blue: 0.17))
        }
        .defaultSize(width: 760, height: 860)
        .defaultPosition(.topTrailing)

        MenuBarExtra {
            menu
        } label: {
            Image(nsImage: IORouteStatusIcon.image).accessibilityLabel("EyeOh Demo")
        }
        .menuBarExtraStyle(.menu)

        Window("Camera Preview", id: "camera-preview") {
            ContentUnavailableView(
                cameraStore.selectedCamera?.name ?? "Camera Preview", systemImage: "video",
                description: Text("Demo camera. No live feed.")
            )
            .frame(minWidth: 420, minHeight: 240)
        }

        Settings {
            Form {
                Toggle("Show input volume", isOn: Binding(
                    get: { preferences.showsInputVolumeInMenu },
                    set: { preferences.showsInputVolumeInMenu = $0 }
                ))
                Text("Demo devices and settings are separate from your Mac’s devices.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }

    private var menu: some View {
        EyeOhMenuView(store: store, cameraStore: cameraStore, preferences: preferences,
                      softwareUpdater: updater, micMute: mute)
    }
}

@MainActor
private final class DemoCamera: CameraDeviceControlling {
    static let c920 = CameraDevice(id: "c920", name: "HD Pro Webcam C920", kind: .external)
    private let available: [CameraDevice]
    private var selected: String

    init(disconnected: Bool) {
        var cameras = [
            CameraDevice(id: "airhug", name: "AIRHUG 11", kind: .external),
            CameraDevice(id: "mac", name: "MacBook Camera", kind: .builtIn),
            CameraDevice(id: "mac-desk", name: "MacBook Desk View Camera", kind: .deskView),
            CameraDevice(id: "phone", name: "iPhone Camera", kind: .continuity),
            CameraDevice(id: "phone-desk", name: "iPhone Desk View Camera", kind: .deskView),
        ]
        if !disconnected { cameras.insert(Self.c920, at: 1) }
        available = cameras
        selected = disconnected ? "mac" : Self.c920.id
    }

    func cameras() -> [CameraDevice] { available }
    func preferredCameraID() -> String? { selected }
    func setPreferredCamera(_ id: String) throws { selected = id }
}

private final class DemoAudio: AudioDeviceControlling, BluetoothDeviceConnecting, MicMuteControlling, @unchecked Sendable {
    private struct State {
        var input: AudioDeviceID = 6
        var output: AudioDeviceID = 6
        var systemOutput: AudioDeviceID = 6
        var inputVolumes: [AudioDeviceID: Float32] = [:]
        var outputVolumes: [AudioDeviceID: Float32] = [:]
        var muted: Set<AudioDeviceID> = []
        var connected: Set<String> = []
    }
    private let lock = NSLock()
    private var state = State()
    private let availableInputs: [AudioDevice]

    init(cameraDisconnected: Bool) {
        availableInputs = cameraDisconnected ? Self.inputs.filter { $0.id != 2 } : Self.inputs
    }

    static let remembered = [
        device(20, "JBL Wave Flex 2", .bluetooth, address: "02-00-00-00-00-20"),
        device(21, "Onyx Star", .bluetooth, address: "02-00-00-00-00-21"),
    ]
    private static let headset = device(6, "WH-1000XM5", .bluetooth, address: "02-00-00-00-00-06")
    private static let inputs = [
        device(1, "AIRHUG 11", .usb), device(2, "HD Pro Webcam C920", .usb),
        device(3, "Immersed", .virtual), device(4, "MacBook Microphone", .builtIn),
        device(5, "iPhone Microphone", .unknown), headset,
    ]
    private static let outputs = [
        device(10, "Immersed", .virtual), device(11, "LU28R55", .displayPort),
        device(12, "MacBook Speakers", .builtIn), device(13, "Q32G2WG4+", .displayPort), headset,
    ]

    private static func device(_ id: AudioDeviceID, _ name: String, _ transport: AudioDeviceTransport,
                               address: String? = nil) -> AudioDevice {
        AudioDevice(id: id, uid: address ?? "demo-\(id)", name: name, transport: transport, channelCount: 2)
    }

    private func routes(_ base: [AudioDevice], input: Bool) -> [AudioDevice] {
        lock.withLock {
            let connected = Self.remembered.filter { state.connected.contains($0.uid) }
            let volumes = input ? state.inputVolumes : state.outputVolumes
            return (base + connected).map { device in
                AudioDevice(id: device.id, uid: device.uid, name: device.name, transport: device.transport,
                            channelCount: device.channelCount, volume: volumes[device.id] ?? (input ? 0.69 : 0.37),
                            isVolumeSettable: true, isMuted: input ? state.muted.contains(device.id) : nil)
            }
        }
    }

    func inputDevices() throws -> [AudioDevice] { routes(availableInputs, input: true) }
    func outputDevices() throws -> [AudioDevice] { routes(Self.outputs, input: false) }
    func defaultInputDeviceID() throws -> AudioDeviceID { lock.withLock { state.input } }
    func defaultOutputDeviceID() throws -> AudioDeviceID { lock.withLock { state.output } }
    func defaultSystemOutputDeviceID() throws -> AudioDeviceID { lock.withLock { state.systemOutput } }
    func setDefaultInputDevice(_ id: AudioDeviceID) throws { lock.withLock { state.input = id } }
    func setDefaultOutputDevice(_ id: AudioDeviceID) throws { lock.withLock { state.output = id } }
    func setSystemOutputDevice(_ id: AudioDeviceID) throws { lock.withLock { state.systemOutput = id } }
    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws { lock.withLock { state.inputVolumes[id] = scalar } }
    func setOutputVolume(_ scalar: Float32, for id: AudioDeviceID) throws { lock.withLock { state.outputVolumes[id] = scalar } }
    func setInputMute(_ muted: Bool, for id: AudioDeviceID) throws { try setMuted(muted, for: id) }
    func connect(address: String) async throws { _ = lock.withLock { state.connected.insert(address) } }
    func uid(for id: AudioDeviceID) -> String? { routes(availableInputs, input: true).first { $0.id == id }?.uid }
    func deviceID(forUID uid: String) -> AudioDeviceID? { routes(availableInputs, input: true).first { $0.uid == uid }?.id }
    func muteMethod(for id: AudioDeviceID) -> MicMuteMethod? { .muteProperty }
    func isMuted(_ id: AudioDeviceID) -> Bool? { lock.withLock { state.muted.contains(id) } }
    func setMuted(_ muted: Bool, for id: AudioDeviceID) throws {
        lock.withLock {
            if muted { state.muted.insert(id) } else { state.muted.remove(id) }
        }
    }
    func inputVolume(for id: AudioDeviceID) -> Float32? { lock.withLock { state.inputVolumes[id] ?? 0.69 } }
    func inputChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
