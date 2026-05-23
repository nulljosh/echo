import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 72 + CGFloat(i * 22), height: 72 + CGFloat(i * 22))
                            .scaleEffect(pulse ? 1.0 : 0.85)
                            .opacity(pulse ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.4)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.35),
                                value: pulse
                            )
                    }
                }

                Circle()
                    .fill(isRecording ? Color.red : Color.primary)
                    .frame(width: 72, height: 72)

                if isTranscribing && isRecording {
                    ProgressView()
                        .tint(Color(.systemBackground))
                        .scaleEffect(0.85)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemBackground))
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color(.systemBackground))
                }
            }
        }
        .buttonStyle(SpringButtonStyle())
        .onAppear { pulse = isRecording }
        .onChange(of: isRecording) { _, newValue in pulse = newValue }
    }
}

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: configuration.isPressed)
    }
}
