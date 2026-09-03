import SwiftUI

/// A compact 5-bar level meter, the watch-sized counterpart to the iPhone
/// app's `WaveformBarsView`.
struct WaveformBarsView: View {
    let level: Float

    @State private var heights: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.red.opacity(0.7))
                    .frame(width: 3, height: heights[i] * 32)
            }
        }
        .frame(height: 32)
        .onChange(of: level) { _, new in
            withAnimation(.easeInOut(duration: 0.1)) {
                heights = (0..<5).map { _ in
                    CGFloat(max(0.12, min(1.0, Float.random(in: max(0, new - 0.25)...min(1, new + 0.25)))))
                }
            }
        }
    }
}
