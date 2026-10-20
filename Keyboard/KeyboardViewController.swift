import SwiftUI
import UIKit

/// Echo's keyboard: one big dictate key, plus space, delete, return and the globe, so it works as a keyboard even
/// without Full Access. It never touches the microphone (iOS keeps keyboards off it): dictate opens Echo, which records
/// in the background while you go back, and the finished text comes back here through DictationBridge.
final class KeyboardViewController: UIInputViewController {
    private let model = KeyboardModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        model.insert = { [weak self] text in
            guard let proxy = self?.textDocumentProxy else { return }
            let before = proxy.documentContextBeforeInput ?? ""
            let lead = before.isEmpty || before.last!.isWhitespace || text.first?.isWhitespace == true ? "" : " "
            proxy.insertText(lead + text)
        }
        model.type = { [weak self] in self?.textDocumentProxy.insertText($0) }
        model.delete = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        model.nextKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        model.openEcho = { [weak self] in self?.open(DictationBridge.url) ?? false }

        let host = UIHostingController(rootView: KeyboardView(model: model))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.heightAnchor.constraint(equalToConstant: 216),
        ])
        host.didMove(toParent: self)
        DictationBridge.observe(.result) { [weak self] in self?.model.refresh() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model.hasFullAccess = hasFullAccess
        model.showsGlobe = needsInputModeSwitchKey
        model.refresh()
    }

    /// Keyboards may not open URLs, so this walks the responder chain to the app and asks it.
    /// ponytail: the same route every dictation keyboard takes; if iOS closes it, the key says to open Echo instead.
    private func open(_ url: URL) -> Bool {
        let selector = sel_registerName("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let next = responder {
            if let app = next as? UIApplication, app.responds(to: selector) {
                typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?) -> Void
                unsafeBitCast(app.method(for: selector), to: Open.self)(app, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            responder = next.next
        }
        return false
    }
}

final class KeyboardModel: ObservableObject {
    @Published var state = DictationBridge.State.idle
    @Published var hasFullAccess = false
    @Published var showsGlobe = true
    @Published var hint: String?
    var insert: (String) -> Void = { _ in }
    var type: (String) -> Void = { _ in }
    var delete: () -> Void = {}
    var nextKeyboard: () -> Void = {}
    var openEcho: () -> Bool = { false }

    /// Types any text Echo finished while the keyboard was away, then shows where the dictation stands.
    func refresh() {
        guard hasFullAccess else { return }
        if let text = DictationBridge.takeResult()?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { insert(text) }
        state = DictationBridge.state
    }

    func dictate() {
        switch state {
        case .idle: hint = openEcho() ? nil : "Open Echo, tap record, then come back."
        case .listening: state = .writing; DictationBridge.post(.stop)
        case .writing: break
        }
    }
}

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    private let accent = Color(red: 0, green: 0.455, blue: 0.851)

    var body: some View {
        VStack(spacing: 8) {
            Button(action: model.dictate) {
                HStack(spacing: 8) {
                    if model.state == .writing { ProgressView().tint(.white) } else { Image(systemName: model.state == .listening ? "stop.fill" : "mic.fill") }
                    Text(title)
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(accent.opacity(model.hasFullAccess ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!model.hasFullAccess || model.state == .writing)
            .accessibilityIdentifier("dictate")

            if let note = model.hasFullAccess ? model.hint : "To dictate, turn on Allow Full Access for Echo in Settings, General, Keyboard." {
                Text(note).font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            HStack(spacing: 6) {
                if model.showsGlobe { key(Image(systemName: "globe"), label: "Next keyboard", action: model.nextKeyboard) }
                key(Text("space"), label: "Space") { model.type(" ") }.frame(maxWidth: .infinity)
                key(Image(systemName: "delete.left"), label: "Delete", action: model.delete)
                key(Image(systemName: "return"), label: "Return") { model.type("\n") }
            }
            .frame(height: 44)
        }
        .padding(8)
    }

    private var title: String {
        switch model.state {
        case .idle: "Dictate with Echo"
        case .listening: "Tap when you are done"
        case .writing: "Writing"
        }
    }

    private func key(_ content: some View, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            content
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .frame(minWidth: 44, maxWidth: label == "Space" ? .infinity : 56, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(label)
    }
}
