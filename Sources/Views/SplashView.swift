import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 1.0
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            #if os(iOS)
            Color(.systemBackground).ignoresSafeArea()
            #else
            Color(.windowBackgroundColor).ignoresSafeArea()
            #endif
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.echo(56, .light))
                    .foregroundStyle(.tint)
                Text("Echo")
                    .font(.echo(28, .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        }
    }
}
