import AudioToolbox
import CoreAudio
import Foundation
import Observation

enum MicMuteMethod: Equatable, Sendable {
    case muteProperty
    case volumeScalar
}

protocol MicMuteControlling: Sendable {
    func defaultInputDeviceID() throws -> AudioDeviceID
    func uid(for id: AudioDeviceID) -> String?
    func deviceID(forUID uid: String) -> AudioDeviceID?
    func muteMethod(for id: AudioDeviceID) -> MicMuteMethod?
    func isMuted(_ id: AudioDeviceID) -> Bool?
    func setMuted(_ muted: Bool, for id: AudioDeviceID) throws
    func inputVolume(for id: AudioDeviceID) -> Float32?
    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws
    func inputChanges() -> AsyncStream<Void>
}

/// System-wide microphone mute for the current default input.
///
/// EyeOh only ever undoes its own changes, tracked per device UID: the method used
/// (mute flag, or volume 0 plus the previous level) and whether the device was already
/// muted before EyeOh acted. `isMuted` means "EyeOh muted it"; `isDeviceMuted` means
/// "the default input is muted by anyone", so the UI can tell them apart.
///
/// Policy: EyeOh's mute follows the default input. If the default input changes while
/// EyeOh has muted, its own change on the old device is undone and the new device is
/// muted. If the new device cannot be muted, EyeOh stops muting and says so. An
/// explicit unmute undoes only EyeOh's change; a mute set by another app is cleared
/// only through `forceUnmute()`. EyeOh undoes its own mute on quit.
@MainActor
@Observable
final class MicMuteController {
    private struct Applied: Equatable {
        let uid: String
        let method: MicMuteMethod
        let restoreVolume: Float32?
        let wasAlreadyMuted: Bool
    }

    private let client: any MicMuteControlling
    private var applied: Applied?
    private var monitorTask: Task<Void, Never>?

    private(set) var isMuted = false
    private(set) var isDeviceMuted = false
    private(set) var isSupported = true
    private(set) var errorMessage: String?

    /// Single source of truth for "EyeOh's global mute is active" (observable).
    /// Excludes mutes set by other apps; see `isDeviceMuted` / `isSilenced`.
    var isGlobalMuteActive: Bool { isMuted }

    /// True when the default input is silenced, whoever did it.
    var isSilenced: Bool { isMuted || isDeviceMuted }

