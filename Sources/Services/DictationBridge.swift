import Foundation

/// The Echo keyboard (v3.0) cannot use the microphone: iOS keeps keyboards off it. So the app records and writes,
/// and the keyboard only asks. They talk through the shared App Group: Darwin notifications for stop and "text ready",
/// and the group's defaults for the state and the finished text. The keyboard opens `url` to start a dictation.
enum DictationBridge {
    static let group = "group.com.nulljosh.echo"
    static let url = URL(string: "com.nulljosh.echo://dictate")!

    enum Signal: String {
        case stop, result
        var name: String { "com.nulljosh.echo.dictation.\(rawValue)" }
    }

    enum State: String { case idle, listening, writing }

    /// Swapped for a throwaway suite in tests, so they never touch the real app's state.
    static var defaults = UserDefaults(suiteName: group) ?? .standard

    static var state: State {
        get { State(rawValue: defaults.string(forKey: "dictation.state") ?? "") ?? .idle }
        set { defaults.set(newValue.rawValue, forKey: "dictation.state") }
    }

    /// App side: hands the finished text to the keyboard and tells it to look.
    static func publish(_ text: String) {
        defaults.set(text, forKey: "dictation.result")
        state = .idle
        post(.result)
    }

    /// Keyboard side: the finished text, once. A second call gets nil, so nothing is typed twice.
    static func takeResult() -> String? {
        guard let text = defaults.string(forKey: "dictation.result") else { return nil }
        defaults.removeObject(forKey: "dictation.result")
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
