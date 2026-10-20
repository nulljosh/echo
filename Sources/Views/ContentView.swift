import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private static let liveID = UUID()

    @StateObject private var engine = TranscriptionEngine()
    @StateObject private var speech = SpeechManager()
    @StateObject private var account = Account()
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showFilePicker = false
    @State private var importing = false
    @State private var isDropTargeted = false
    @State private var exportFormat: Exporter.Format?
    #if os(macOS)
    @State private var columns: NavigationSplitViewVisibility = .detailOnly // History starts tucked away; the toolbar button opens it
    #endif

    var body: some View {
        layout
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: Self.audioTypes, allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first { transcribe(url) }
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
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    selectedModel: $engine.selectedModel,
                    selectedLanguage: $engine.selectedLanguage,
                    customWords: $engine.customWords,
                    models: engine.availableModels,
                    languages: engine.availableLanguages,
                    modelState: engine.modelState,
                    resolvedModel: engine.resolvedModel,
                    onReload: { await engine.reloadModel() },
                    account: account
                )
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
                if CommandLine.arguments.contains("-ECHO_DEMO"), // promo footage, see TranscriptionEngine.runDemo
                   let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    try? await Task.sleep(for: .seconds(1.5))
                    await engine.runDemo(docs.appendingPathComponent("demo.wav"))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: IntentInbox.startRecording)) { _ in
                if IntentInbox.takePendingStart(), !engine.isRecording { engine.startRecording() }
            }
            .onOpenURL { transcribe($0) }
    }

    private func transcribe(_ url: URL) {
        Task {
            importing = true
            await engine.transcribeFile(url: url)
            importing = false
        }
    }

    // MARK: - Layouts

    #if os(iOS)
    private var layout: some View {
        NavigationStack {
            transcript
                .safeAreaInset(edge: .bottom) {
                    // Record is dead centre; Settings sits at the leading edge of the same row.
                    recordButton
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .leading) {
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape").font(.echo(22)).frame(width: 32, height: 32).fallbackCircle()
                            }
                            .glassCircle()
                            .accessibilityLabel("Settings")
                            .accessibilityIdentifier("settings-button")
                        }
                        .padding(.horizontal, 20).padding(.vertical, 16)
                }
                .navigationTitle("Echo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showHistory = true } label: { Label("History", systemImage: "clock") }
                            .disabled(engine.entries.isEmpty)
                            .accessibilityIdentifier("history-button")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        upgradeRing
                        shareMenu
                        moreMenu
                    }
                }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryView(entries: engine.entries, onDelete: engine.deleteEntry, speech: speech)
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHistory = false } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
    #else
    private var layout: some View {
        NavigationSplitView(columnVisibility: $columns) {
            HistoryView(entries: engine.entries, onDelete: engine.deleteEntry, speech: speech)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            transcript
                .safeAreaInset(edge: .bottom) { macBar }
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor, lineWidth: 2).padding(8)
                    }
                }
                .onDrop(of: Self.audioTypes, isTargeted: $isDropTargeted) { handleDrop(providers: $0) }
                .toolbar { ToolbarItem(placement: .primaryAction) { upgradeRing } }
        }
    }

    /// The Mac's bottom bar, same shape as the iPhone's: Settings and Meeting left, record dead centre, Share and More right.
    private var macBar: some View {
        recordButton
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                HStack(spacing: 12) {
                    barButton("gearshape", label: "Settings") { showSettings = true }
                        .accessibilityIdentifier("settings-button")
                    // Meeting: also hear the call (what the Mac plays). No bot joins, nothing leaves the Mac.
                    barButton(engine.meetingMode ? "person.2.wave.2.fill" : "person.2.wave.2", label: engine.meetingMode ? "Meeting on" : "Meeting off") {
                        engine.meetingMode.toggle()
                    }
                    .foregroundStyle(engine.meetingMode ? Color.accentColor : Color.primary)
                    .disabled(engine.isRecording)
                    .help(engine.meetingMode ? "Meeting on: hears your mic and the call" : "Meeting off: hears your mic only")
                }
            }
            .overlay(alignment: .trailing) {
                HStack(spacing: 12) {
                    barMenu("square.and.arrow.up", label: "Share or export") { shareItems }
                        .disabled(engine.transcribedText.isEmpty)
                    barMenu(engine.isCleaning || engine.isSummarizing ? "hourglass" : "ellipsis", label: "More") { moreItems }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
    }

    /// A menu that looks exactly like a bar button (menus take a button style only as a button-style menu).
    private func barMenu<Items: View>(_ symbol: String, label: String, @ViewBuilder items: () -> Items) -> some View {
        Menu(content: items) {
            Image(systemName: symbol).font(.echo(17)).frame(width: 32, height: 32).fallbackCircle()
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .glassCircle()
        .accessibilityLabel(label)
    }

    private func barButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.echo(17)).frame(width: 32, height: 32).fallbackCircle()
        }
        .glassCircle()
        .accessibilityLabel(label)
    }
    #endif

    // MARK: - Shared

    private var transcript: some View {
        TranscriptionView(
            text: engine.transcribedText,
            modelState: engine.modelState,
            isRecording: engine.isRecording,
            audioLevel: engine.audioLevel,
            onRetry: { Task { await engine.reloadModel() } },
            unusualLanguage: engine.isUnusualLanguage ? engine.detectedLanguage : nil
        )
        .overlay {
            if importing && engine.transcribedText.isEmpty {
                VStack(spacing: 12) {
                    ProgressView(value: engine.fileProgress).frame(width: 160)
                    Text("Transcribing \(Int(engine.fileProgress * 100))%")
                        .font(.echo(13))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    /// Working on tiny while a more accurate model downloads. Never blocks recording.
    @ViewBuilder
    private var upgradeRing: some View {
        if let p = engine.upgradeProgress {
            ProgressView(value: p).progressViewStyle(.circular).controlSize(.small)
                .help("Getting a more accurate model in the background")
                .accessibilityLabel("Getting a more accurate model, \(Int(p * 100)) percent")
        }
    }

    /// The main thing on screen to press. Share and More live in the bar.
    private var recordButton: some View {
        RecordButton(isRecording: engine.isRecording, isTranscribing: engine.isTranscribing) {
            if engine.isRecording { Task { await engine.stopRecording() } }
            else { engine.startRecording() }
        }
        .disabled(engine.modelState.isError || importing) // never waits on a model
        #if os(macOS)
        .keyboardShortcut("r", modifiers: .command)
        #endif
    }

    private var busy: Bool { engine.isRecording || importing || engine.isCleaning || engine.isSummarizing }

    @ViewBuilder
    private var shareItems: some View {
        ShareLink("Share", item: engine.transcribedText)
        Divider()
        ForEach(Exporter.Format.allCases) { format in
            Button("Export \(format.rawValue)") { exportFormat = format }
        }
    }

    private var shareMenu: some View {
        Menu { shareItems } label: { Label("Share", systemImage: "square.and.arrow.up") }
            .menuIndicator(.hidden)
            .disabled(engine.transcribedText.isEmpty)
    }

    @ViewBuilder
    private var moreItems: some View {
        let empty = engine.transcribedText.isEmpty
        if Cleanup.isAvailable {
            Button { Task { await engine.cleanUp() } } label: { Label("Clean Up", systemImage: "wand.and.stars") }
                .disabled(empty || busy)
            Button { Task { await engine.summarize() } } label: { Label("Summarize", systemImage: "list.bullet.rectangle") }
                .disabled(empty || busy)
        }
        Button {
            speech.toggle(id: Self.liveID, text: engine.transcribedText, languageCode: engine.isUnusualLanguage ? engine.detectedLanguage : nil)
        } label: {
            speech.speakingID == Self.liveID
                ? Label("Stop Reading", systemImage: "stop")
                : Label("Read Aloud", systemImage: "speaker.wave.2")
        }
        .disabled(empty)
        Divider()
        Button { showFilePicker = true } label: { Label("Transcribe a File", systemImage: "doc") }
            .disabled(engine.modelState != .ready || busy)
    }

    private var moreMenu: some View {
        Menu { moreItems } label: {
            if engine.isCleaning || engine.isSummarizing {
                ProgressView().controlSize(.small)
            } else {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .menuIndicator(.hidden)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            .accessibilityIdentifier("settings-button")
    }

    private static let audioTypes: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio].compactMap { $0 }

    #if os(macOS)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, _ in
            guard let url else { return }
            // A fresh name each drop: a reused name would fail to copy and transcribe the older file.
            let local = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: local)
            Task { @MainActor in transcribe(local) }
        }
        return true
    }
    #endif
}
