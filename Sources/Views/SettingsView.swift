import SwiftUI

struct SettingsView: View {
    @Binding var selectedModel: String
    @Binding var selectedLanguage: String
    let models: [String]
    let languages: [String]
    let modelState: ModelState
    let resolvedModel: String
    @ObservedObject var store: StoreManager
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

                Section("Whisper Model") {
                    ForEach(models, id: \.self) { model in
                        Button {
                            if store.isModelLocked(model) {
                                store.showPaywall = true
                            } else if selectedModel != model {
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
                                if store.isModelLocked(model) {
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                                } else if selectedModel == model {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Echo Pro") {
                    if store.isPro {
                        Label("Unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.primary)
                    } else {
                        Button {
                            store.showPaywall = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Echo Pro").foregroundStyle(.primary)
                                    Text("\(store.freeFilesRemaining) free file transcriptions left")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        Button("Restore Purchase") { Task { await store.restore() } }
                            .foregroundStyle(.secondary)
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
                            .font(.caption.weight(.medium))
                            .foregroundStyle(rawTheme == id ? .accentColor : .secondary)
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
