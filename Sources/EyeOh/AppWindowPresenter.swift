import AppKit

@MainActor
enum AppWindowPresenter {
    static func bringToFront(title: String, attemptsRemaining: Int = 6) {
        if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
            present(window)
            return
        }

        guard attemptsRemaining > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            bringToFront(title: title, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    static func bringSettingsToFront(attemptsRemaining: Int = 6) {
        let settingsTitles = ["General", "Privacy", "Help", "About"]
        if let window = NSApplication.shared.windows.first(where: {
            settingsTitles.contains($0.title)
        }) {
            present(window)
            return
        }

        guard attemptsRemaining > 0 else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            bringSettingsToFront(attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private static func present(_ window: NSWindow) {
        var collectionBehavior = window.collectionBehavior
        collectionBehavior.insert(.moveToActiveSpace)
        window.collectionBehavior = collectionBehavior

        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }),
           let screen = NSScreen.main ?? NSScreen.screens.first {
            var frame = window.frame
            frame.origin = NSPoint(
                x: screen.visibleFrame.midX - frame.width / 2,
                y: screen.visibleFrame.midY - frame.height / 2
            )
            window.setFrame(frame, display: false)
        }

        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
