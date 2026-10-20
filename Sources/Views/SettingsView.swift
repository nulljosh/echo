import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Binding var selectedModel: String
    @Binding var selectedLanguage: String
    @Binding var customWords: String
    let models: [String]
    let languages: [String]
    let modelState: ModelState
    let resolvedModel: String
    let onReload: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_theme") private var rawTheme = "system"

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    AppearancePicker(rawTheme: $rawTheme)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section("Speak-Back Voice") {
                    VoicePicker()
                }

                Section {
                    NavigationLink {
                        languagePicker
                    } label: {
                        HStack {
                            Text("Language")
                            Spacer()
                            Text(languageLabel(selectedLanguage)).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("Names, places, jargon", text: $customWords, axis: .vertical)
                        .lineLimit(1...4)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("custom-words")
                } header: {
                    Text("Custom Words")
                } footer: {
                    Text("Echo spells these your way. Separate them with commas.")
                }

                Section {
                    NavigationLink("Advanced") { modelPicker }
                }

                Section("Status") {
                    HStack(spacing: 10) {
                        statusIndicator
                        Text(statusText).foregroundStyle(.secondary)
                        Spacer()
                        if case .error = modelState {
                            Button("Retry") {
                                Task { await onReload() }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
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

    private var languagePicker: some View {
        let sorted = languages.filter { $0 != "auto" }.sorted { languageLabel($0) < languageLabel($1) }
        return List(["auto"] + sorted, id: \.self) { lang in
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
        .navigationTitle("Language")
    }

    // ponytail: Auto is right for nearly everyone, so the model list sits one level down
    private var modelPicker: some View {
        List {
            Section {
                ForEach(models, id: \.self) { model in
                    Button {
                        if selectedModel != model {
                            selectedModel = model
                            Task { await onReload() }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(modelLabel(model)).foregroundStyle(.primary)
                                Text(modelDescription(model))
                                    .font(.echo(12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedModel == model {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } footer: {
                Text("Auto picks the best model for this device. Bigger models are more accurate and slower.")
            }
        }
        .navigationTitle("Model")
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
        if model.contains("large") { return "Large" }
        return model.replacingOccurrences(of: "openai_whisper-", with: "").capitalized
    }

    private func modelDescription(_ model: String) -> String {
        let resolved = resolvedModel.replacingOccurrences(of: "openai_whisper-", with: "").lowercased()
        switch model {
        case "auto": return "Picks best for this device (currently \(resolved))"
        case "apple": return "Apple · files and Shortcuts, when installed"
        case "openai_whisper-tiny": return "Fastest · built in"
        case "openai_whisper-base": return "Balanced · built in"
        case "openai_whisper-small_216MB": return "Accurate · built in"
        case "openai_whisper-large-v3-v20240930_turbo_632MB": return "Most accurate · ~630 MB"
        default: return ""
        }
    }

    private func languageLabel(_ lang: String) -> String {
        if lang == "auto" { return "Auto-detect" }
        return Locale.current.localizedString(forLanguageCode: lang)?.capitalized ?? lang.uppercased()
    }
}

private struct VoicePicker: View {
    @AppStorage(SpeechManager.voiceIdentifierKey) private var selectedVoiceID = ""

    private var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") }
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) } // no Bahh, Boing or Bad News
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        ForEach(voices, id: \.identifier) { voice in
            Button {
                selectedVoiceID = voice.identifier
            } label: {
                HStack {
                    Text(voice.name).foregroundStyle(.primary)
                    Spacer()
                    if selectedVoiceID == voice.identifier {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
            }
        }
    }
}

private struct AppearancePicker: View {
    @Binding var rawTheme: String
    private let options = [("light", "Light"), ("dark", "Dark"), ("system", "System")]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(options, id: \.0) { id, label in
                Button { rawTheme = id } label: {
                    VStack(spacing: 8) {
                        themePreview(id)
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(rawTheme == id ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: 2)
                            )
                        Text(label)
                            .font(.echo(12, .medium))
                            .foregroundStyle(rawTheme == id ? Color.accentColor : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func themePreview(_ id: String) -> some View {
        switch id {
        case "light":
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.92))
        case "dark":
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.12))
        default:
            GeometryReader { geo in
                ZStack {
                    Color(white: 0.92)
                    Path { p in
                        p.move(to: CGPoint(x: geo.size.width, y: 0))
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        p.closeSubpath()
                    }.fill(Color(white: 0.12))
                }
            }
        }
    }
}
