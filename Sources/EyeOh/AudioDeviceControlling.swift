import AudioToolbox

protocol AudioDeviceControlling: Sendable {
    func inputDevices() throws -> [AudioDevice]
    func outputDevices() throws -> [AudioDevice]
    func defaultInputDeviceID() throws -> AudioDeviceID
    func defaultOutputDeviceID() throws -> AudioDeviceID
    func defaultSystemOutputDeviceID() throws -> AudioDeviceID
    func setDefaultInputDevice(_ id: AudioDeviceID) throws
    func setDefaultOutputDevice(_ id: AudioDeviceID) throws
    func setSystemOutputDevice(_ id: AudioDeviceID) throws
    func setInputVolume(_ scalar: Float32, for id: AudioDeviceID) throws
    func setOutputVolume(_ scalar: Float32, for id: AudioDeviceID) throws
    func setInputMute(_ muted: Bool, for id: AudioDeviceID) throws
    func deviceChanges() -> AsyncStream<Void>
}

extension AudioDeviceControlling {
    func setInputMute(_ muted: Bool, for id: AudioDeviceID) throws {}

    func deviceChanges() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }

    func defaultSystemOutputDeviceID() throws -> AudioDeviceID {
        try defaultOutputDeviceID()
    }

    func setSystemOutputDevice(_ id: AudioDeviceID) throws {
        try setDefaultOutputDevice(id)
    }
}
