import Foundation

struct SavedCamera: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let modelID: String?

    init(id: String, name: String, modelID: String?) {
        self.id = id
        self.name = name
        self.modelID = modelID
    }

    init(_ camera: CameraDevice) {
        self.init(id: camera.id, name: camera.name, modelID: camera.modelID)
    }
}

/// Stores the camera the user picked, because macOS resets `userPreferredCamera`
/// after reboot and may override it when a Continuity Camera appears.
final class CameraPersistence {
    private enum Key {
        static let savedCamera = "camera.saved"
        static let holdEnabled = "camera.holdSelection"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedCamera: SavedCamera? {
        get {
            defaults.data(forKey: Key.savedCamera)
                .flatMap { try? JSONDecoder().decode(SavedCamera.self, from: $0) }
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.savedCamera)
            } else {
                defaults.removeObject(forKey: Key.savedCamera)
            }
        }
    }

    /// On unless the user has turned it off. It only has an effect once a camera is saved.
    var holdsSelection: Bool {
        get { defaults.object(forKey: Key.holdEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.holdEnabled) }
    }
}

enum CameraMatcher {
    /// Exact `uniqueID` first. If it is gone (some devices get a new ID when moved to
    /// another port), accept a single available camera with the same model and name,
    /// then a single one with the same name. Ambiguous matches are rejected so two
    /// identical webcams are never confused.
    static func match(_ saved: SavedCamera, in available: [CameraDevice]) -> CameraDevice? {
        if let exact = available.first(where: { $0.id == saved.id }) {
            return exact
        }
        if let modelID = saved.modelID, !modelID.isEmpty {
            let sameModel = available.filter { $0.modelID == modelID && $0.name == saved.name }
            if sameModel.count == 1 { return sameModel[0] }
        }
        let sameName = available.filter { $0.name == saved.name }
        return sameName.count == 1 ? sameName[0] : nil
    }
}

enum CameraHoldPolicy {
    /// The camera to re-apply, or nil when nothing should change: hold is off, no
    /// camera is saved, the saved camera is not connected, or macOS already agrees.
    static func cameraToApply(
        saved: SavedCamera?,
        holdEnabled: Bool,
        available: [CameraDevice],
        userPreferredID: String?,
        systemPreferredID: String?
    ) -> CameraDevice? {
        guard holdEnabled, let saved, let target = CameraMatcher.match(saved, in: available) else {
            return nil
        }
        let userAgrees = userPreferredID == target.id
        let systemAgrees = systemPreferredID == nil || systemPreferredID == target.id
        return userAgrees && systemAgrees ? nil : target
    }
}

/// Caps re-applies so EyeOh never fights another app that keeps changing the preference.
struct CameraApplyRateLimiter {
    let maxApplies: Int
    let window: TimeInterval
    private var applies: [Date] = []

    init(maxApplies: Int = 3, window: TimeInterval = 30) {
        self.maxApplies = maxApplies
        self.window = window
    }

    mutating func allow(at now: Date) -> Bool {
        applies.removeAll { now.timeIntervalSince($0) >= window }
        guard applies.count < maxApplies else { return false }
        applies.append(now)
        return true
    }
}
