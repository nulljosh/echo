import SwiftUI

struct RecordView: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        VStack(spacing: 10) {
            Text("Voxprint")
                .font(.headline)
                .foregroundStyle(.secondary)

            if store.isRecording {
                Text(formattedElapsed)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                WaveformBarsView(level: store.level)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("Recorded on device. Nothing leaves your watch.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button(action: toggle) {
                ZStack {
                    Circle()
                        .fill(store.isRecording ? Color.red : Color.primary)
                        .frame(width: 52, height: 52)
                    if store.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(iconColor)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .alert(
            "Voxprint",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var iconColor: Color {
        Color.black
    }

    private var formattedElapsed: String {
        let s = Int(store.elapsed)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func toggle() {
        if store.isRecording {
            store.stopRecording()
        } else {
            store.startRecording()
        }
    }
}
