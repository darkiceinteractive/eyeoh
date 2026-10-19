import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ShortcutsSettingsView: View {
    let preferences: HotkeyPreferences
    let center: HotkeyCenter
    @State private var messages: [HotkeyAction: String] = [:]

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases) { action in
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent(action.title) {
                            ShortcutRecorder(
                                binding: preferences.binding(for: action),
                                onRecord: { record($0, for: action) }
                            )
                            .frame(width: 140, height: 24)
                        }
                        if let message = messages[action] ?? center.failures[action] {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Click a field, then press a shortcut that includes ⌘, ⌃ or ⌥. Press Delete to clear it, or Esc to cancel. Shortcuts work in any app and are off until you set them.")
            }
        }
        .formStyle(.grouped)
    }

    private func record(_ binding: HotkeyBinding?, for action: HotkeyAction) {
        messages[action] = nil
        switch preferences.set(binding, for: action) {
        case .assigned:
            break
        case .invalid:
            messages[action] = "Include ⌘, ⌃ or ⌥ so normal typing isn't captured."
        case .conflict(let other):
            messages[action] = "Already used for \"\(other.title)\"."
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let binding: HotkeyBinding?
    let onRecord: (HotkeyBinding?) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.onRecord = onRecord
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.onRecord = onRecord
        button.currentBinding = binding
    }
}

private final class RecorderButton: NSButton {
    var onRecord: ((HotkeyBinding?) -> Void)?
    var currentBinding: HotkeyBinding? { didSet { refreshTitle() } }
    private var isRecording = false { didSet { refreshTitle() } }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        keyDown(with: event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        switch Int(event.keyCode) {
        case kVK_Escape:
            break
        case kVK_Delete, kVK_ForwardDelete:
            onRecord?(nil)
        default:
            onRecord?(HotkeyBinding(
                keyCode: UInt32(event.keyCode),
                modifiers: event.modifierFlags.carbonModifiers
            ))
        }
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func refreshTitle() {
        title = isRecording ? "Type shortcut…" : (currentBinding?.displayString ?? "Not set")
    }
}
