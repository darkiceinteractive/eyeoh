import Foundation

@MainActor
final class DeviceVolumePresets {
    enum Direction: String {
        case input
        case output
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func value(for uid: String, direction: Direction) -> Float32? {
        let key = key(for: uid, direction: direction)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Float32(defaults.double(forKey: key))
    }

    func setValue(_ value: Float32, for uid: String, direction: Direction) {
        defaults.set(Double(min(max(value, 0), 1)), forKey: key(for: uid, direction: direction))
    }

    private func key(for uid: String, direction: Direction) -> String {
        "device-volume.\(direction.rawValue).\(uid)"
    }
}
