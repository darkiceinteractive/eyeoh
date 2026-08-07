import AVFoundation
import XCTest
@testable import EyeOh

@MainActor
final class CameraPreviewStoreTests: XCTestCase {
    func testPermissionResultDoesNotStartPreviewAfterWindowCloses() async {
        let preview = MockPreviewController()
        let authorization = YieldingAuthorizationController()
        let store = CameraPreviewStore(controller: preview, authorization: authorization)

        store.present(cameraID: "camera")
        store.requestAccess(cameraID: "camera")
        store.stop()

        for _ in 0..<4 {
            await Task.yield()
        }

        XCTAssertEqual(preview.startCount, 0)
        XCTAssertEqual(preview.stopCount, 2)
    }

    func testLosingTheLastCameraStopsPreviewAndIgnoresPendingCompletion() async {
        let preview = MockPreviewController(completesImmediately: false)
        let authorization = AuthorizedCameraController()
        let store = CameraPreviewStore(controller: preview, authorization: authorization)

        store.present(cameraID: "camera")
        XCTAssertEqual(preview.startCount, 1)

        store.prepare(cameraID: nil)
        preview.completeStart()
        await Task.yield()

        XCTAssertEqual(preview.stopCount, 1)
        XCTAssertEqual(store.errorMessage, "No camera is available to preview.")
    }
}

private final class MockPreviewController: CameraPreviewControlling, @unchecked Sendable {
    let session = AVCaptureSession()
    private let completesImmediately: Bool
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var startCompletion: (@Sendable (String?) -> Void)?

    init(completesImmediately: Bool = true) {
        self.completesImmediately = completesImmediately
    }

    func start(cameraID: String, completion: @escaping @Sendable (String?) -> Void) {
        startCount += 1
        if completesImmediately {
            completion(nil)
        } else {
            startCompletion = completion
        }
    }

    func stop() {
        stopCount += 1
    }

    func completeStart() {
        startCompletion?(nil)
        startCompletion = nil
    }
}

@MainActor
private struct AuthorizedCameraController: CameraAuthorizationControlling {
    func status() -> AVAuthorizationStatus {
        .authorized
    }

    func requestAccess() async -> Bool {
        true
    }
}

@MainActor
private struct YieldingAuthorizationController: CameraAuthorizationControlling {
    func status() -> AVAuthorizationStatus {
        .notDetermined
    }

    func requestAccess() async -> Bool {
        await Task.yield()
        return true
    }
}
