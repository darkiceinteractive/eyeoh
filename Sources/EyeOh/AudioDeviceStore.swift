import AudioToolbox
import Foundation
import Observation

@MainActor
@Observable
final class AudioDeviceStore {
    private let controller: any AudioDeviceControlling
    private let volumePresets: DeviceVolumePresets
    private let bluetoothConnector: any BluetoothDeviceConnecting
    private let rememberedBluetoothDevices: RememberedBluetoothDevices
    private var monitorTask: Task<Void, Never>?

    private(set) var devices: [AudioDevice] = []
    private(set) var selectedDeviceID: AudioDeviceID?
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var selectedOutputDeviceID: AudioDeviceID?
    private(set) var rememberedInputDevices: [RememberedBluetoothAudioDevice] = []
    private(set) var rememberedOutputDevices: [RememberedBluetoothAudioDevice] = []
    private(set) var rememberedBluetoothDeviceCount = 0
    private(set) var connectingBluetoothAddress: String?
    private(set) var errorMessage: String?
    var showsDisconnectedBluetoothDevices: Bool {
        didSet {
            rememberedBluetoothDevices.showsDisconnectedDevices = showsDisconnectedBluetoothDevices
            refreshRememberedDevices()
        }
    }

    init(
        controller: any AudioDeviceControlling,
        volumePresets: DeviceVolumePresets = DeviceVolumePresets(),
        bluetoothConnector: any BluetoothDeviceConnecting = IOBluetoothClient(),
        rememberedBluetoothDevices: RememberedBluetoothDevices = RememberedBluetoothDevices()
    ) {
        self.controller = controller
        self.volumePresets = volumePresets
        self.bluetoothConnector = bluetoothConnector
        self.rememberedBluetoothDevices = rememberedBluetoothDevices
        showsDisconnectedBluetoothDevices = rememberedBluetoothDevices.showsDisconnectedDevices
        refresh()
    }

    var selectedDevice: AudioDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var selectedOutputDevice: AudioDevice? {
        outputDevices.first { $0.id == selectedOutputDeviceID }
    }

    var menuBarTitle: String {
        Self.compactDeviceName(selectedDevice?.name ?? "No input")
    }

