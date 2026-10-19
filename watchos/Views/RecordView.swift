import SwiftUI

struct RecordView: View {
    @ObservedObject var store: RecordingStore

    var body: some View {
        VStack(spacing: 10) {
            Text("Notate")
                .font(.notate(17, .semibold))
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
                Text("Your iPhone writes it out")
                    .font(.notate(13))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Button(action: toggle) {
                ZStack {
                    Circle()
                        .fill(store.isRecording ? Color.red : Self.accent)
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
            "Notate",
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

    private static let accent = Color(red: 0, green: 0x74 / 255, blue: 0xD9 / 255) // brand blue #0074D9

    private var iconColor: Color { .white }

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
