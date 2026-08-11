import XCTest
@testable import EyeOh

final class RememberedBluetoothDevicesTests: XCTestCase {
    func testExtractsBluetoothAddressFromCoreAudioUID() {
        XCTAssertEqual(
            RememberedBluetoothDevices.bluetoothAddress(from: "BC-87-FA-9C-65-E0:input"),
            "BC-87-FA-9C-65-E0"
        )
        XCTAssertEqual(
            RememberedBluetoothDevices.bluetoothAddress(from: "prefix-bc:87:fa:9c:65:e0-output"),
            "BC-87-FA-9C-65-E0"
        )
        XCTAssertNil(RememberedBluetoothDevices.bluetoothAddress(from: "built-in-microphone"))
    }

    func testRemembersBothRoutesAndPersistsLocally() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RememberedBluetoothDevices(defaults: defaults)

        store.remember(
            AudioDevice(
                id: 1,
                uid: "BC-87-FA-9C-65-E0:input",
                name: "Onyx Star",
                transport: .bluetooth,
                channelCount: 1
            ),
            direction: .input
        )
        store.remember(
            AudioDevice(
                id: 2,
                uid: "BC-87-FA-9C-65-E0:output",
                name: "Onyx Star",
                transport: .bluetooth,
                channelCount: 2
            ),
            direction: .output
        )

        let restored = RememberedBluetoothDevices(defaults: defaults)
        XCTAssertEqual(restored.devices.count, 1)
        XCTAssertEqual(restored.devices.first?.address, "BC-87-FA-9C-65-E0")
        XCTAssertEqual(restored.devices.first?.inputUID, "BC-87-FA-9C-65-E0:input")
        XCTAssertEqual(restored.devices.first?.outputUID, "BC-87-FA-9C-65-E0:output")
    }

    func testDisconnectedVisibilityDefaultsOnAndCanBeDisabled() {
        let suiteName = "EyeOhTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RememberedBluetoothDevices(defaults: defaults)

        XCTAssertTrue(store.showsDisconnectedDevices)
        store.showsDisconnectedDevices = false
        XCTAssertFalse(RememberedBluetoothDevices(defaults: defaults).showsDisconnectedDevices)
    }
}
