import SwiftUI

struct MicMuteMenuRow: View {
    let micMute: MicMuteController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                micMute.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: micMute.isSilenced ? "mic.slash.fill" : "mic.fill")
                        .foregroundStyle(micMute.isSilenced ? Color.red : DarkIceBrand.iceBlue)
                        .frame(width: 18)
                    Text(micMute.isMuted ? "Unmute Microphone" : (micMute.isDeviceMuted ? "Microphone Muted" : "Mute Microphone"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!micMute.isSupported && !micMute.isSilenced)
            .accessibilityLabel(micMute.isMuted ? "Unmute microphone" : "Mute microphone")

            if micMute.isDeviceMuted && !micMute.isMuted {
                HStack {
                    Text("Muted by another app or in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Unmute") { micMute.forceUnmute() }
                        .font(.caption)
                }
            } else if !micMute.isSupported && !micMute.isMuted {
                Text("The current input device doesn't support muting from EyeOh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let message = micMute.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
