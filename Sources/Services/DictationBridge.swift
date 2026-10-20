import Foundation

/// The Echo keyboard (v3.0) cannot use the microphone: iOS keeps keyboards off it. So the app records and writes,
/// and the keyboard only asks. Darwin notifications carry stop and "text ready"; the state and the finished text sit in
/// a Keychain group both targets hold, which needs no App Group. The keyboard opens `url` to start a dictation.
enum DictationBridge {
    static let group = "QMM486NPYC.com.nulljosh.echo.shared"
    static let url = URL(string: "com.nulljosh.echo://dictate")!

    enum Signal: String {
        case stop, result
        var name: String { "com.nulljosh.echo.dictation.\(rawValue)" }
    }

    enum State: String { case idle, listening, writing }

    /// Where the state and text live. Tests swap in a dictionary, so they never touch the real Keychain.
    static var store: (read: (String) -> String?, write: (String, String?) -> Void) = (
        { Keychain.read($0, group: group) },
        { key, value in
            if let value { Keychain.write(key, value, group: group) } else { Keychain.delete(key, group: group) }
        }
    )

    static var state: State {
        get { State(rawValue: store.read("dictation.state") ?? "") ?? .idle }
        set { store.write("dictation.state", newValue.rawValue) }
    }

    /// App side: hands the finished text to the keyboard and tells it to look.
    static func publish(_ text: String) {
        store.write("dictation.result", text)
        state = .idle
        post(.result)
    }

    /// Keyboard side: the finished text, once. A second call gets nil, so nothing is typed twice.
    static func takeResult() -> String? {
        guard let text = store.read("dictation.result") else { return nil }
        store.write("dictation.result", nil)
        return text
    }

    static func post(_ signal: Signal) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(signal.name as CFString), nil, nil, true)
    }

    private static var handlers: [String: () -> Void] = [:]

    /// Runs `handler` on the main queue whenever the other side posts `signal`. One handler per signal.
    static func observe(_ signal: Signal, _ handler: @escaping () -> Void) {
        if handlers.updateValue(handler, forKey: signal.name) != nil { return }
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, name, _, _ in
            guard let name = name?.rawValue as String? else { return }
            DispatchQueue.main.async { DictationBridge.handlers[name]?() }
        }, signal.name as CFString, nil, .deliverImmediately)
    }
}
