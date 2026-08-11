import AppKit
import SwiftUI

struct EyeOhHelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header("EyeOh Help", subtitle: "Quick switching for your Mac's input, output and camera.")

                helpItem(
                    icon: "arrow.left.arrow.right",
                    title: "Switch a device",
                    text: "Open EyeOh from the menu bar, then click an input, output or camera. The green check shows the current macOS preference."
                )
                helpItem(
                    icon: "bolt.horizontal.circle",
                    title: "Reconnect Bluetooth audio",
                    text: "After EyeOh has seen a Bluetooth microphone or speaker, it can keep a dimmed shortcut in the menu while that device is disconnected. Click Connect to ask macOS to reconnect it, wait for the route to appear, then select it and restore its saved volume. EyeOh never pairs new devices."
                )
                helpItem(
                    icon: "slider.horizontal.3",
                    title: "An app did not follow",
                    text: "Zoom, Teams and other apps can pin their own device. Set that app to Default or Automatic so it follows EyeOh."
                )
                helpItem(
                    icon: "video",
                    title: "Preview a camera",
                    text: "Choose a camera, then open Preview Preferred Camera. EyeOh asks for camera access only for this local preview and never records it."
                )
                helpItem(
                    icon: "waveform.path",
                    title: "Virtual devices",
                    text: "EyeOh shows usable Core Audio routes. Private meeting-app endpoints are hidden; installed virtual drivers can appear when macOS allows them as a default."
                )

                Divider()

                HStack {
                    Button("Send Feedback…", systemImage: "envelope") {
                        FeedbackMail.open()
                        Diagnostics.record(.feedbackOpened)
                    }
                    Spacer()
                    Text("No audio, video or device names are attached.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .background(DarkIceBrand.charcoal.opacity(0.035))
    }

    private func helpItem(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DarkIceBrand.iceBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EyeOhAboutView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: IORouteStatusIcon.image)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 56)
                .padding(18)
                .background(DarkIceBrand.charcoal, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("EyeOh").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Version \(AppMetadata.version) (\(AppMetadata.build))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Quickly reconnect and switch your Mac's audio input, audio output and preferred camera.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            VStack(spacing: 4) {
                Text("Free and open-source software")
                    .font(.headline)
                Text("Source code: MIT License\nEyeOh name and artwork: Dark Ice Interactive")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Visit Dark Ice") {
                    guard let url = URL(string: "https://darkice.au/") else { return }
                    NSWorkspace.shared.open(url)
                }
                Button("Send Feedback…") {
                    FeedbackMail.open()
                    Diagnostics.record(.feedbackOpened)
                }
            }

            Text("Copyright © 2026 Dark Ice Interactive Pty Ltd")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func header(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.largeTitle.bold())
        Text(subtitle).foregroundStyle(.secondary)
    }
}

enum AppMetadata {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local"
    }
}

enum FeedbackMail {
    static func open() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "darkice@darkice.co"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "EyeOh feedback — v\(AppMetadata.version)"),
            URLQueryItem(
                name: "body",
                value: "Hi Dark Ice,\n\nWhat happened?\n\n\nWhat did you expect?\n\n\nEyeOh: \(AppMetadata.version) (\(AppMetadata.build))\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
            ),
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