    var statusAccessibilityLabel: String {
        let input = selectedDevice?.name ?? "No input"
        let output = selectedOutputDevice?.name ?? "No output"
        return "EyeOh. Input: \(input). Output: \(output)."
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        let changes = controller.deviceChanges()
        monitorTask = Task { [weak self] in
            for await _ in changes {
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    func refresh() {
        do {
            let refreshedInputs = try controller.inputDevices()
            let refreshedOutputs = try controller.outputDevices()
            let refreshedInputID = try controller.defaultInputDeviceID()
            let refreshedOutputID = try controller.defaultOutputDeviceID()

            devices = refreshedInputs
            outputDevices = refreshedOutputs
            selectedDeviceID = refreshedInputID
            selectedOutputDeviceID = refreshedOutputID
            refreshedInputs.forEach {
                rememberedBluetoothDevices.remember($0, direction: .input)
            }
            refreshedOutputs.forEach {
                rememberedBluetoothDevices.remember($0, direction: .output)
            }
            refreshRememberedDevices()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ device: AudioDevice) {
        guard device.id != selectedDeviceID else { return }
        do {
            rememberCurrentInputVolume()
            try controller.setDefaultInputDevice(device.id)
            var presetError: Error?
            if let preset = volumePresets.value(for: device.uid, direction: .input),
               device.isVolumeSettable {
                do {
                    try controller.setInputVolume(preset, for: device.id)
                } catch {
                    presetError = error
                }
            }
            refresh()
            Diagnostics.record(.inputChanged)
            if let presetError {
                errorMessage = "Input switched, but its saved volume could not be restored: \(presetError.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectOutput(_ device: AudioDevice) {
        guard device.id != selectedOutputDeviceID else { return }
        do {
            rememberCurrentOutputVolume()
            try controller.setDefaultOutputDevice(device.id)
            var presetError: Error?
            if let preset = volumePresets.value(for: device.uid, direction: .output),
               device.isVolumeSettable {
                do {
                    try controller.setOutputVolume(preset, for: device.id)
                } catch {
                    presetError = error
                }
            }
            refresh()
            Diagnostics.record(.outputChanged)
            if let presetError {
                errorMessage = "Output switched, but its saved volume could not be restored: \(presetError.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectInput(_ remembered: RememberedBluetoothAudioDevice) async {
        await connect(remembered, direction: .input)
    }

    func connectOutput(_ remembered: RememberedBluetoothAudioDevice) async {
        await connect(remembered, direction: .output)
    }

    func clearRememberedBluetoothDevices() {
        rememberedBluetoothDevices.removeAll()
        refreshRememberedDevices()
    }

    func isConnecting(_ remembered: RememberedBluetoothAudioDevice) -> Bool {
        connectingBluetoothAddress == remembered.address
    }

    func setSelectedInputVolume(_ scalar: Float32) {
        guard let device = selectedDevice, device.isVolumeSettable else { return }
        do {
            try controller.setInputVolume(scalar, for: device.id)
            volumePresets.setValue(scalar, for: device.uid, direction: .input)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSelectedOutputVolume(_ scalar: Float32) {
        guard let device = selectedOutputDevice, device.isVolumeSettable else { return }
        do {
            try controller.setOutputVolume(scalar, for: device.id)
            volumePresets.setValue(scalar, for: device.uid, direction: .output)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rememberCurrentInputVolume() {
        guard let device = selectedDevice,
              device.isVolumeSettable,
              let volume = device.volume
        else { return }
        volumePresets.setValue(volume, for: device.uid, direction: .input)
    }

    private func rememberCurrentOutputVolume() {
        guard let device = selectedOutputDevice,
              device.isVolumeSettable,
              let volume = device.volume
        else { return }
        volumePresets.setValue(volume, for: device.uid, direction: .output)
    }

    private func connect(
        _ remembered: RememberedBluetoothAudioDevice,
        direction: DeviceVolumePresets.Direction
    ) async {
        guard connectingBluetoothAddress == nil else { return }
        let previousInputID = try? controller.defaultInputDeviceID()
        let previousOutputID = try? controller.defaultOutputDeviceID()
        let previousSystemOutputID = try? controller.defaultSystemOutputDeviceID()
        connectingBluetoothAddress = remembered.address
        errorMessage = nil
        defer { connectingBluetoothAddress = nil }

        do {
            try await bluetoothConnector.connect(address: remembered.address)

            for attempt in 0..<40 {
                refresh()
                let target: AudioDevice?
                switch direction {
                case .input:
                    target = remembered.inputUID.flatMap { uid in
                        devices.first { $0.uid == uid }
                    }
                case .output:
                    target = remembered.outputUID.flatMap { uid in
                        outputDevices.first { $0.uid == uid }
                    }
                }

                if let target {
                    // Bluetooth profile activation can make macOS switch every audio
                    // default. Restore the snapshot first so the clicked row changes
                    // only its own direction and the normal selection path can save
                    // and restore the correct per-device volume.
                    if let previousInputID {
                        try? controller.setDefaultInputDevice(previousInputID)
                    }
                    if let previousOutputID {
                        try? controller.setDefaultOutputDevice(previousOutputID)
                    }
                    if let previousSystemOutputID {
                        try? controller.setSystemOutputDevice(previousSystemOutputID)
                    }
                    refresh()

                    switch direction {
                    case .input:
                        select(target)
                    case .output:
                        selectOutput(target)
                    }
                    return
                }

                if attempt < 39 {
                    try await Task.sleep(for: .milliseconds(250))
                }
            }

            errorMessage = "Connected to \(remembered.name), but macOS did not make its audio route available."
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Couldn't connect to \(remembered.name). Make sure it is on, nearby and not connected to another device."
        }
    }

    private func refreshRememberedDevices() {
        let remembered = rememberedBluetoothDevices.devices
        rememberedBluetoothDeviceCount = remembered.count

        guard showsDisconnectedBluetoothDevices else {
            rememberedInputDevices = []
            rememberedOutputDevices = []
            return
        }

        let liveInputUIDs = Set(devices.map(\.uid))
        let liveOutputUIDs = Set(outputDevices.map(\.uid))
        rememberedInputDevices = remembered.filter {
            guard let uid = $0.inputUID else { return false }
            return !liveInputUIDs.contains(uid)
        }
        rememberedOutputDevices = remembered.filter {
            guard let uid = $0.outputUID else { return false }
            return !liveOutputUIDs.contains(uid)
        }
    }

    nonisolated static func compactDeviceName(_ name: String) -> String {
        var compact = name
            .replacingOccurrences(of: "MacBook Pro", with: "MacBook", options: .caseInsensitive)

        let removableSuffixes = [
            " Microphone", " Speakers", " Camera", " Audio", " Built-in"
        ]
        for suffix in removableSuffixes {
            if compact.range(of: suffix, options: [.anchored, .backwards, .caseInsensitive]) != nil {
                compact.removeLast(suffix.count)
            }
        }

        compact = compact.trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = 11
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
