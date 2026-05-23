import SwiftUI

struct ContentView: View {
    @StateObject private var engine = TranscriptionEngine()
    @State private var showHistory = false

    var body: some View {
        #if os(iOS)
        iOSLayout
        #else
        macOSLayout
        #endif
    }

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                TranscriptionView(text: engine.transcribedText, modelState: engine.modelState)
                    .padding(.horizontal, 16)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
            }
        }
        .sheet(isPresented: $showHistory) {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task { await engine.loadModel() }
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    HistoryView(entries: engine.entries, onDelete: engine.deleteEntry)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    TranscriptionView(text: engine.transcribedText, modelState: engine.modelState)
                        .padding(.horizontal, 20)

                    bottomBar
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                }
            }
        }
        .task { await engine.loadModel() }
    }
    #endif

    // MARK: - Shared

    private var topBar: some View {
        HStack {
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("Echo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            ModelPickerView(
                selectedModel: $engine.selectedModel,
                models: engine.availableModels,
                modelState: engine.modelState,
                onReload: { await engine.reloadModel() }
            )
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 32) {
            Button {
                engine.copyToClipboard()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 20))
                    .foregroundColor(engine.transcribedText.isEmpty ? .white.opacity(0.2) : .white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(engine.transcribedText.isEmpty)

            RecordButton(
                isRecording: engine.isRecording,
                isTranscribing: engine.isTranscribing
            ) {
                if engine.isRecording {
                    Task { await engine.stopRecording() }
                } else {
                    engine.startRecording()
                }
            }
            .disabled(engine.modelState != .ready)

            #if os(iOS)
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(engine.entries.isEmpty ? .white.opacity(0.2) : .white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(engine.entries.isEmpty)
            #else
            Spacer().frame(width: 28)
            #endif
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
