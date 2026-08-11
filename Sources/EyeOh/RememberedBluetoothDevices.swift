import Foundation

struct RememberedBluetoothAudioDevice: Codable, Equatable, Identifiable, Sendable {
    var id: String { address }

    let address: String
    var name: String
    var inputUID: String?
    var outputUID: String?
}

final class RememberedBluetoothDevices {
    private static let devicesKey = "bluetooth.rememberedAudioDevices"
    private static let showsDisconnectedKey = "bluetooth.showsDisconnectedAudioDevices"

    private let defaults: UserDefaults
    private var devicesByAddress: [String: RememberedBluetoothAudioDevice]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.devicesKey),
           let decoded = try? JSONDecoder().decode([RememberedBluetoothAudioDevice].self, from: data) {
            devicesByAddress = Dictionary(uniqueKeysWithValues: decoded.map { ($0.address, $0) })
        } else {
            devicesByAddress = [:]
        }
    }

    var devices: [RememberedBluetoothAudioDevice] {
        devicesByAddress.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var showsDisconnectedDevices: Bool {
        get {
            guard defaults.object(forKey: Self.showsDisconnectedKey) != nil else { return true }
            return defaults.bool(forKey: Self.showsDisconnectedKey)
        }
        set {
            defaults.set(newValue, forKey: Self.showsDisconnectedKey)
        }
    }

    func remember(_ device: AudioDevice, direction: DeviceVolumePresets.Direction) {
        guard device.transport == .bluetooth,
              let address = Self.bluetoothAddress(from: device.uid)
        else { return }

        var remembered = devicesByAddress[address] ?? RememberedBluetoothAudioDevice(
            address: address,
            name: device.name,
            inputUID: nil,
            outputUID: nil
        )
        remembered.name = device.name
        switch direction {
        case .input:
            remembered.inputUID = device.uid
        case .output:
            remembered.outputUID = device.uid
        }
        devicesByAddress[address] = remembered
        persist()
    }

    func removeAll() {
        devicesByAddress.removeAll()
        defaults.removeObject(forKey: Self.devicesKey)
    }

    static func bluetoothAddress(from coreAudioUID: String) -> String? {
        let pattern = #"(?i)([0-9a-f]{2}[-:]){5}[0-9a-f]{2}"#
        guard let range = coreAudioUID.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return coreAudioUID[range]
            .replacingOccurrences(of: ":", with: "-")
            .uppercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: Self.devicesKey)
    }
}
