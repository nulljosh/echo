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
    @StateObject private var speech = SpeechManager()
    @State private var showHistory = false
    @State private var inputMode: InputMode = .record
    @State private var exportFormat: Exporter.Format?
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
        .fileExporter(
            isPresented: Binding(get: { exportFormat != nil }, set: { if !$0 { exportFormat = nil } }),
            document: ExportFile(text: engine.currentEntry.map { Exporter.render($0, as: exportFormat ?? .text) } ?? ""),
            contentType: (exportFormat ?? .text).contentType,
            defaultFilename: "Echo \(Date().formatted(date: .abbreviated, time: .omitted)).\((exportFormat ?? .text).fileExtension)"
        ) { _ in exportFormat = nil }
        .sheet(item: Binding(get: { engine.summary.map(SummaryBox.init) }, set: { if $0 == nil { engine.summary = nil } })) { box in
            SummaryView(summary: box.summary)
        }
        .alert("Echo", isPresented: Binding(get: { engine.notice != nil }, set: { if !$0 { engine.notice = nil } })) {
            Button("OK") {}
        } message: {
            Text(engine.notice ?? "")
        }
        .task {
            #if os(iOS)
            WatchBridge.shared.engine = engine
            #endif
            if IntentInbox.takePendingStart() { engine.startRecording() } // launched by Shortcuts or the Action button
            await engine.loadModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: IntentInbox.startRecording)) { _ in
            if IntentInbox.takePendingStart(), !engine.isRecording { engine.startRecording() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                selectedModel: $engine.selectedModel,
                selectedLanguage: $engine.selectedLanguage,
                customWords: $engine.customWords,
                models: engine.availableModels,
                languages: engine.availableLanguages,
                modelState: engine.modelState,
                resolvedModel: engine.resolvedModel,
                onReload: { await engine.reloadModel() }
            )
        }
        .onOpenURL { url in
            inputMode = .file
            transcribe(url)
        }
    }

    private func transcribe(_ url: URL) {
        Task { await engine.transcribeFile(url: url) }
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
                        .font(.echo(22, .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry, speech: speech)
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
                Rectangle().fill(.thinMaterial).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.echo(13, .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry, speech: speech)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                transcriptionArea.padding(.horizontal, 20).padding(.top, 20)
                bottomBar.padding(.horizontal, 24).padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            // The controls live in the title bar next to the window title, one header instead of two.
            .toolbar { ToolbarItem(placement: .primaryAction) { topBar.padding(.horizontal, 6) } }
        }
        .navigationSplitViewStyle(.balanced)
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
            onRetry: retryAction,
            unusualLanguage: engine.isUnusualLanguage ? engine.detectedLanguage : nil,
            speech: speech
        )
    }

    private var fileDropZone: some View {
        ZStack {
            TranscriptionView(
                text: engine.transcribedText,
                modelState: engine.modelState,
                onRetry: retryAction,
                placeholder: "",
                speech: speech
            )

            if engine.isTranscribing {
                VStack(spacing: 10) {
                    ProgressView(value: engine.fileProgress)
                        .tint(.accentColor)
                        .frame(width: 160)
                    Text("Transcribing… \(Int(engine.fileProgress * 100))%")
                        .font(.echo(13))
                        .foregroundStyle(.secondary)
                }
            }

            if engine.transcribedText.isEmpty && !engine.isTranscribing {
                VStack(spacing: 12) {
                    Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                        .font(.echo(36))
                        .foregroundStyle(isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.interpolatingSpring(stiffness: 300, damping: 15), value: isDropTargeted)
                    Text(dropZoneLabel)
                        .font(.echo(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Browse Files") { showFilePicker = true }
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
            #if os(iOS)
            Text("Echo").font(.echo(17, .semibold)).foregroundStyle(.primary) // the Mac window title already says it
            #endif
            Spacer()
            statusDot
            Button { withAnimation(.easeOut(duration: 0.2)) { inputMode = .record } } label: {
                Image(systemName: "mic.fill")
                    .font(.echo(15, .medium))
                    .foregroundStyle(inputMode == .record ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .scaleEffect(inputMode == .record ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(engine.isRecording || engine.isTranscribing)
            Button { withAnimation(.easeOut(duration: 0.2)) { inputMode = .file } } label: {
                Image(systemName: "doc.fill")
                    .font(.echo(15, .medium))
                    .foregroundStyle(inputMode == .file ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .scaleEffect(inputMode == .file ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(engine.isRecording || engine.isTranscribing)
            #if os(macOS)
            // Meeting: also hear the call (what the Mac plays). No bot joins, nothing leaves the Mac.
            Button { engine.meetingMode.toggle() } label: {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.echo(15, .medium))
                    .foregroundStyle(engine.meetingMode ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .disabled(engine.isRecording)
            .help(engine.meetingMode ? "Meeting on: hears your mic and the call" : "Meeting off: hears your mic only")
            .accessibilityLabel(engine.meetingMode ? "Meeting mode on" : "Meeting mode off")
            #endif
            #if os(iOS)
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.echo(16, .medium))
                    .foregroundStyle(engine.entries.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }
            .buttonStyle(.plain)
            .disabled(engine.entries.isEmpty)
            .accessibilityIdentifier("history-button")
            #endif
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.echo(17, .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings-button")
        }
    }

    private var statusDot: some View {
        Group {
            switch engine.modelState {
            case .loading:
                ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
            case .ready:
                if let p = engine.upgradeProgress {
                    // Working on tiny while a more accurate model downloads. Never blocks recording.
                    ProgressView(value: p).progressViewStyle(.circular).scaleEffect(0.6).frame(width: 20, height: 20)
                        .help("Getting a more accurate model in the background")
                        .accessibilityLabel("Getting a more accurate model, \(Int(p * 100)) percent")
                } else {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                }
            case .error:
                Circle().fill(Color.orange).frame(width: 7, height: 7)
            case .unloaded:
                Circle().fill(Color.secondary).frame(width: 7, height: 7)
            }
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeOut(duration: 0.2), value: engine.modelState)
        .animation(.easeOut(duration: 0.2), value: engine.upgradeProgress == nil)
    }

    private var bottomBar: some View {
        HStack(spacing: 32) {
            if inputMode == .record {
                RecordButton(isRecording: engine.isRecording, isTranscribing: engine.isTranscribing) {
                    if engine.isRecording { Task { await engine.stopRecording() } }
                    else { engine.startRecording() }
                }
                .disabled(engine.modelState.isError) // never waits on a model
                #if os(macOS)
                .keyboardShortcut("r", modifiers: .command)
                #endif
            } else {
                fileActionButton
            }

            if Cleanup.isAvailable {
                Button { Task { await engine.cleanUp() } } label: {
                    if engine.isCleaning {
                        ProgressView().scaleEffect(0.8).frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.echo(20))
                            .foregroundStyle(engine.transcribedText.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                    }
                }
                .buttonStyle(.plain)
                .disabled(engine.transcribedText.isEmpty || engine.isRecording || engine.isTranscribing || engine.isCleaning)
                .help("Clean up punctuation, grammar and filler words, on device")
                .accessibilityLabel("Clean up transcript")
            }

            if Cleanup.isAvailable {
                Button { Task { await engine.summarize() } } label: {
                    if engine.isSummarizing {
                        ProgressView().scaleEffect(0.8).frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.echo(20))
                            .foregroundStyle(engine.transcribedText.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                    }
                }
                .buttonStyle(.plain)
                .disabled(engine.transcribedText.isEmpty || engine.isRecording || engine.isTranscribing || engine.isSummarizing)
                .help("Summary and action items, on device")
                .accessibilityLabel("Summarize transcript")
            }

            Menu {
                ShareLink("Share text", item: engine.transcribedText)
                Divider()
                ForEach(Exporter.Format.allCases) { format in
                    Button("Export \(format.rawValue)") { exportFormat = format }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.echo(20))
                    .foregroundStyle(engine.transcribedText.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(engine.transcribedText.isEmpty)
            .accessibilityLabel("Share or export")
        }
    }

    private var fileActionButton: some View {
        Button { showFilePicker = true } label: {
            ZStack {
                Circle().fill(Color.accentColor).frame(width: 56, height: 56)
                if engine.isTranscribing {
                    ProgressView().tint(Color.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "folder.fill")
                        .font(.echo(20, .medium))
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
