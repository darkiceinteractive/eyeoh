import AppKit
import Carbon.HIToolbox
import Observation

/// Registers the configured shortcuts with Carbon, which needs neither Accessibility
/// permission nor extra sandbox entitlements.
@MainActor
@Observable
final class HotkeyCenter {
    private static let signature: OSType = 0x45594F48 // 'EYOH'

    private let preferences: HotkeyPreferences
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var registered: [HotkeyAction: EventHotKeyRef] = [:]
    @ObservationIgnored var onAction: ((HotkeyAction) -> Void)?

    private(set) var failures: [HotkeyAction: String] = [:]

    init(preferences: HotkeyPreferences) {
        self.preferences = preferences
        preferences.onChange = { [weak self] in self?.sync() }
    }

    func start() {
        installHandler()
        sync()
    }

    func sync() {
        registered.values.forEach { UnregisterEventHotKey($0) }
        registered.removeAll()
        failures.removeAll()

        for (index, action) in HotkeyAction.allCases.enumerated() {
            guard let binding = preferences.binding(for: action) else { continue }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.keyCode,
                binding.modifiers,
                EventHotKeyID(signature: Self.signature, id: UInt32(index)),
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                registered[action] = ref
            } else {
                failures[action] = "\(binding.displayString) is already used by the system or another app."
            }
        }
    }

    fileprivate func handle(id: UInt32) {
        guard HotkeyAction.allCases.indices.contains(Int(id)) else { return }
        onAction?(HotkeyAction.allCases[Int(id)])
    }

    private func installHandler() {
        guard handlerRef == nil else { return }
        HotkeyDispatch.target = self
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let id = hotKeyID.id
                Task { @MainActor in HotkeyDispatch.target?.handle(id: id) }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
    }
}

@MainActor
private enum HotkeyDispatch {
    static weak var target: HotkeyCenter?
}

extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        return value
    }
}
