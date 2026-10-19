import AudioToolbox
import Foundation

struct PriorityEntry: Codable, Equatable, Identifiable, Sendable {
    var id: String { uid }

    let uid: String
    var name: String
}

enum DevicePriorityResolver {
    /// The highest-ranked priority entry that is currently available.
    static func preferred(in priority: [PriorityEntry], available: [AudioDevice]) -> AudioDevice? {
        for entry in priority {
            if let device = available.first(where: { $0.uid == entry.uid }) {
                return device
            }
        }
        return nil
    }

    /// True when the system default differs from the device the priority list wants.
    static func isHijacked(currentID: AudioDeviceID?, preferred: AudioDevice?) -> Bool {
        guard let preferred else { return false }
        return currentID != preferred.id
    }

    /// Where to send audio when the current default no longer has a usable stream.
    static func fallback(
        priority: [PriorityEntry],
        available: [AudioDevice],
        lastHealthyUID: String?
    ) -> AudioDevice? {
        if let ranked = preferred(in: priority, available: available) { return ranked }
        if let lastHealthyUID, let device = available.first(where: { $0.uid == lastHealthyUID }) {
            return device
        }
        return available.first { $0.transport == .builtIn } ?? available.first
    }

    static func promoting(_ entry: PriorityEntry, in priority: [PriorityEntry]) -> [PriorityEntry] {
        [entry] + priority.filter { $0.uid != entry.uid }
    }
}

/// Rate-limits automatic re-asserts so EyeOh never fights another app (or macOS)
/// that keeps changing the default. After `maxReasserts` within `window`, the
/// lock pauses for `pauseDuration`.
struct ReassertBackoff: Equatable, Sendable {
    var maxReasserts = 3
    var window: TimeInterval = 15
    var pauseDuration: TimeInterval = 60
    private(set) var timestamps: [Date] = []
    private(set) var pausedUntil: Date?

    func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return now < pausedUntil
    }

    mutating func requestReassert(at now: Date) -> Bool {
        if let until = pausedUntil {
            if now < until { return false }
            pausedUntil = nil
            timestamps = []
        }
        timestamps.removeAll { now.timeIntervalSince($0) > window }
        if timestamps.count >= maxReasserts {
            pausedUntil = now.addingTimeInterval(pauseDuration)
            timestamps = []
            return false
        }
        timestamps.append(now)
        return true
    }
}

@MainActor
final class DevicePriorityPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func entries(for direction: DeviceVolumePresets.Direction) -> [PriorityEntry] {
        guard let data = defaults.data(forKey: listKey(direction)),
              let decoded = try? JSONDecoder().decode([PriorityEntry].self, from: data)
        else { return [] }
        return decoded
    }

    func setEntries(_ entries: [PriorityEntry], for direction: DeviceVolumePresets.Direction) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: listKey(direction))
    }

    func locks(_ direction: DeviceVolumePresets.Direction) -> Bool {
        defaults.bool(forKey: lockKey(direction))
    }

    func setLocks(_ value: Bool, for direction: DeviceVolumePresets.Direction) {
        defaults.set(value, forKey: lockKey(direction))
    }

    var clearsStaleMuteOnSwitch: Bool {
        get { defaults.bool(forKey: "input.clearStaleMuteOnSwitch") }
        set { defaults.set(newValue, forKey: "input.clearStaleMuteOnSwitch") }
    }

    private func listKey(_ direction: DeviceVolumePresets.Direction) -> String {
        "priority.\(direction.rawValue).list"
    }

    private func lockKey(_ direction: DeviceVolumePresets.Direction) -> String {
        "priority.\(direction.rawValue).lock"
    }
}
