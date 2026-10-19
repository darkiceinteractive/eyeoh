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
    private let priorityPreferences: DevicePriorityPreferences
    private let now: @MainActor () -> Date
    private let settleDelay: Duration
    private var monitorTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var inputBackoff = ReassertBackoff()
    private var outputBackoff = ReassertBackoff()
    private var lastHealthyInputUID: String?
    private var lastHealthyOutputUID: String?

    private(set) var devices: [AudioDevice] = []
    private(set) var selectedDeviceID: AudioDeviceID?
    private(set) var outputDevices: [AudioDevice] = []
    private(set) var selectedOutputDeviceID: AudioDeviceID?
    private(set) var rememberedInputDevices: [RememberedBluetoothAudioDevice] = []
    private(set) var rememberedOutputDevices: [RememberedBluetoothAudioDevice] = []
    private(set) var rememberedBluetoothDeviceCount = 0
    private(set) var connectingBluetoothAddress: String?
    private(set) var errorMessage: String?
    private(set) var inputPriority: [PriorityEntry]
    private(set) var outputPriority: [PriorityEntry]
    var locksInput: Bool {
        didSet {
            priorityPreferences.setLocks(locksInput, for: .input)
            if locksInput { enforceInputPriority() }
        }
    }
    var locksOutput: Bool {
        didSet {
            priorityPreferences.setLocks(locksOutput, for: .output)
            if locksOutput { enforceOutputPriority() }
        }
    }
    /// Reads `MicMuteController.isGlobalMuteActive`, the single source of truth for
    /// "EyeOh itself muted the microphone". Not stored here so the two cannot drift.
    @ObservationIgnored var globalMuteSource: @MainActor () -> Bool = { false }
    var globalMuteActive: Bool { globalMuteSource() }
    var clearsStaleMuteOnSwitch: Bool {
        didSet { priorityPreferences.clearsStaleMuteOnSwitch = clearsStaleMuteOnSwitch }
    }
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
        rememberedBluetoothDevices: RememberedBluetoothDevices = RememberedBluetoothDevices(),
        priorityPreferences: DevicePriorityPreferences = DevicePriorityPreferences(),
        now: @escaping @MainActor () -> Date = { Date() },
        settleDelay: Duration = .milliseconds(900)
    ) {
        self.controller = controller
        self.volumePresets = volumePresets
        self.bluetoothConnector = bluetoothConnector
        self.rememberedBluetoothDevices = rememberedBluetoothDevices
        self.priorityPreferences = priorityPreferences
        self.now = now
        self.settleDelay = settleDelay
        inputPriority = priorityPreferences.entries(for: .input)
        outputPriority = priorityPreferences.entries(for: .output)
        locksInput = priorityPreferences.locks(.input)
        locksOutput = priorityPreferences.locks(.output)
        clearsStaleMuteOnSwitch = priorityPreferences.clearsStaleMuteOnSwitch
        showsDisconnectedBluetoothDevices = rememberedBluetoothDevices.showsDisconnectedDevices
        refresh()
    }

    var selectedDevice: AudioDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var selectedOutputDevice: AudioDevice? {
        outputDevices.first { $0.id == selectedOutputDeviceID }
    }

    enum InputSilence: Equatable {
        case muted
        case zeroVolume
    }

    /// Why the active input would record silence. EyeOh never clears this by
    /// itself unless the user opted in; another app may have muted it on purpose.
    var inputSilence: InputSilence? {
        guard let device = selectedDevice else { return nil }
        if device.isMuted == true { return .muted }
        if device.isVolumeSettable, let volume = device.volume, volume <= 0 { return .zeroVolume }
        return nil
    }

    func unmuteSelectedInput() {
        guard let device = selectedDevice else { return }
        do {
            if device.isMuted == true {
                try controller.setInputMute(false, for: device.id)
            }
            if device.isVolumeSettable, let volume = device.volume, volume <= 0 {
                let saved = volumePresets.value(for: device.uid, direction: .input) ?? 0
                try controller.setInputVolume(saved > 0 ? saved : 0.75, for: device.id)
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
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
                self?.scheduleSettle()
            }
        }
        scheduleSettle()
    }

    /// Bluetooth devices announce themselves before their input stream is usable,
    /// and macOS may change defaults several times while a profile switches. Act
    /// only once the notifications have been quiet for `settleDelay`.
    private func scheduleSettle() {
        settleTask?.cancel()
        settleTask = Task { [weak self, settleDelay] in
            try? await Task.sleep(for: settleDelay)
            guard !Task.isCancelled else { return }
            self?.settle()
        }
    }

    private func clearStaleMuteAfterSwitch(to device: AudioDevice) {
        guard clearsStaleMuteOnSwitch, !globalMuteActive,
              selectedDevice?.id == device.id, selectedDevice?.isMuted == true
        else { return }
        do {
            try controller.setInputMute(false, for: device.id)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func settle() {
        refresh()
        repairUnusableDefaults()
        enforceInputPriority()
        enforceOutputPriority()
    }

    enum LockStatus: Equatable {
        case off
        case active
        case paused
    }

    var inputLockStatus: LockStatus {
        lockStatus(locks: locksInput, backoff: inputBackoff)
    }

    var outputLockStatus: LockStatus {
        lockStatus(locks: locksOutput, backoff: outputBackoff)
    }

    private func lockStatus(locks: Bool, backoff: ReassertBackoff) -> LockStatus {
        guard locks else { return .off }
        return backoff.isPaused(at: now()) ? .paused : .active
    }

    func priority(for direction: DeviceVolumePresets.Direction) -> [PriorityEntry] {
        direction == .input ? inputPriority : outputPriority
    }

    func isConnected(_ entry: PriorityEntry, direction: DeviceVolumePresets.Direction) -> Bool {
        let live = direction == .input ? devices : outputDevices
        return live.contains { $0.uid == entry.uid }
    }

    func addToPriority(_ device: AudioDevice, direction: DeviceVolumePresets.Direction) {
        addToPriority(PriorityEntry(uid: device.uid, name: device.name), direction: direction)
    }

    func addToPriority(_ entry: PriorityEntry, direction: DeviceVolumePresets.Direction) {
        var list = priority(for: direction)
        guard !list.contains(where: { $0.uid == entry.uid }) else { return }
        list.append(entry)
        setPriority(list, direction: direction)
    }

    func removeFromPriority(uid: String, direction: DeviceVolumePresets.Direction) {
        setPriority(priority(for: direction).filter { $0.uid != uid }, direction: direction)
    }

    func movePriority(from source: IndexSet, to destination: Int, direction: DeviceVolumePresets.Direction) {
        var list = priority(for: direction)
        let moving = source.sorted().map { list[$0] }
        let adjusted = destination - source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { list.remove(at: index) }
        list.insert(contentsOf: moving, at: min(max(adjusted, 0), list.count))
        setPriority(list, direction: direction)
    }

    private func setPriority(_ list: [PriorityEntry], direction: DeviceVolumePresets.Direction) {
        switch direction {
        case .input:
            inputPriority = list
            priorityPreferences.setEntries(list, for: .input)
            enforceInputPriority()
        case .output:
            outputPriority = list
            priorityPreferences.setEntries(list, for: .output)
            enforceOutputPriority()
        }
    }

    /// A pick made in EyeOh's own menu is the user's newest intent, so while a
    /// lock is on it becomes the top-ranked device instead of being undone.
    private func promoteManualPick(_ device: AudioDevice, direction: DeviceVolumePresets.Direction) {
        let locked = direction == .input ? locksInput : locksOutput
        guard locked else { return }
        let promoted = DevicePriorityResolver.promoting(
            PriorityEntry(uid: device.uid, name: device.name),
            in: priority(for: direction)
        )
        switch direction {
        case .input:
            inputPriority = promoted
            priorityPreferences.setEntries(promoted, for: .input)
        case .output:
            outputPriority = promoted
            priorityPreferences.setEntries(promoted, for: .output)
        }
    }

    private func enforceInputPriority() {
        guard locksInput,
              let preferred = DevicePriorityResolver.preferred(in: inputPriority, available: devices),
              DevicePriorityResolver.isHijacked(currentID: selectedDeviceID, preferred: preferred),
              inputBackoff.requestReassert(at: now())
        else { return }
        applyInput(preferred)
    }

    private func enforceOutputPriority() {
        guard locksOutput,
              let preferred = DevicePriorityResolver.preferred(in: outputPriority, available: outputDevices),
              DevicePriorityResolver.isHijacked(currentID: selectedOutputDeviceID, preferred: preferred),
              outputBackoff.requestReassert(at: now())
        else { return }
        applyOutput(preferred)
    }

    /// The system can leave a default pointing at a device that has no usable
    /// stream (an AirPods input that has not switched to the call profile yet, or
    /// one that has vanished). Re-point it at something that works, which is what
    /// toggling the device in System Settings does by hand.
    private func repairUnusableDefaults() {
        if !devices.isEmpty,
           !devices.contains(where: { $0.id == selectedDeviceID }),
           let target = DevicePriorityResolver.fallback(
               priority: locksInput ? inputPriority : [],
               available: devices,
               lastHealthyUID: lastHealthyInputUID
           ),
           inputBackoff.requestReassert(at: now()) {
            applyInput(target)
        }
        if !outputDevices.isEmpty,
           !outputDevices.contains(where: { $0.id == selectedOutputDeviceID }),
           let target = DevicePriorityResolver.fallback(
               priority: locksOutput ? outputPriority : [],
               available: outputDevices,
               lastHealthyUID: lastHealthyOutputUID
           ),
           outputBackoff.requestReassert(at: now()) {
            applyOutput(target)
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
            if let healthy = refreshedInputs.first(where: { $0.id == refreshedInputID }) {
                lastHealthyInputUID = healthy.uid
            }
            if let healthy = refreshedOutputs.first(where: { $0.id == refreshedOutputID }) {
                lastHealthyOutputUID = healthy.uid
            }
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
        promoteManualPick(device, direction: .input)
        applyInput(device)
    }

    private func applyInput(_ device: AudioDevice) {
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
            clearStaleMuteAfterSwitch(to: device)
            Diagnostics.record(.inputChanged)
            if let presetError {
                errorMessage = "Input switched, but its saved volume could not be restored: \(presetError.localizedDescription)"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectOutput(_ device: AudioDevice) {
        promoteManualPick(device, direction: .output)
        applyOutput(device)
    }

    private func applyOutput(_ device: AudioDevice) {
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
        // Device IDs change when a Bluetooth device reconnects, so remember the
        // UIDs and resolve them to current IDs only when restoring.
        let previousInputUID = devices.first { $0.id == selectedDeviceID }?.uid
        let previousOutputUID = outputDevices.first { $0.id == selectedOutputDeviceID }?.uid
        let previousSystemOutputUID = (try? controller.defaultSystemOutputDeviceID())
            .flatMap { id in outputDevices.first { $0.id == id }?.uid }
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
                    if let id = devices.first(where: { $0.uid == previousInputUID })?.id {
                        try? controller.setDefaultInputDevice(id)
                    }
                    if let id = outputDevices.first(where: { $0.uid == previousOutputUID })?.id {
                        try? controller.setDefaultOutputDevice(id)
                    }
                    if let id = outputDevices.first(where: { $0.uid == previousSystemOutputUID })?.id {
                        try? controller.setSystemOutputDevice(id)
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
