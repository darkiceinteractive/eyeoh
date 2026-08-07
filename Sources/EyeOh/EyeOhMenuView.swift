import AppKit
import SwiftUI

struct EyeOhMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    let store: AudioDeviceStore
    let cameraStore: CameraDeviceStore

    var body: some View {
        Group {
            Section("Input") {
                if store.devices.isEmpty {
                    Text("No input devices available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.devices) { device in
                        inputButton(for: device)
                    }
                }
            }

            Section("Output") {
                if store.outputDevices.isEmpty {
                    Text("No output devices available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.outputDevices) { device in
                        outputButton(for: device)
                    }
                }
            }

            Section("Camera") {
                if cameraStore.cameras.isEmpty {
                    Text("No cameras available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cameraStore.cameras) { camera in
                        cameraButton(for: camera)
                    }

                    Button("Preview Preferred Camera…", systemImage: "eye") {
                        openWindow(id: "camera-preview")
                    }
                    .disabled(cameraStore.selectedCamera == nil)
                }
            }

            Divider()

            inputVolumeControl
            outputVolumeControl

            if let errorMessage = store.errorMessage {
                Divider()
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            if let errorMessage = cameraStore.errorMessage {
                Divider()
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Refresh", systemImage: "arrow.clockwise") {
                store.refresh()
                cameraStore.refresh()
            }
            .keyboardShortcut("r")

            Button("Open Sound Settings…", systemImage: "gear") {
                openSoundSettings()
            }

            Divider()

            Button("About EyeOh", systemImage: "info.circle") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }

            Button("Quit EyeOh", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            // Volume may have changed in Sound Settings while the menu was closed.
            store.refresh()
            cameraStore.refresh()
        }
    }

    @ViewBuilder
    private var inputVolumeControl: some View {
        if let device = store.selectedDevice,
           let volume = device.volume,
           device.isVolumeSettable {
            volumeMenu(
                title: "Input volume",
                systemImage: "mic",
                volume: volume,
                setVolume: store.setSelectedInputVolume
            )
        } else if store.selectedDevice != nil {
            Label("Input volume · Controlled by device", systemImage: "mic")
                .disabled(true)
        }
    }

    @ViewBuilder
    private var outputVolumeControl: some View {
        if let device = store.selectedOutputDevice,
           let volume = device.volume,
           device.isVolumeSettable {
            volumeMenu(
                title: "Output volume",
                systemImage: "speaker.wave.2",
                volume: volume,
                setVolume: store.setSelectedOutputVolume
            )
        } else if store.selectedOutputDevice != nil {
            Label("Output volume · Controlled by device", systemImage: "speaker.slash")
                .disabled(true)
        }
    }

    private func volumeMenu(
        title: String,
        systemImage: String,
        volume: Float32,
        setVolume: @escaping (Float32) -> Void
    ) -> some View {
        let percentage = Int((volume * 100).rounded())
        return Menu {
            Button("Quieter by 5%", systemImage: "minus") {
                setVolume(max(0, volume - 0.05))
            }
            Button("Louder by 5%", systemImage: "plus") {
                setVolume(min(1, volume + 0.05))
            }

            Divider()

            ForEach([0, 25, 50, 75, 100], id: \.self) { preset in
                Button {
                    setVolume(Float32(preset) / 100)
                } label: {
                    if percentage == preset {
                        Label(preset == 0 ? "Mute" : "\(preset)%", systemImage: "checkmark")
                    } else {
                        Text(preset == 0 ? "Mute" : "\(preset)%")
                    }
                }
            }

            Divider()
            Text("Remembered for this device")
                .foregroundStyle(.secondary)
        } label: {
            Label("\(title) · \(percentage)%", systemImage: systemImage)
        }
    }

    private func inputButton(for device: AudioDevice) -> some View {
        let selected = device.id == store.selectedDeviceID
        return Button {
            store.select(device)
        } label: {
            deviceLabel(device, selected: selected)
        }
        .accessibilityLabel(
            "\(device.name), \(device.transport.rawValue) input, \(selected ? "selected" : "available")"
        )
    }

    private func outputButton(for device: AudioDevice) -> some View {
        let selected = device.id == store.selectedOutputDeviceID
        return Button {
            store.selectOutput(device)
        } label: {
            deviceLabel(device, selected: selected)
        }
        .accessibilityLabel(
            "\(device.name), \(device.transport.rawValue) output, \(selected ? "selected" : "available")"
        )
    }

    private func cameraButton(for camera: CameraDevice) -> some View {
        let selected = camera.id == cameraStore.selectedCameraID
        return Button {
            cameraStore.select(camera)
        } label: {
            cameraLabel(camera, selected: selected)
        }
        .accessibilityLabel(
            "\(camera.name), \(camera.kind.rawValue) camera, \(selected ? "preferred" : "available")"
        )
    }

    private func deviceLabel(_ device: AudioDevice, selected: Bool) -> some View {
        Label {
            Text("\(device.name) — \(device.transport.rawValue)")
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(
                    selected
                        ? (colorScheme == .dark ? DarkIceBrand.iceBlue : DarkIceBrand.readableBlue)
                        : .primary
                )
        } icon: {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(DarkIceBrand.charcoal, DarkIceBrand.lime)
            } else {
                Image(systemName: device.transport.systemImage)
            }
        }
    }

    private func cameraLabel(_ camera: CameraDevice, selected: Bool) -> some View {
        Label {
            Text("\(camera.name) — \(camera.kind.rawValue)")
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(
                    selected
                        ? (colorScheme == .dark ? DarkIceBrand.iceBlue : DarkIceBrand.readableBlue)
                        : .primary
                )
        } icon: {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(DarkIceBrand.charcoal, DarkIceBrand.lime)
            } else {
                Image(systemName: camera.kind.systemImage)
            }
        }
    }

    private func openSoundSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
