import Foundation
import IOBluetooth

@main
struct AudioSandboxProbe {
    static func main() throws {
        let client = CoreAudioClient()
        let inputs = try client.inputDevices()
        let outputs = try client.outputDevices()
        let inputID = try client.defaultInputDeviceID()
        let outputID = try client.defaultOutputDeviceID()

        guard inputs.contains(where: { $0.id == inputID }) else {
            throw ProbeError.defaultInputMissing
        }
        guard outputs.contains(where: { $0.id == outputID }) else {
            throw ProbeError.defaultOutputMissing
        }

        if ProcessInfo.processInfo.environment["EYEOH_PROBE_WRITES"] == "1" {
            let systemOutputID = try client.defaultSystemOutputDeviceID()
            defer {
                try? client.setDefaultInputDevice(inputID)
                try? client.setDefaultOutputDevice(outputID)
                try? client.setSystemOutputDevice(systemOutputID)
            }

            try client.setDefaultInputDevice(inputID)
            try client.setDefaultOutputDevice(outputID)
            try client.setSystemOutputDevice(systemOutputID)
        }

        let mode = ProcessInfo.processInfo.environment["EYEOH_PROBE_WRITES"] == "1"
            ? "read/write-current"
            : "read"
        print("Sandbox \(mode) probe passed: \(inputs.count) inputs, \(outputs.count) outputs.")

        if ProcessInfo.processInfo.environment["EYEOH_PROBE_BLUETOOTH_READ"] == "1" {
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            let pairedAddresses = Set(paired.compactMap(\.addressString))
            print("Sandbox Bluetooth probe passed: \(pairedAddresses.count) paired devices visible.")
        }
    }
}

private enum ProbeError: Error {
    case defaultInputMissing
    case defaultOutputMissing
}
