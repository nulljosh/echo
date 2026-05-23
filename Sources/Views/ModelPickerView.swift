import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: String
    let models: [String]
    let modelState: ModelState
    let onReload: () async -> Void

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(models, id: \.self) { model in
                    Button(displayName(model)) {
                        selectedModel = model
                        Task { await onReload() }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(displayName(selectedModel))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)

            statusChip
        }
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            switch modelState {
            case .loading:
                ProgressView().scaleEffect(0.7).tint(.white)
                Text("Loading")
            case .ready:
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Ready")
            case .error:
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Error")
            case .unloaded:
                Circle().fill(Color.gray).frame(width: 6, height: 6)
                Text("Unloaded")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(.white.opacity(0.5))
    }

    private func displayName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .capitalized
    }
}
