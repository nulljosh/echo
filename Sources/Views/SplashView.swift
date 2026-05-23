import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 1.0
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.primary)
                Text("Echo")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.5)) { opacity = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDismiss() }
            }
        }
    }
}
