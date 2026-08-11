import Foundation

protocol BluetoothDeviceConnecting: Sendable {
    func connect(address: String) async throws
}

enum BluetoothConnectionError: LocalizedError, Equatable {
    case unavailable
    case notPaired
    case timedOut
    case connectionFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The remembered Bluetooth device is no longer available."
        case .notPaired:
            "The Bluetooth device is no longer paired with this Mac."
        case .timedOut:
            "The Bluetooth device did not answer before the connection timed out."
        case let .connectionFailed(status):
            "macOS could not connect to the Bluetooth device (\(status))."
        }
    }
}