    init(client: any MicMuteControlling) {
        self.client = client
        refresh()
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        let changes = client.inputChanges()
        monitorTask = Task { [weak self] in
            for await _ in changes {
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    func toggle() {
        if isMuted {
            unmute()
        } else if isDeviceMuted {
            forceUnmute()
        } else {
            mute()
        }
    }

    func mute() {
        guard !isMuted else { return }
        guard let id = try? client.defaultInputDeviceID() else {
            errorMessage = "No input device to mute."
            return
        }
        apply(to: id)
    }

    /// Undoes only what EyeOh changed. A device that was already muted stays muted.
    func unmute() {
        guard let current = applied else {
            isMuted = false
            return
        }
        do {
            try restore(current)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't unmute the microphone: \(error.localizedDescription)"
        }
        applied = nil
        isMuted = false
        refreshDeviceState()
    }

    /// Clears a mute that something else set. Only for an explicit user request.
    func forceUnmute() {
        if isMuted { unmute() }
        guard let id = try? client.defaultInputDeviceID() else { return }
        do {
            switch client.muteMethod(for: id) {
            case .muteProperty:
                try client.setMuted(false, for: id)
            case .volumeScalar:
                if (client.inputVolume(for: id) ?? 1) < 0.001 { try client.setInputVolume(1, for: id) }
            case nil:
                break
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't unmute the microphone: \(error.localizedDescription)"
        }
        refreshDeviceState()
    }

    func restoreOnQuit() {
        if isMuted { unmute() }
    }

    func refresh() {
        guard let id = try? client.defaultInputDeviceID() else {
            isSupported = false
            isDeviceMuted = false
            return
        }

        if let current = applied {
            if current.uid != client.uid(for: id) {
                transfer(from: current, to: id)
            } else if wasChangedExternally(current, id: id) {
                applied = nil
                isMuted = false
            }
        }
        isSupported = client.muteMethod(for: id) != nil
        refreshDeviceState()
    }

    private func refreshDeviceState() {
        guard let id = try? client.defaultInputDeviceID() else {
            isDeviceMuted = false
            return
        }
        switch client.muteMethod(for: id) {
        case .muteProperty:
            isDeviceMuted = client.isMuted(id) == true
        case .volumeScalar:
            isDeviceMuted = (client.inputVolume(for: id) ?? 1) < 0.001
        case nil:
            isDeviceMuted = false
        }
    }

    private func apply(to id: AudioDeviceID) {
        guard let method = client.muteMethod(for: id), let uid = client.uid(for: id) else {
            isSupported = false
            errorMessage = "This input device doesn't support muting from EyeOh."
            return
        }
        do {
            switch method {
            case .muteProperty:
                let already = client.isMuted(id) == true
                if !already { try client.setMuted(true, for: id) }
                applied = Applied(uid: uid, method: method, restoreVolume: nil, wasAlreadyMuted: already)
            case .volumeScalar:
                let previous = client.inputVolume(for: id) ?? 1
                let already = previous < 0.001
                if !already { try client.setInputVolume(0, for: id) }
                applied = Applied(uid: uid, method: method, restoreVolume: previous, wasAlreadyMuted: already)
            }
            isMuted = true
            isSupported = true
            errorMessage = nil
            refreshDeviceState()
        } catch {
            errorMessage = "Couldn't mute the microphone: \(error.localizedDescription)"
        }
    }

    private func transfer(from old: Applied, to id: AudioDeviceID) {
        try? restore(old)
        applied = nil
        isMuted = false
        guard client.muteMethod(for: id) != nil else {
            errorMessage = "Microphone unmuted: the new input device can't be muted from EyeOh."
            return
        }
        apply(to: id)
    }

    private func restore(_ state: Applied) throws {
        guard !state.wasAlreadyMuted, let id = client.deviceID(forUID: state.uid) else { return }
        switch state.method {
        case .muteProperty:
            guard client.isMuted(id) == true else { return }
            try client.setMuted(false, for: id)
        case .volumeScalar:
            // Only restore while the level is still the 0 EyeOh set.
            guard (client.inputVolume(for: id) ?? 1) < 0.001 else { return }
            try client.setInputVolume(state.restoreVolume ?? 1, for: id)
        }
    }

    private func wasChangedExternally(_ state: Applied, id: AudioDeviceID) -> Bool {
        guard !state.wasAlreadyMuted else { return false }
        switch state.method {
        case .muteProperty:
            return client.isMuted(id) == false
        case .volumeScalar:
            return (client.inputVolume(for: id) ?? 0) > 0.001
        }
    }
}

struct CoreAudioMicMuteClient: MicMuteControlling {
    func defaultInputDeviceID() throws -> AudioDeviceID {
        try CoreAudioClient().defaultInputDeviceID()
    }

    func uid(for id: AudioDeviceID) -> String? {
        inputDevice(id)?.uid
    }

    func deviceID(forUID uid: String) -> AudioDeviceID? {
        (try? CoreAudioClient().inputDevices())?.first { $0.uid == uid }?.id
    }

    func muteMethod(for id: AudioDeviceID) -> MicMuteMethod? {
        if !settableMuteElements(for: id).isEmpty { return .muteProperty }
        if let device = inputDevice(id), device.isVolumeSettable, device.volume != nil {
            return .volumeScalar
        }
        return nil
    }

    func isMuted(_ id: AudioDeviceID) -> Bool? {
        for element in settableMuteElements(for: id) {
            var address = muteAddress(element)
            var value: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr {
                return value != 0
            }
        }
        return nil
    }

    func setMuted(_ muted: Bool, for id: AudioDeviceID) throws {
        let elements = settableMuteElements(for: id)
        guard !elements.isEmpty else {
            throw CoreAudioError(
                operation: "mute the audio input",
                status: kAudioHardwareUnsupportedOperationError
            )
        }
        for element in elements {
            var address = muteAddress(element)
            var value: UInt32 = muted ? 1 : 0
            let status = AudioObjectSetPropertyData(
                id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
            )
            guard status == noErr else {
                throw CoreAudioError(operation: "mute the audio input", status: status)
            }
        }
    }

    func inputVolume(for id: AudioDeviceID) -> Float32? {
        inputDevice(id)?.volume
    }

    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        try CoreAudioClient().setInputVolume(scalar, for: id)
    }

    func inputChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let registration = DefaultInputListener(continuation: continuation)
            continuation.onTermination = { _ in registration.cancel() }
        }
    }

    private func inputDevice(_ id: AudioDeviceID) -> AudioDevice? {
        (try? CoreAudioClient().inputDevices())?.first { $0.id == id }
    }

    private func muteAddress(_ element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: element
        )
    }

    /// A settable master mute wins; otherwise every settable channel mute is used.
    private func settableMuteElements(for id: AudioDeviceID) -> [AudioObjectPropertyElement] {
        var result: [AudioObjectPropertyElement] = []
        for element in [kAudioObjectPropertyElementMain] + Array(1...8) {
            var address = muteAddress(element)
            guard AudioObjectHasProperty(id, &address) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr,
                  settable.boolValue
            else { continue }
            if element == kAudioObjectPropertyElementMain { return [element] }
            result.append(element)
        }
        return result
    }
}

private final class DefaultInputListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "au.com.darkice.eyeoh.mic-mute-events")
    private let listener: AudioObjectPropertyListenerBlock
    private var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    private var isRegistered = false

    init(continuation: AsyncStream<Void>.Continuation) {
        listener = { _, _ in continuation.yield() }
        isRegistered = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, listener
        ) == noErr
    }

    func cancel() {
        guard isRegistered else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, listener
        )
        isRegistered = false
    }

    deinit { cancel() }
}
