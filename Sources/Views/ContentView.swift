import SwiftUI
import UniformTypeIdentifiers

enum InputMode: String, CaseIterable {
    case record = "Record"
    case file = "File"

    var icon: String {
        switch self {
        case .record: return "mic.fill"
        case .file: return "doc.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var engine = TranscriptionEngine()
    @StateObject private var store = StoreManager()
    @State private var showHistory = false
    @State private var inputMode: InputMode = .record
    @State private var showFilePicker = false
    @State private var isDropTargeted = false
    @State private var showSplash = true
    @State private var showSettings = false

    var body: some View {
        ZStack {
            #if os(iOS)
            iOSLayout
            #else
            macOSLayout
            #endif
            if showSplash {
                SplashView { showSplash = false }
            }
        }
        .task {
            await engine.loadModel()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                selectedModel: $engine.selectedModel,
                selectedLanguage: $engine.selectedLanguage,
                models: engine.availableModels,
                languages: engine.availableLanguages,
                modelState: engine.modelState,
                resolvedModel: engine.resolvedModel,
                store: store,
                onReload: { await engine.reloadModel() }
            )
        }
        .sheet(isPresented: $store.showPaywall) {
            PaywallView(store: store)
        }
    }

    /// File transcription is the paid workflow. Allow it while free runs remain or Pro
    /// is owned, otherwise surface the paywall instead of starting the picker.
    private func requestFile() {
        if store.canTranscribeFile() {
            showFilePicker = true
        } else {
            store.showPaywall = true
        }
    }

    /// Runs the transcription, then consumes a free run only if it actually produced text.
    private func transcribe(_ url: URL) {
        Task {
            await engine.transcribeFile(url: url)
            let out = engine.transcribedText
            if !out.isEmpty && !out.hasPrefix("Transcription failed") {
                store.recordFileTranscription()
            }
        }
    }

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
                transcriptionArea
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .sheet(isPresented: $showHistory) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: Self.audioTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                transcribe(url)
            }
        }
        .task { await engine.loadModel() }
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            ZStack {
                Color(.windowBackgroundColor).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            ZStack {
                Color(.windowBackgroundColor).ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
                    transcriptionArea.padding(.horizontal, 20)
                    bottomBar.padding(.horizontal, 24).padding(.vertical, 20)
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: Self.audioTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                transcribe(url)
            }
        }
        .task { await engine.loadModel() }
    }
    #endif

    // MARK: - Shared subviews

    @ViewBuilder
    private var transcriptionArea: some View {
        if inputMode == .file {
            fileDropZone
        } else {
            mainTranscriptionView
        }
    }

    private var mainTranscriptionView: some View {
        TranscriptionView(
            text: engine.transcribedText,
            modelState: engine.modelState,
            isRecording: engine.isRecording,
            audioLevel: engine.audioLevel,
            onRetry: retryAction
        )
    }

    private var fileDropZone: some View {
        ZStack {
            TranscriptionView(
                text: engine.transcribedText,
                modelState: engine.modelState,
                onRetry: retryAction,
                placeholder: ""
            )

            if engine.transcribedText.isEmpty && !engine.isTranscribing {
                VStack(spacing: 12) {
                    Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                        .font(.system(size: 36))
                        .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isDropTargeted)
                    Text(dropZoneLabel)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Browse Files") { requestFile() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(engine.modelState != .ready)
                }
                .padding()
            }
        }
        #if os(macOS)
        .onDrop(of: Self.audioTypes, isTargeted: $isDropTargeted) { handleDrop(providers: $0) }
        #endif
    }

    private var dropZoneLabel: String {
        #if os(macOS)
        return "Drop an audio file here, or browse"
        #else
        return "Browse for an audio file to transcribe"
        #endif
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Echo").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
            Spacer()
            statusDot
            Button { inputMode = .record } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(inputMode == .record ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(engine.isRecording || engine.isTranscribing)
            Button { inputMode = .file } label: {
                Image(systemName: "doc.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(inputMode == .file ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(engine.isRecording || engine.isTranscribing)
            #if os(iOS)
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(engine.entries.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .disabled(engine.entries.isEmpty)
            #endif
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        switch engine.modelState {
        case .loading:
            ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
        case .ready:
            Circle().fill(Color.green).frame(width: 7, height: 7)
        case .error:
            Circle().fill(Color.orange).frame(width: 7, height: 7)
        case .unloaded:
            Circle().fill(Color.secondary).frame(width: 7, height: 7)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 32) {
            if inputMode == .record {
                RecordButton(isRecording: engine.isRecording, isTranscribing: engine.isTranscribing) {
                    if engine.isRecording { Task { await engine.stopRecording() } }
                    else { engine.startRecording() }
                }
                .disabled(engine.modelState != .ready)
                #if os(macOS)
                .keyboardShortcut("r", modifiers: .command)
                #endif
            } else {
                fileActionButton
            }

            ShareLink(item: engine.transcribedText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                    .foregroundStyle(engine.transcribedText.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .disabled(engine.transcribedText.isEmpty)
        }
    }

    private var fileActionButton: some View {
        Button { requestFile() } label: {
            ZStack {
                Circle().fill(Color.primary).frame(width: 56, height: 56)
                if engine.isTranscribing {
                    ProgressView().tint(Color.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(SpringButtonStyle())
        .disabled(engine.modelState != .ready || engine.isTranscribing)
    }

    // MARK: - Helpers

    private func retryAction() { Task { await engine.reloadModel() } }

    private static let audioTypes: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio].compactMap { $0 }

    #if os(macOS)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard store.canTranscribeFile() else { store.showPaywall = true; return false }
        guard let provider = providers.first else { return false }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, _ in
            guard let url else { return }
            let local = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: local)
            Task { @MainActor in transcribe(local) }
        }
        return true
    }
    #endif
}
