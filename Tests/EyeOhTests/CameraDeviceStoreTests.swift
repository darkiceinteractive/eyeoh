import XCTest
@testable import EyeOh

@MainActor
final class CameraDeviceStoreTests: XCTestCase {
    func testLoadsCamerasAndPreferredCamera() {
        let controller = MockCameraController()
        controller.devices = [
            CameraDevice(id: "built-in", name: "MacBook Pro Camera", kind: .builtIn),
            CameraDevice(id: "airhug", name: "AIRHUG 11", kind: .external),
        ]
        controller.preferredID = "airhug"

        let store = CameraDeviceStore(controller: controller)

        XCTAssertEqual(store.cameras.count, 2)
        XCTAssertEqual(store.selectedCamera?.name, "AIRHUG 11")
        XCTAssertNil(store.errorMessage)
    }

    func testSelectingCameraUpdatesPreference() {
        let controller = MockCameraController()
        let builtIn = CameraDevice(
            id: "built-in",
            name: "MacBook Pro Camera",
            kind: .builtIn
        )
        let airhug = CameraDevice(id: "airhug", name: "AIRHUG 11", kind: .external)
        controller.devices = [builtIn, airhug]
        controller.preferredID = builtIn.id
        let store = CameraDeviceStore(controller: controller)

        store.select(airhug)

        XCTAssertEqual(controller.preferredID, airhug.id)
        XCTAssertEqual(store.selectedCameraID, airhug.id)
    }

    func testSelectionFailureKeepsPreviousPreference() {
        let controller = MockCameraController()
        let builtIn = CameraDevice(
            id: "built-in",
            name: "MacBook Pro Camera",
            kind: .builtIn
        )
        let airhug = CameraDevice(id: "airhug", name: "AIRHUG 11", kind: .external)
        controller.devices = [builtIn, airhug]
        controller.preferredID = builtIn.id
        let store = CameraDeviceStore(controller: controller)
        controller.setError = TestError.denied

        store.select(airhug)

        XCTAssertEqual(store.selectedCameraID, builtIn.id)
        XCTAssertNotNil(store.errorMessage)
    }
}

private extension CameraDeviceStoreTests {
    enum TestError: Error {
        case denied
    }
}

@MainActor
private final class MockCameraController: CameraDeviceControlling {
    var devices: [CameraDevice] = []
    var preferredID: String?
    var setError: Error?

    func cameras() -> [CameraDevice] {
        devices
    }

    func preferredCameraID() -> String? {
        preferredID
    }

    func setPreferredCamera(_ id: String) throws {
        if let setError { throw setError }
        preferredID = id
    }
}
