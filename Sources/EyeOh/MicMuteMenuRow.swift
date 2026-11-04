import SwiftUI

struct MicMuteMenuRow: View {
    let micMute: MicMuteController

    var body: some View {
        Group {
            Button {
                micMute.toggle()
            } label: {
                Label(
                    micMute.isSilenced ? "Unmute Microphone" : "Mute Microphone",
                    systemImage: micMute.isSilenced ? "mic.slash.fill" : "mic.fill"
                )
            }
            .disabled(!micMute.isSupported && !micMute.isSilenced)
            .accessibilityLabel(micMute.isSilenced ? "Unmute microphone" : "Mute microphone")

            if let message = micMute.errorMessage {
                Text(message)
                    .foregroundStyle(.red)
            } else if micMute.isDeviceMuted && !micMute.isMuted {
                Text("Muted by another app or in System Settings.")
                    .disabled(true)
            } else if !micMute.isSupported && !micMute.isMuted {
                Text("The current input device doesn't support muting from EyeOh.")
                    .disabled(true)
            }
        }
    }
}
