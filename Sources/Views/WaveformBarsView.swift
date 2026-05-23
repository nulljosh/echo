import SwiftUI

struct WaveformBarsView: View {
    let level: Float

    @State private var heights: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.primary.opacity(0.5))
                    .frame(width: 4, height: heights[i] * 48)
            }
        }
        .onChange(of: level) { _, new in
            withAnimation(.easeInOut(duration: 0.1)) {
                heights = (0..<5).map { _ in
                    CGFloat(max(0.12, min(1.0, Float.random(in: max(0, new - 0.25)...min(1, new + 0.25)))))
                }
            }
        }
    }
}
