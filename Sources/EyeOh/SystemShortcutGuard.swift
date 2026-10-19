import Carbon.HIToolbox
import Foundation

/// Detects shortcuts that macOS itself owns, so EyeOh never registers one that would
/// shadow a system or standard app shortcut. Combines a fixed list of reserved combos
/// with the user's enabled entries from `com.apple.symbolichotkeys` where readable.
struct SystemShortcutGuard: Sendable {
    private static let cmd = UInt32(cmdKey)
    private static let ctrl = UInt32(controlKey)
    private static let opt = UInt32(optionKey)
    private static let shift = UInt32(shiftKey)

    private static let reserved: [(HotkeyBinding, String)] = [
        (HotkeyBinding(keyCode: UInt32(kVK_Space), modifiers: cmd), "Spotlight"),
        (HotkeyBinding(keyCode: UInt32(kVK_Space), modifiers: cmd | opt), "Finder search"),
        (HotkeyBinding(keyCode: UInt32(kVK_Space), modifiers: ctrl), "input source switching"),
        (HotkeyBinding(keyCode: UInt32(kVK_Tab), modifiers: cmd), "the app switcher"),
        (HotkeyBinding(keyCode: UInt32(kVK_Tab), modifiers: cmd | shift), "the app switcher"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_Grave), modifiers: cmd), "window switching"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_Q), modifiers: cmd), "Quit"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_W), modifiers: cmd), "Close Window"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_H), modifiers: cmd), "Hide"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_H), modifiers: cmd | opt), "Hide Others"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_M), modifiers: cmd), "Minimize"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_C), modifiers: cmd), "Copy"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_V), modifiers: cmd), "Paste"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_X), modifiers: cmd), "Cut"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_Z), modifiers: cmd), "Undo"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_A), modifiers: cmd), "Select All"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_S), modifiers: cmd), "Save"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_Comma), modifiers: cmd), "Settings"),
        (HotkeyBinding(keyCode: UInt32(kVK_UpArrow), modifiers: ctrl), "Mission Control"),
        (HotkeyBinding(keyCode: UInt32(kVK_DownArrow), modifiers: ctrl), "App Exposé"),
        (HotkeyBinding(keyCode: UInt32(kVK_LeftArrow), modifiers: ctrl), "switching Spaces"),
        (HotkeyBinding(keyCode: UInt32(kVK_RightArrow), modifiers: ctrl), "switching Spaces"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_3), modifiers: cmd | shift), "screenshots"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_4), modifiers: cmd | shift), "screenshots"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_5), modifiers: cmd | shift), "screenshots"),
        (HotkeyBinding(keyCode: UInt32(kVK_ANSI_Q), modifiers: cmd | ctrl), "Lock Screen"),
        (HotkeyBinding(keyCode: UInt32(kVK_Escape), modifiers: cmd | opt), "Force Quit"),
    ]

    private let systemBindings: [(HotkeyBinding, String)]

    init(systemBindings: [(HotkeyBinding, String)] = SystemShortcutGuard.readSymbolicHotKeys()) {
        self.systemBindings = systemBindings
    }

    /// A short phrase naming what the shortcut is used for, or nil when it is free.
    func conflict(for binding: HotkeyBinding) -> String? {
        if let match = Self.reserved.first(where: { $0.0 == binding }) { return match.1 }
        return systemBindings.first(where: { $0.0 == binding })?.1
    }

    /// Enabled entries of `com.apple.symbolichotkeys` with a real key. Unreadable
    /// preferences (for example under the sandbox) simply yield no entries.
    static func readSymbolicHotKeys() -> [(HotkeyBinding, String)] {
        let raw = CFPreferencesCopyAppValue(
            "AppleSymbolicHotKeys" as CFString,
            "com.apple.symbolichotkeys" as CFString
        )
        guard let all = raw as? [String: Any] else { return [] }
        var result: [(HotkeyBinding, String)] = []
        for (_, value) in all {
            guard let entry = value as? [String: Any],
                  (entry["enabled"] as? NSNumber)?.boolValue == true,
                  let detail = entry["value"] as? [String: Any],
                  let parameters = detail["parameters"] as? [Any], parameters.count >= 3,
                  let keyCode = (parameters[1] as? NSNumber)?.uint32Value, keyCode != 65535,
                  let flags = (parameters[2] as? NSNumber)?.uint32Value
            else { continue }
            var modifiers: UInt32 = 0
            if flags & 0x100000 != 0 { modifiers |= cmd }
            if flags & 0x20000 != 0 { modifiers |= shift }
            if flags & 0x80000 != 0 { modifiers |= opt }
            if flags & 0x40000 != 0 { modifiers |= ctrl }
            result.append((HotkeyBinding(keyCode: keyCode, modifiers: modifiers), "a macOS system shortcut"))
        }
        return result
    }
}
