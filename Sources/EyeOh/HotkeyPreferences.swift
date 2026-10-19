import AudioToolbox
import Carbon.HIToolbox
import Foundation
import Observation

enum HotkeyAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case toggleMicMute
    case nextInput
    case nextOutput
    case openMenu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleMicMute: "Mute / unmute microphone"
        case .nextInput: "Switch to next input"
        case .nextOutput: "Switch to next output"
        case .openMenu: "Open EyeOh menu"
        }
    }

    var preferenceKey: String { "hotkeys.\(rawValue)" }
}

/// A Carbon virtual key code plus Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey).
struct HotkeyBinding: Codable, Equatable, Hashable, Sendable {
    static let modifierMask = UInt32(cmdKey | shiftKey | optionKey | controlKey)

    let keyCode: UInt32
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Self.modifierMask
    }

    /// Global shortcuts need Command, Control or Option so ordinary typing is never captured.
    var isValid: Bool {
        modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
    }

    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + Self.keyName(keyCode)
    }

    private static let keyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
        kVK_ANSI_RightBracket: "]", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'",
        kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11",
        kVK_F12: "F12",
    ]

    private static func keyName(_ code: UInt32) -> String {
        keyNames[Int(code)] ?? "Key \(code)"
    }
}

enum HotkeyAssignmentResult: Equatable {
    case assigned
    case invalid
    case conflict(HotkeyAction)
}

/// Shortcuts are all unset by default and persist as JSON per action in UserDefaults.
@MainActor
@Observable
final class HotkeyPreferences {
    private let defaults: UserDefaults
    private(set) var bindings: [HotkeyAction: HotkeyBinding] = [:]
    @ObservationIgnored var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        for action in HotkeyAction.allCases {
            guard let data = defaults.data(forKey: action.preferenceKey),
                  let binding = try? JSONDecoder().decode(HotkeyBinding.self, from: data),
                  binding.isValid,
                  !bindings.values.contains(binding)
            else { continue }
            bindings[action] = binding
        }
    }

    func binding(for action: HotkeyAction) -> HotkeyBinding? {
        bindings[action]
    }

    @discardableResult
    func set(_ binding: HotkeyBinding?, for action: HotkeyAction) -> HotkeyAssignmentResult {
        guard let binding else {
            bindings[action] = nil
            defaults.removeObject(forKey: action.preferenceKey)
            onChange?()
            return .assigned
        }
        guard binding.isValid else { return .invalid }
        if let other = bindings.first(where: { $0.key != action && $0.value == binding })?.key {
            return .conflict(other)
        }
        guard let data = try? JSONEncoder().encode(binding) else { return .invalid }
        bindings[action] = binding
        defaults.set(data, forKey: action.preferenceKey)
        onChange?()
        return .assigned
    }
}

enum DeviceCycler {
    /// Next device after `currentID` in list order, wrapping around. Nil when there is nothing to switch to.
    static func next(in devices: [AudioDevice], after currentID: AudioDeviceID?) -> AudioDevice? {
        guard !devices.isEmpty else { return nil }
        guard let currentID, let index = devices.firstIndex(where: { $0.id == currentID }) else {
            return devices.first
        }
        guard devices.count > 1 else { return nil }
        return devices[(index + 1) % devices.count]
    }
}
