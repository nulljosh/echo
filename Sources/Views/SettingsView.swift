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
    @ObservedObject var account: Account
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_theme") private var rawTheme = "system"

    @AppStorage(SpeechManager.voiceIdentifierKey) private var voiceID = ""

    /// One row per voice and accent, at the best quality installed. A name that exists in two accents gets its region.
    private var voices: [(id: String, label: String)] {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        var best: [String: AVSpeechSynthesisVoice] = [:]
        for voice in AVSpeechSynthesisVoice.speechVoices()
        where voice.language.hasPrefix(language) && !voice.voiceTraits.contains(.isNoveltyVoice) { // no Bahh, Boing or Bad News
            let key = voice.name + "|" + voice.language
            if (best[key]?.quality.rawValue ?? 0) < voice.quality.rawValue { best[key] = voice }
        }
        let picked = best.values.sorted { ($0.name, $0.language) < ($1.name, $1.language) }
        let counts = Dictionary(grouping: picked, by: \.name).mapValues(\.count)
        return picked.map { voice in
            guard counts[voice.name, default: 1] > 1,
                  let region = Locale(identifier: voice.language).region?.identifier,
                  let place = Locale.current.localizedString(forRegionCode: region) else { return (voice.identifier, voice.name) }
            return (voice.identifier, "\(voice.name) (\(place))")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                AccountSection(account: account)

                Section {
                    Picker("Appearance", selection: $rawTheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    Picker("Speak-Back Voice", selection: $voiceID) {
                        Text("Default").tag("")
                        ForEach(voices, id: \.id) { Text($0.label).tag($0.id) }
                    }
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(["auto"] + languages.filter { $0 != "auto" }.sorted { languageLabel($0) < languageLabel($1) }, id: \.self) {
                            Text(languageLabel($0)).tag($0)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
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

                // ponytail: Auto is right for nearly everyone, so the model list sits one level down
                Section {
                    NavigationLink { modelPicker } label: {
                        LabeledContent("Model", value: modelLabel(selectedModel))
                    }
                    if case .error = modelState {
                        Button("Retry") { Task { await onReload() } }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 440)
        #endif
    }

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

    private func modelLabel(_ model: String) -> String {
        switch model {
        case "auto": return "Auto"
        case AppleSpeech.modelID: return "Apple"
        case let m where m.contains("large"): return "Large"
        case let m where m.contains("small"): return "Small"
        case let m where m.contains("base"): return "Base"
        case let m where m.contains("tiny"): return "Tiny"
        default: return model
        }
    }

    private func modelDescription(_ model: String) -> String {
        let resolved = resolvedModel.replacingOccurrences(of: "openai_whisper-", with: "").lowercased()
        switch model {
        case "auto": return AppleSpeech.isSupported ? "Apple's speech model first, Whisper \(resolved) for the rest" : "Picks best for this device (currently \(resolved))"
        case "apple": return "Apple's on-device speech model"
        case "openai_whisper-tiny": return "Fastest · built in"
        case "openai_whisper-base": return "Balanced · ~145 MB"
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
