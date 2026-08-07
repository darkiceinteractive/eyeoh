import AudioToolbox
import Foundation
import Observation

@MainActor
@Observable
final class AudioDeviceStore {
    private let controller: any AudioDeviceControlling
    private let volumePresets: DeviceVolumePresets
    private var monitorTask: Task<Void, Never>?

    private(set) var devices: [AudioDevice] = []
    private(set) var selectedDeviceID: AudioDeviceID?
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var selectedOutputDeviceID: AudioDeviceID?
    private(set) var errorMessage: String?

    init(
        controller: any AudioDeviceControlling,
        volumePresets: DeviceVolumePresets = DeviceVolumePresets()
    ) {
        self.controller = controller
        self.volumePresets = volumePresets
        refresh()
    }

    var selectedDevice: AudioDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var selectedOutputDevice: AudioDevice? {
        outputDevices.first { $0.id == selectedOutputDeviceID }
    }

    var menuBarTitle: String {
        shortened(selectedDevice?.name ?? "No input")
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
            if let presetError {
                errorMessage = "Output switched, but its saved volume could not be restored: \(presetError.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func shortened(_ name: String) -> String {
        let limit = 18
        guard name.count > limit else { return name }
        return String(name.prefix(limit - 1)) + "…"
    }
}
