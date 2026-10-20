import SwiftUI

/// The one circle in the app. Blue to start, red with a square to stop.
struct RecordButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: 64, height: 64)
                if isTranscribing && isRecording {
                    ProgressView().tint(.white)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 20, height: 20)
                } else {
                    Image(systemName: "mic.fill").font(.echo(22, .medium)).foregroundStyle(.white)
                }
            }
            .animation(.easeOut(duration: 0.2), value: isRecording)
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(isRecording ? "Stop recording" : "Record")
    }
}

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
