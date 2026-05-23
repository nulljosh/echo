import SwiftUI

struct SettingsView: View {
    @Binding var selectedModel: String
    @Binding var selectedLanguage: String
    let models: [String]
    let languages: [String]
    let modelState: ModelState
    let resolvedModel: String
    let onReload: () async -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Whisper Model") {
                    ForEach(models, id: \.self) { model in
                        Button {
                            if selectedModel != model {
                                selectedModel = model
                                Task { await onReload() }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(modelLabel(model))
                                        .foregroundStyle(.primary)
                                    Text(modelDescription(model))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedModel == model {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Language") {
                    ForEach(languages, id: \.self) { lang in
                        Button {
                            selectedLanguage = lang
                        } label: {
                            HStack {
                                Text(languageLabel(lang)).foregroundStyle(.primary)
                                Spacer()
                                if selectedLanguage == lang {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Status") {
                    HStack(spacing: 10) {
                        statusIndicator
                        Text(statusText).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch modelState {
        case .loading: ProgressView().scaleEffect(0.8)
        case .ready: Circle().fill(Color.green).frame(width: 8, height: 8)
        case .error: Circle().fill(Color.orange).frame(width: 8, height: 8)
        case .unloaded: Circle().fill(Color.secondary).frame(width: 8, height: 8)
        }
    }

    private var statusText: String {
        switch modelState {
        case .loading: return "Loading model..."
        case .ready: return "Ready"
        case .error(let msg): return msg
        case .unloaded: return "Not loaded"
        }
    }

    private func modelLabel(_ model: String) -> String {
        if model == "auto" { return "Auto" }
        return model.replacingOccurrences(of: "openai_whisper-", with: "").capitalized
    }

    private func modelDescription(_ model: String) -> String {
        let resolved = resolvedModel.replacingOccurrences(of: "openai_whisper-", with: "").lowercased()
        switch model {
        case "auto": return "Picks best for this device (currently \(resolved))"
        case "openai_whisper-tiny": return "Fastest · ~39 MB"
        case "openai_whisper-base": return "Balanced · ~150 MB"
        case "openai_whisper-small": return "Most accurate · ~500 MB"
        default: return ""
        }
    }

    private let languageNames: [String: String] = [
        "auto": "Auto-detect", "en": "English", "fr": "French", "es": "Spanish",
        "de": "German", "zh": "Chinese", "ja": "Japanese", "ko": "Korean",
        "ar": "Arabic", "pt": "Portuguese", "ru": "Russian", "it": "Italian"
    ]

    private func languageLabel(_ lang: String) -> String {
        languageNames[lang] ?? lang.uppercased()
    }
}
