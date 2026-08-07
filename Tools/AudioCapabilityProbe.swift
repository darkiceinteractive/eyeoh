import CoreAudio
import Foundation

@main
struct AudioCapabilityProbe {
    static func main() throws {
        for id in try deviceIDs() {
            guard let name = stringProperty(kAudioObjectPropertyName, id: id) else { continue }
            let transport = uint32Property(kAudioDevicePropertyTransportType, id: id) ?? 0
            let hidden = (uint32Property(kAudioDevicePropertyIsHidden, id: id) ?? 0) != 0
            let alive = (uint32Property(kAudioDevicePropertyDeviceIsAlive, id: id) ?? 0) != 0
            let inputDefault = scopedBooleanProperty(
                kAudioDevicePropertyDeviceCanBeDefaultDevice,
                id: id,
                scope: kAudioDevicePropertyScopeInput
            )
            let outputDefault = scopedBooleanProperty(
                kAudioDevicePropertyDeviceCanBeDefaultDevice,
                id: id,
                scope: kAudioDevicePropertyScopeOutput
            )

            let input = volumeCapability(id: id, scope: kAudioDevicePropertyScopeInput)
            let output = volumeCapability(id: id, scope: kAudioDevicePropertyScopeOutput)

            print(
                [
                    name,
                    "transport=\(fourCC(transport))",
                    "hidden=\(hidden)",
                    "alive=\(alive)",
                    "inputDefault=\(inputDefault.map(String.init) ?? "unknown")",
                    "outputDefault=\(outputDefault.map(String.init) ?? "unknown")",
                    "inputVolume=\(input)",
                    "outputVolume=\(output)",
                ].joined(separator: "\t")
            )
        }
    }

    private static func deviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        var ids = Array(
            repeating: AudioDeviceID(0),
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func volumeCapability(
        id: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> String {
        let elements = [kAudioObjectPropertyElementMain, 1, 2]
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: scope,
                mElement: element
            )
            guard AudioObjectHasProperty(id, &address) else { continue }

            var settable: DarwinBoolean = false
            AudioObjectIsPropertySettable(id, &address, &settable)
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
                continue
            }
            return "element:\(element),value:\(String(format: "%.3f", value)),settable:\(settable.boolValue)"
        }
        return "unsupported"
    }

    private static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        id: AudioDeviceID
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard withUnsafeMutablePointer(to: &value, {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }) == noErr else { return nil }
        return value as String
    }

    private static func uint32Property(
        _ selector: AudioObjectPropertySelector,
        id: AudioDeviceID
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    private static func scopedBooleanProperty(
        _ selector: AudioObjectPropertySelector,
        id: AudioDeviceID,
        scope: AudioObjectPropertyScope
    ) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(id, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value != 0
    }

    private static func fourCC(_ value: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? String(value)
    }
}
