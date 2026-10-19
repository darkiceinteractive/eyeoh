import AppKit
import SwiftUI

struct EyeOhMenuView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    let store: AudioDeviceStore
    let cameraStore: CameraDeviceStore
    let preferences: AppPreferences
    let softwareUpdater: SoftwareUpdateController
    let micMute: MicMuteController

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    MicMuteMenuRow(micMute: micMute)

                    outputVolumeControl

                    if preferences.showsInputVolumeInMenu {
                        inputVolumeControl
                    }

                    routeSection(
                        title: "Input",
                        systemImage: "mic",
                        emptyMessage: "No input devices available"
                    ) {
                        ForEach(store.devices) { device in
                            inputButton(for: device)
                        }
                        ForEach(store.rememberedInputDevices) { remembered in
                            rememberedInputButton(for: remembered)
                        }
                        lockIndicator(store.inputLockStatus, noun: "input")
                    }

                    routeSection(
                        title: "Output",
                        systemImage: "speaker.wave.2",
                        emptyMessage: "No output devices available"
                    ) {
                        ForEach(store.outputDevices) { device in
                            outputButton(for: device)
                        }
                        ForEach(store.rememberedOutputDevices) { remembered in
                            rememberedOutputButton(for: remembered)
                        }
                        lockIndicator(store.outputLockStatus, noun: "output")
                    }

                    routeSection(
                        title: "Camera",
                        systemImage: "video",
                        emptyMessage: "No cameras available"
                    ) {
                        ForEach(cameraStore.cameras) { camera in
                            cameraButton(for: camera)
                        }

                        Button {
                            Diagnostics.record(.previewOpened)
                            openWindow(id: "camera-preview")
                            AppWindowPresenter.bringToFront(title: "Camera Preview")
                        } label: {
                            menuRowLabel("Preview preferred camera…", systemImage: "play.rectangle")
                        }
                        .buttonStyle(.plain)
                        .disabled(cameraStore.selectedCamera == nil)

                        if let hint = cameraStore.holdHint {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }

                    if let errorMessage = store.errorMessage {
                        errorCard(errorMessage)
                    }

                    if let errorMessage = cameraStore.errorMessage {
                        errorCard(errorMessage)
                    }
                }
                .padding(14)
            }

            footer
        }
        .frame(width: 360)
        .background(.regularMaterial)
        .onAppear {
            // Volume may have changed in Sound Settings while the panel was closed.
            store.refresh()
            cameraStore.refresh()
            micMute.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: IORouteStatusIcon.image)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .padding(7)
                .background(DarkIceBrand.iceBlue.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("EyeOh")
                    .font(.headline)
                Text("Quick routes for this Mac")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openSettings()
                AppWindowPresenter.bringSettingsToFront()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var outputVolumeControl: some View {
        if let device = store.selectedOutputDevice,
           let volume = device.volume,
           device.isVolumeSettable {
            volumeCard(
                title: "Output volume",
                subtitle: compactMenuName(device.name),
                systemImage: "speaker.wave.2.fill",
                volume: volume,
                setVolume: store.setSelectedOutputVolume
            )
        } else if let device = store.selectedOutputDevice {
            unavailableVolumeCard(title: "Output volume", deviceName: device.name, systemImage: "speaker.slash")
        }
    }

    @ViewBuilder
    private var inputVolumeControl: some View {
        if let device = store.selectedDevice,
           let volume = device.volume,
           device.isVolumeSettable {
            volumeCard(
                title: "Input volume",
                subtitle: compactMenuName(device.name),
                systemImage: "mic.fill",
                volume: volume,
                setVolume: store.setSelectedInputVolume
            )
        } else if let device = store.selectedDevice {
            unavailableVolumeCard(title: "Input volume", deviceName: device.name, systemImage: "mic.slash")
        }
    }

    @ViewBuilder
    private func lockIndicator(_ status: AudioDeviceStore.LockStatus, noun: String) -> some View {
        switch status {
        case .off:
            EmptyView()
        case .active:
            Label("Locked to priority list", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("The \(noun) is locked to your priority list")
        case .paused:
            Label("Lock paused, something keeps changing it", systemImage: "lock.open.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func volumeCard(
        title: String,
        subtitle: String,
        systemImage: String,
        volume: Float32,
        setVolume: @escaping (Float32) -> Void
    ) -> some View {
        let percentage = Int((volume * 100).rounded())
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(DarkIceBrand.iceBlue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text("\(percentage)%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DarkIceBrand.iceBlue)
            }

            HStack(spacing: 9) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(volume) },
                        set: { setVolume(Float32($0)) }
                    ),
                    in: 0...1
                )
                .tint(DarkIceBrand.iceBlue)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(percentage) percent")
        }
        .padding(12)
        .background(DarkIceBrand.iceBlue.opacity(colorScheme == .dark ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.12 : 0.40))
        }
    }

    private func unavailableVolumeCard(title: String, deviceName: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(compactMenuName(deviceName)) controls its own level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func routeSection<Content: View>(
        title: String,
        systemImage: String,
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isEmpty: Bool
        switch title {
        case "Input": isEmpty = store.devices.isEmpty && store.rememberedInputDevices.isEmpty
        case "Output": isEmpty = store.outputDevices.isEmpty && store.rememberedOutputDevices.isEmpty
        default: isEmpty = cameraStore.cameras.isEmpty
        }

        return VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 2) {
                if isEmpty {
                    Text(emptyMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                } else {
                    content()
                }
            }
            .padding(4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if softwareUpdater.isAvailable {
                Button("Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                    softwareUpdater.checkForUpdates()
                }
                .disabled(!softwareUpdater.canCheckForUpdates)
            }

            Spacer()

            Button("Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func inputButton(for device: AudioDevice) -> some View {
        let selected = device.id == store.selectedDeviceID
        return Button { store.select(device) } label: { deviceLabel(device, selected: selected) }
            .buttonStyle(.plain)
            .accessibilityLabel("\(device.name), \(device.transport.rawValue) input, \(selected ? "selected" : "available")")
    }

    private func outputButton(for device: AudioDevice) -> some View {
        let selected = device.id == store.selectedOutputDeviceID
        return Button { store.selectOutput(device) } label: { deviceLabel(device, selected: selected) }
            .buttonStyle(.plain)
            .accessibilityLabel("\(device.name), \(device.transport.rawValue) output, \(selected ? "selected" : "available")")
    }

    private func rememberedInputButton(for remembered: RememberedBluetoothAudioDevice) -> some View {
        Button { Task { await store.connectInput(remembered) } } label: { rememberedBluetoothLabel(remembered) }
            .buttonStyle(.plain)
            .disabled(store.connectingBluetoothAddress != nil)
    }

    private func rememberedOutputButton(for remembered: RememberedBluetoothAudioDevice) -> some View {
        Button { Task { await store.connectOutput(remembered) } } label: { rememberedBluetoothLabel(remembered) }
            .buttonStyle(.plain)
            .disabled(store.connectingBluetoothAddress != nil)
    }

    private func cameraButton(for camera: CameraDevice) -> some View {
        let selected = camera.id == cameraStore.selectedCameraID
        return Button { cameraStore.select(camera) } label: { cameraLabel(camera, selected: selected) }
            .buttonStyle(.plain)
            .accessibilityLabel("\(camera.name), \(camera.kind.rawValue) camera, \(selected ? "preferred" : "available")")
    }

    private func deviceLabel(_ device: AudioDevice, selected: Bool) -> some View {
        menuRowLabel(compactMenuName(device.name), systemImage: selected ? "checkmark.circle.fill" : device.transport.systemImage, selected: selected)
            .help("\(device.name) · \(device.transport.rawValue)")
    }

    private func rememberedBluetoothLabel(_ remembered: RememberedBluetoothAudioDevice) -> some View {
        let connecting = store.isConnecting(remembered)
        return menuRowLabel(
            "\(compactMenuName(remembered.name)) · \(connecting ? "Connecting…" : "Connect")",
            systemImage: connecting ? "arrow.trianglehead.2.clockwise.rotate.90" : "wave.3.right",
            secondary: true
        )
    }

    private func cameraLabel(_ camera: CameraDevice, selected: Bool) -> some View {
        menuRowLabel(compactMenuName(camera.name), systemImage: selected ? "checkmark.circle.fill" : camera.kind.systemImage, selected: selected)
            .help("\(camera.name) · \(camera.kind.rawValue)")
    }

    private func menuRowLabel(
        _ title: String,
        systemImage: String,
        selected: Bool = false,
        secondary: Bool = false
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .frame(width: 17)
                .foregroundStyle(selected ? DarkIceBrand.iceBlue : (secondary ? .secondary : .primary))
            Text(title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(secondary ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(selected ? DarkIceBrand.iceBlue.opacity(colorScheme == .dark ? 0.18 : 0.12) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func errorCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactMenuName(_ name: String) -> String {
        name.replacingOccurrences(of: "MacBook Pro", with: "MacBook", options: .caseInsensitive)
    }
}
