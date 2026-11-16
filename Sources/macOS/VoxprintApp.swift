import Carbon.HIToolbox
import SwiftUI

@main
struct VoxprintApp: App {
    @AppStorage("app_theme") private var rawTheme = "system"

    init() { HotKey.register() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 560)
                .preferredColorScheme(rawTheme == "dark" ? .dark : rawTheme == "light" ? .light : nil)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Control-Shift-Space from any app. Carbon hot keys work in the sandbox and need no Accessibility prompt.
/// Not Control-Option-Space: macOS uses it by default for the next input source.
/// ponytail: fixed shortcut, add a recorder in Settings if someone asks to change it.
@MainActor
enum HotKey {
    static let pressed = Notification.Name("echo.hotkey")
    /// True while a window is up to hear the press. Closing the window tears its recorder down.
    static var isLive = false
    static var onPress = { // swapped by the test
        if isLive { NotificationCenter.default.post(name: pressed, object: nil); return }
        // No window: relaunching our own bundle is a reopen, SwiftUI opens a window, and it starts recording on appear.
        IntentInbox.pendingStart = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration())
    }
    private(set) static var status: OSStatus = -1
    private static var ref: EventHotKeyRef?

    static func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            MainActor.assumeIsolated { HotKey.onPress() } // the application event target fires on the main thread
            return noErr
        }, 1, &spec, nil, nil)
        status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | shiftKey), EventHotKeyID(signature: OSType(0x4543484F), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}
