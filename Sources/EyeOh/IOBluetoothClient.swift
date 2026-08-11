import IOBluetooth

struct IOBluetoothClient: BluetoothDeviceConnecting {
    func connect(address: String) async throws {
        guard let device = IOBluetoothDevice(addressString: address) else {
            throw BluetoothConnectionError.unavailable
        }
        guard device.isPaired() else {
            throw BluetoothConnectionError.notPaired
        }
        guard !device.isConnected() else { return }

        try await BluetoothConnectionAttempt(device: device).run()
    }
}

private final class BluetoothConnectionAttempt: NSObject, @unchecked Sendable {
    private let device: IOBluetoothDevice
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(device: IOBluetoothDevice) {
        self.device = device
    }

    func run() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    self.continuation = continuation
                }

                let status = device.openConnection(self)
                guard status == kIOReturnSuccess else {
                    if device.isConnected() {
                        finish(with: .success(()))
                    } else {
                        finish(with: .failure(BluetoothConnectionError.connectionFailed(status)))
                    }
                    return
                }

                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    self?.finish(with: .failure(BluetoothConnectionError.timedOut))
                }
            }
        } onCancel: {
            finish(with: .failure(CancellationError()))
        }
    }

    @objc(connectionComplete:status:)
    func connectionComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        if status == kIOReturnSuccess || device.isConnected() {
            finish(with: .success(()))
        } else {
            finish(with: .failure(BluetoothConnectionError.connectionFailed(status)))
        }
    }

    private func finish(with result: Result<Void, Error>) {
        let pending = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            let pending = continuation
            continuation = nil
            return pending
        }
        guard let pending else { return }
        timeoutTask?.cancel()
        pending.resume(with: result)
    }
}
