import AppKit
import SwiftUI

struct EyeOhMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    let store: AudioDeviceStore
    let cameraStore: CameraDeviceStore

    var body: some View {
        Group {
            Section("Input") {
                if store.devices.isEmpty && store.rememberedInputDevices.isEmpty {
                    Text("No input devices available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.devices) { device in
                        inputButton(for: device)
                    }
                    ForEach(store.rememberedInputDevices) { remembered in
                        rememberedInputButton(for: remembered)
                    }
                }
            }

            Section("Output") {
                if store.outputDevices.isEmpty && store.rememberedOutputDevices.isEmpty {
                    Text("No output devices available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.outputDevices) { device in
                        outputButton(for: device)
                    }
                    ForEach(store.rememberedOutputDevices) { remembered in
                        rememberedOutputButton(for: remembered)
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

                    Button("Preview Preferred Camera…", systemImage: "video") {
                        Diagnostics.record(.previewOpened)
                        openWindow(id: "camera-preview")
                        AppWindowPresenter.bringToFront(title: "Camera Preview")
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

            Button("Settings…", systemImage: "gearshape") {
                openSettings()
                AppWindowPresenter.bringSettingsToFront()
            }
            .keyboardShortcut(",")

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

    private func rememberedInputButton(for remembered: RememberedBluetoothAudioDevice) -> some View {
        Button {
            Task { await store.connectInput(remembered) }
        } label: {
            rememberedBluetoothLabel(remembered)
        }
        .disabled(store.connectingBluetoothAddress != nil)
        .accessibilityLabel(
            "\(remembered.name), disconnected remembered Bluetooth input. Connect and select."
        )
    }

    private func rememberedOutputButton(for remembered: RememberedBluetoothAudioDevice) -> some View {
        Button {
            Task { await store.connectOutput(remembered) }
        } label: {
            rememberedBluetoothLabel(remembered)
        }
        .disabled(store.connectingBluetoothAddress != nil)
        .accessibilityLabel(
            "\(remembered.name), disconnected remembered Bluetooth output. Connect and select."
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
            Text(compactMenuName(device.name))
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
        .help("\(device.name) · \(device.transport.rawValue)")
    }

    private func rememberedBluetoothLabel(_ remembered: RememberedBluetoothAudioDevice) -> some View {
        let connecting = store.isConnecting(remembered)
        return Label {
            Text("\(compactMenuName(remembered.name)) · \(connecting ? "Connecting…" : "Connect")")
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: connecting ? "arrow.trianglehead.2.clockwise.rotate.90" : "wave.3.right")
                .foregroundStyle(connecting ? DarkIceBrand.iceBlue : .secondary)
        }
        .help("\(remembered.name) · Disconnected Bluetooth device")
    }

    private func cameraLabel(_ camera: CameraDevice, selected: Bool) -> some View {
        Label {
            Text(compactMenuName(camera.name))
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
        .help("\(camera.name) · \(camera.kind.rawValue)")
    }

    private func compactMenuName(_ name: String) -> String {
        name.replacingOccurrences(of: "MacBook Pro", with: "MacBook", options: .caseInsensitive)
    }

}
