import XCTest
@testable import EyeOh

@MainActor
final class SoftwareUpdateControllerTests: XCTestCase {
    func testSourceBuildDoesNotExposeDirectUpdater() {
        let controller = SoftwareUpdateController()

        XCTAssertFalse(controller.isAvailable)
        XCTAssertFalse(controller.canCheckForUpdates)
        XCTAssertFalse(controller.automaticallyChecksForUpdates)
        XCTAssertFalse(controller.automaticallyDownloadsUpdates)
    }
}
