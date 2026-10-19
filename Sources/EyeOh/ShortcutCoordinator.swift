import AppKit
import SwiftUI

@MainActor
final class ShortcutCoordinator {
    private let store: AudioDeviceStore
    private let micMute: MicMuteController
    private let hud = HUDPresenter()

    init(store: AudioDeviceStore, micMute: MicMuteController) {
        self.store = store
        self.micMute = micMute
    }

    func handle(_ action: HotkeyAction) {
        switch action {
        case .toggleMicMute:
            micMute.toggle()
            if let error = micMute.errorMessage, !micMute.isSilenced {
                hud.show(symbol: "exclamationmark.triangle", text: error)
            } else if micMute.isSilenced {
                hud.show(symbol: "mic.slash.fill", text: "Microphone muted")
            } else {
                hud.show(symbol: "mic.fill", text: "Microphone on")
            }
        case .nextInput:
            guard let next = DeviceCycler.next(in: store.devices, after: store.selectedDeviceID) else {
                hud.show(symbol: "mic", text: "No other input")
                return
            }
            store.select(next)
            hud.show(symbol: "mic.fill", text: next.name)
        case .nextOutput:
            guard let next = DeviceCycler.next(in: store.outputDevices, after: store.selectedOutputDeviceID) else {
                hud.show(symbol: "speaker.wave.2", text: "No other output")
                return
            }
            store.selectOutput(next)
            hud.show(symbol: "speaker.wave.2.fill", text: next.name)
        case .openMenu:
            MenuBarItemOpener.open()
        }
    }
}

/// Opens the MenuBarExtra panel by clicking its status item button. SwiftUI exposes no API for this.
@MainActor
enum MenuBarItemOpener {
    static func open() {
        for window in NSApp.windows where NSStringFromClass(type(of: window)).contains("StatusBarWindow") {
            if let button = firstControl(in: window.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    private static func firstControl(in view: NSView?) -> NSControl? {
        guard let view else { return nil }
        if let control = view as? NSControl { return control }
        for subview in view.subviews {
            if let found = firstControl(in: subview) { return found }
        }
        return nil
    }
}

@MainActor
final class HUDPresenter {
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(symbol: String, text: String) {
        let hosting = NSHostingView(rootView: HUDView(symbol: symbol, text: text))
        let size = hosting.fittingSize
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = hosting
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrame(
                NSRect(
                    x: frame.midX - size.width / 2,
                    y: frame.minY + frame.height * 0.14,
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak panel] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel?.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    if panel?.alphaValue == 0 { panel?.orderOut(nil) }
                }
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        return panel
    }
}

private struct HUDView: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(DarkIceBrand.iceBlue)
            Text(text)
                .font(.headline)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .fixedSize()
    }
}
