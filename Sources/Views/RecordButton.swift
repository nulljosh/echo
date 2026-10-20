import SwiftUI

/// The record button: tinted glass, blue to start, red with a square to stop.
struct RecordButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isTranscribing && isRecording {
                    ProgressView().tint(.white)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 20, height: 20)
                } else {
                    Image(systemName: "mic.fill").font(.echo(22, .medium)).foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
            .fallbackCircle(isRecording ? .red : .accentColor)
            .animation(.easeOut(duration: 0.2), value: isRecording)
        }
        .glassCircle(tint: isRecording ? .red : .accentColor)
        .controlSize(.large)
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

extension View {
    /// Apple's glass button styles on iOS 26 and macOS 26, tinted for the one prominent control.
    @ViewBuilder
    func glassCircle(tint: Color? = nil) -> some View {
        if #available(iOS 26, macOS 26, *) {
            if let tint { buttonStyle(.glassProminent).buttonBorderShape(.circle).tint(tint) }
            else { buttonStyle(.glass).buttonBorderShape(.circle) }
        } else {
            buttonStyle(PressButtonStyle())
        }
    }

    /// The flat circle older systems draw behind a glassCircle label, padded to the same size.
    @ViewBuilder
    func fallbackCircle(_ fill: Color? = nil) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self
        } else if let fill {
            padding(8).background(fill, in: Circle())
        } else {
            padding(8).background(.quaternary, in: Circle())
        }
    }

    /// A real bottom bar: Apple's safeAreaBar on iOS and macOS 26 (glass, scroll edge effect), the system bar material before.
    @ViewBuilder
    func nativeBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, macOS 26, *) {
            safeAreaBar(edge: .bottom) { bar() }
        } else {
            safeAreaInset(edge: .bottom, spacing: 0) { bar().background(.bar) }
        }
    }

    /// A glass capsule behind a row of controls (a plain bar material before iOS and macOS 26).
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            background(.bar, in: Capsule())
        }
    }
}
