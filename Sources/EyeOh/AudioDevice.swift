import AudioToolbox

struct AudioDevice: Identifiable, Equatable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: AudioDeviceTransport
    let channelCount: UInt32
    let volume: Float32?
    let isVolumeSettable: Bool

    init(
        id: AudioDeviceID,
        uid: String,
        name: String,
        transport: AudioDeviceTransport,
        channelCount: UInt32,
        volume: Float32? = nil,
        isVolumeSettable: Bool = false
    ) {
        self.id = id
        self.uid = uid
        self.name = name
        self.transport = transport
        self.channelCount = channelCount
        self.volume = volume
        self.isVolumeSettable = isVolumeSettable
    }
}

enum AudioDeviceTransport: String, Sendable {
    case airPlay = "AirPlay"
    case bluetooth = "Bluetooth"
    case builtIn = "Built-in"
    case displayPort = "DisplayPort"
    case hdmi = "HDMI"
    case pci = "PCI"
    case thunderbolt = "Thunderbolt"
    case usb = "USB"
    case virtual = "Virtual"
    case aggregate = "Aggregate"
    case unknown = "Audio device"

    var systemImage: String {
        switch self {
        case .airPlay:
            "airplayaudio"
        case .bluetooth:
            "wave.3.right"
        case .builtIn:
            "laptopcomputer"
        case .displayPort, .hdmi:
            "display"
        case .pci, .thunderbolt, .usb:
            "cable.connector"
        case .virtual, .aggregate:
            "waveform"
        case .unknown:
            "mic"
        }
    }
}
