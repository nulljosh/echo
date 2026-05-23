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
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)

            statusChip
        }
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            switch modelState {
            case .loading:
                ProgressView().scaleEffect(0.7)
                Text("Loading")
            case .ready:
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Ready")
            case .error:
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Error")
            case .unloaded:
                Circle().fill(Color.secondary).frame(width: 6, height: 6)
                Text("Unloaded")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func displayName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .capitalized
    }
}
