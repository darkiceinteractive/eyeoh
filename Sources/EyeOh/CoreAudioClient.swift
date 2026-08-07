import AudioToolbox
import CoreAudio
import Foundation

struct CoreAudioClient: AudioDeviceControlling {
    func inputDevices() throws -> [AudioDevice] {
        try devices(scope: kAudioDevicePropertyScopeInput)
    }

    func outputDevices() throws -> [AudioDevice] {
        try devices(scope: kAudioDevicePropertyScopeOutput)
    }

    func defaultInputDeviceID() throws -> AudioDeviceID {
        try defaultDeviceID(
            selector: kAudioHardwarePropertyDefaultInputDevice,
            operation: "read the default input device"
        )
    }

    func defaultOutputDeviceID() throws -> AudioDeviceID {
        try defaultDeviceID(
            selector: kAudioHardwarePropertyDefaultOutputDevice,
            operation: "read the default output device"
        )
    }

    func defaultSystemOutputDeviceID() throws -> AudioDeviceID {
        try defaultDeviceID(
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            operation: "read the system sound output device"
        )
    }

    func setDefaultInputDevice(_ id: AudioDeviceID) throws {
        try setDefaultDevice(
            id,
            selector: kAudioHardwarePropertyDefaultInputDevice,
            operation: "change the default input device"
        )
    }

    func setDefaultOutputDevice(_ id: AudioDeviceID) throws {
        let previousDefault = try defaultOutputDeviceID()
        let previousSystemDefault = try defaultSystemOutputDeviceID()
        do {
            try setDefaultDevice(
                id,
                selector: kAudioHardwarePropertyDefaultOutputDevice,
                operation: "change the default output device"
            )
            try setDefaultDevice(
                id,
                selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                operation: "change the system sound output device"
            )
        } catch {
            try? setDefaultDevice(
                previousDefault,
                selector: kAudioHardwarePropertyDefaultOutputDevice,
                operation: "restore the default output device"
            )
            try? setSystemOutputDevice(previousSystemDefault)
            throw error
        }
    }

