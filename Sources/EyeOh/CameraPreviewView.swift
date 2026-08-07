import AppKit
import AVFoundation
import SwiftUI

@MainActor
protocol CameraAuthorizationControlling {
    func status() -> AVAuthorizationStatus
    func requestAccess() async -> Bool
}

@MainActor
struct AVCameraAuthorizationClient: CameraAuthorizationControlling {
    func status() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

@MainActor
@Observable
final class CameraPreviewStore {
    enum State {
        case permissionRequired
        case denied
        case restricted
        case connecting
        case previewing
        case failed
    }

    let controller: any CameraPreviewControlling
    private let authorization: any CameraAuthorizationControlling

    private(set) var state: State = .permissionRequired
    private(set) var errorMessage: String?
    private var isVisible = false
    private var lifecycleGeneration = 0

    init(
        controller: any CameraPreviewControlling = CameraPreviewController(),
        authorization: any CameraAuthorizationControlling = AVCameraAuthorizationClient()
    ) {
        self.controller = controller
        self.authorization = authorization
    }

    func present(cameraID: String?) {
        isVisible = true
        prepare(cameraID: cameraID)
    }

    func prepare(cameraID: String?) {
        guard isVisible else { return }
        guard let cameraID else {
            invalidateCapture()
            state = .failed
            errorMessage = "No camera is available to preview."
            return
        }

        switch authorization.status() {
        case .authorized:
            start(cameraID: cameraID)
        case .notDetermined:
            invalidateCapture()
            state = .permissionRequired
            errorMessage = nil
        case .denied:
            invalidateCapture()
            state = .denied
            errorMessage = nil
        case .restricted:
            invalidateCapture()
            state = .restricted
            errorMessage = nil
        @unknown default:
            invalidateCapture()
            state = .failed
            errorMessage = "Camera access is unavailable."
        }
    }

    func requestAccess(cameraID: String?) {
        guard let cameraID else { return }
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        Task {
            let granted = await authorization.requestAccess()
            guard isVisible, generation == lifecycleGeneration else { return }
            if granted {
                start(cameraID: cameraID)
            } else {
                state = .denied
            }
        }
    }

    func stop() {
        isVisible = false
        invalidateCapture()
    }

    private func invalidateCapture() {
        lifecycleGeneration += 1
        controller.stop()
    }

    private func start(cameraID: String) {
        guard isVisible else { return }
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        state = .connecting
        errorMessage = nil
        controller.start(cameraID: cameraID) { [weak self] errorMessage in
            Task { @MainActor in
                guard let self,
                      self.isVisible,
                      generation == self.lifecycleGeneration
                else { return }
                if let errorMessage {
                    self.errorMessage = errorMessage
                    self.state = .failed
                } else {
                    self.state = .previewing
                }
            }
        }
    }
}

struct CameraPreviewWindow: View {
    @Environment(\.dismissWindow) private var dismissWindow

    let cameraStore: CameraDeviceStore
    @State private var previewStore = CameraPreviewStore()

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Camera Preview")
                    .font(.title2.weight(.semibold))
                Spacer()
                cameraPicker
                    .frame(maxWidth: 280)
            }

            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Label("Live preview only — nothing is recorded", systemImage: "eye")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    dismissWindow(id: "camera-preview")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 430)
        .onAppear {
            cameraStore.refresh()
            previewStore.present(cameraID: cameraStore.selectedCameraID)
        }
        .onDisappear {
            previewStore.stop()
        }
        .onChange(of: cameraStore.selectedCameraID) { _, cameraID in
            previewStore.prepare(cameraID: cameraID)
        }
    }

    private var cameraPicker: some View {
        Picker("Preferred camera", selection: cameraSelection) {
            ForEach(cameraStore.cameras) { camera in
                Label(camera.name, systemImage: camera.kind.systemImage)
                    .tag(Optional(camera.id))
            }
        }
        .labelsHidden()
        .disabled(cameraStore.cameras.isEmpty)
        .accessibilityLabel("Preferred camera")
    }

    private var cameraSelection: Binding<String?> {
        Binding(
            get: { cameraStore.selectedCameraID },
            set: { cameraID in
                guard let cameraID,
                      let camera = cameraStore.cameras.first(where: { $0.id == cameraID })
                else { return }
                cameraStore.select(camera)
            }
        )
    }

    @ViewBuilder
    private var previewContent: some View {
        switch previewStore.state {
        case .permissionRequired:
            permissionView
        case .denied:
            statusView(
                title: "Camera access is off",
                message: "Allow camera access in Privacy & Security to show a preview.",
                systemImage: "video.slash",
                actionTitle: "Open Privacy & Security…",
                action: openCameraPrivacySettings
            )
        case .restricted:
            statusView(
                title: "Camera access is restricted",
                message: "Camera access is restricted on this Mac.",
                systemImage: "lock",
                actionTitle: nil,
                action: nil
            )
        case .connecting:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Connecting to \(cameraStore.selectedCamera?.name ?? "camera")…")
                    .foregroundStyle(.white)
            }
        case .previewing:
            CameraPreviewLayerView(session: previewStore.controller.session)
                .accessibilityLabel(
                    "Live preview from \(cameraStore.selectedCamera?.name ?? "the selected camera")"
                )
        case .failed:
            statusView(
                title: "Couldn’t start this camera",
                message: previewStore.errorMessage ?? "Close another app using it, then try again.",
                systemImage: "exclamationmark.triangle",
                actionTitle: "Try Again",
                action: {
                    previewStore.prepare(cameraID: cameraStore.selectedCameraID)
                }
            )
        }
    }

    private var permissionView: some View {
        statusView(
            title: "Allow camera preview",
            message: "Camera access is used only while this preview window is open. Nothing is recorded.",
            systemImage: "video",
            actionTitle: "Allow Preview",
            action: {
                previewStore.requestAccess(cameraID: cameraStore.selectedCameraID)
            }
        )
    }

    private func statusView(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 38))
                .foregroundStyle(.white.opacity(0.9))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: 380)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }

    private func openCameraPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewLayerView {
        PreviewLayerView(session: session)
    }

    func updateNSView(_ nsView: PreviewLayerView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class PreviewLayerView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = previewLayer
        previewLayer.videoGravity = .resizeAspect
        previewLayer.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
