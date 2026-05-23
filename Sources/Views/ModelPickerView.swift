import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: String
    @Binding var selectedLanguage: String
    let models: [String]
    let languages: [String]
    let modelState: ModelState
    let onReload: () async -> Void

    var body: some View {
        HStack(spacing: 8) {
            modelMenu
            languageMenu
            statusChip
        }
    }

    private var modelMenu: some View {
        Menu {
            ForEach(models, id: \.self) { model in
                Button(modelLabel(model)) {
                    selectedModel = model
                    Task { await onReload() }
                }
            }
        } label: {
            pill(modelLabel(selectedModel))
        }
        .buttonStyle(.plain)
    }

    private var languageMenu: some View {
        Menu {
            ForEach(languages, id: \.self) { lang in
                Button(languageLabel(lang)) {
                    selectedLanguage = lang
                }
            }
        } label: {
            pill(languageLabel(selectedLanguage))
        }
        .buttonStyle(.plain)
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

    private func pill(_ label: String) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.primary.opacity(0.08), lineWidth: 1))
    }

    private func modelLabel(_ model: String) -> String {
        model.replacingOccurrences(of: "openai_whisper-", with: "").capitalized
    }

    private let languageNames: [String: String] = [
        "auto": "Auto", "en": "English", "fr": "French", "es": "Spanish",
        "de": "German", "zh": "Chinese", "ja": "Japanese", "ko": "Korean",
        "ar": "Arabic", "pt": "Portuguese", "ru": "Russian", "it": "Italian"
    ]

    private func languageLabel(_ lang: String) -> String {
        languageNames[lang] ?? lang.uppercased()
    }
}