    func setSystemOutputDevice(_ id: AudioDeviceID) throws {
        try setDefaultDevice(
            id,
            selector: kAudioHardwarePropertyDefaultSystemOutputDevice,
            operation: "change the system sound output device"
        )
    }

    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        try setVolume(scalar, for: id, scope: kAudioDevicePropertyScopeInput)
    }

    func setOutputVolume(_ scalar: Float32, for id: AudioDeviceID) throws {
        try setVolume(scalar, for: id, scope: kAudioDevicePropertyScopeOutput)
    }

    func deviceChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let registration = CoreAudioListenerRegistration(continuation: continuation)
            continuation.onTermination = { _ in
                registration.cancel()
            }
        }
    }

    private func devices(scope: AudioObjectPropertyScope) throws -> [AudioDevice] {
        let ids = try allDeviceIDs()
        let available = ids.compactMap { id -> AudioDevice? in
            // A device can disappear between enumeration and property reads.
            // Skip only that device instead of discarding the entire menu.
            guard isAlive(id),
                  !isHidden(id),
                  canBeDefaultDevice(id, scope: scope),
                  let channelCount = try? channelCount(for: id, scope: scope),
                  channelCount > 0,
                  let uid = try? stringProperty(kAudioDevicePropertyDeviceUID, for: id),
                  let name = try? stringProperty(kAudioObjectPropertyName, for: id)
            else {
                return nil
            }

            let volume = volumeState(for: id, scope: scope, channelCount: channelCount)
            return AudioDevice(
                id: id,
                uid: uid,
                name: name,
                transport: transport(for: id),
                channelCount: channelCount,
                volume: volume?.scalar,
                isVolumeSettable: volume?.isSettable ?? false
            )
        }

        return available
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func defaultDeviceID(
        selector: AudioObjectPropertySelector,
        operation: String
    ) throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &id
        )
        try check(status, operation: operation)
        return id
    }

    private func setDefaultDevice(
        _ id: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        operation: String
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableID = id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableID
        )
        try check(status, operation: operation)
    }

    private func allDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        )
        try check(status, operation: "count audio devices")

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = Array(repeating: AudioDeviceID(0), count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &ids
        )
        try check(status, operation: "list audio devices")
        return ids
    }

    private func channelCount(
        for id: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size)
        try check(status, operation: "inspect audio channels")

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }

        status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, storage)
        try check(status, operation: "read audio channels")

        let list = storage.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) { count, buffer in
            count + buffer.mNumberChannels
        }
    }

    private func isAlive(_ id: AudioDeviceID) -> Bool {
        (uint32Property(kAudioDevicePropertyDeviceIsAlive, for: id) ?? 0) != 0
    }

    private func isHidden(_ id: AudioDeviceID) -> Bool {
        (uint32Property(kAudioDevicePropertyIsHidden, for: id) ?? 0) != 0
    }

    private func canBeDefaultDevice(
        _ id: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr
            && value != 0
    }

    private func volumeState(
        for id: AudioDeviceID,
        scope: AudioObjectPropertyScope,
        channelCount: UInt32
    ) -> (scalar: Float32, isSettable: Bool)? {
        let elements = [kAudioObjectPropertyElementMain]
            + Array(1...max(channelCount, 1))

        var values: [Float32] = []
        var hasSettableProperty = false
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &address) else { continue }

            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
                continue
            }

            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(id, &address, &settable) == noErr {
                hasSettableProperty = hasSettableProperty || settable.boolValue
            }
            values.append(value)

            // A master value is authoritative; do not average it with channels.
            if element == kAudioObjectPropertyElementMain {
                return (value, hasSettableProperty)
            }
        }

        guard !values.isEmpty else { return nil }
        return (values.reduce(0, +) / Float32(values.count), hasSettableProperty)
    }

    private func setVolume(
        _ scalar: Float32,
        for id: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) throws {
        let count = try channelCount(for: id, scope: scope)
        let elements = [kAudioObjectPropertyElementMain]
            + Array(1...max(count, 1))
        var changed = false
        var value = min(max(scalar, 0), 1)

        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &address) else { continue }
            var settable: DarwinBoolean = false
            guard AudioObjectIsPropertySettable(id, &address, &settable) == noErr,
                  settable.boolValue
            else { continue }

            let status = AudioObjectSetPropertyData(
                id,
                &address,
                0,
                nil,
                UInt32(MemoryLayout<Float32>.size),
                &value
            )
            try check(status, operation: "change the audio device volume")
            changed = true

            // A writable master controls all channels.
            if element == kAudioObjectPropertyElementMain { break }
        }

        guard changed else {
            throw CoreAudioError(operation: "change the audio device volume", status: kAudioHardwareUnsupportedOperationError)
        }
    }

    private func uint32Property(
        _ selector: AudioObjectPropertySelector,
        for id: AudioDeviceID
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private func stringProperty(
        _ selector: AudioObjectPropertySelector,
        for id: AudioDeviceID
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        try check(status, operation: "read an audio device property")
        return value as String
    }

    private func transport(for id: AudioDeviceID) -> AudioDeviceTransport {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return .unknown
        }

        switch value {
        case kAudioDeviceTransportTypeAirPlay:
            return .airPlay
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return .bluetooth
        case kAudioDeviceTransportTypeBuiltIn:
            return .builtIn
        case kAudioDeviceTransportTypeDisplayPort:
            return .displayPort
        case kAudioDeviceTransportTypeHDMI:
            return .hdmi
        case kAudioDeviceTransportTypePCI:
            return .pci
        case kAudioDeviceTransportTypeThunderbolt:
            return .thunderbolt
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeVirtual:
            return .virtual
        case kAudioDeviceTransportTypeAggregate:
            return .aggregate
        default:
            return .unknown
        }
    }

    private func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw CoreAudioError(operation: operation, status: status)
        }
    }
}

private final class CoreAudioListenerRegistration: @unchecked Sendable {
    private let systemObject = AudioObjectID(kAudioObjectSystemObject)
    private let queue = DispatchQueue(label: "au.com.darkice.eyeoh.core-audio-events")
    private let listener: AudioObjectPropertyListenerBlock
    private var addresses: [AudioObjectPropertyAddress] = []

    init(continuation: AsyncStream<Void>.Continuation) {
        listener = { _, _ in
            continuation.yield()
        }

        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultSystemOutputDevice,
        ]

        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectAddPropertyListenerBlock(
                systemObject,
                &address,
                queue,
                listener
            ) == noErr {
                addresses.append(address)
            }
        }
    }

    func cancel() {
        for var address in addresses {
            AudioObjectRemovePropertyListenerBlock(systemObject, &address, queue, listener)
        }
        addresses.removeAll()
    }

    deinit {
        cancel()
    }
}

struct CoreAudioError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? {
        "Could not \(operation) (Core Audio error \(status))."
    }
}
