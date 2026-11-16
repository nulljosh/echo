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
enum HotKey {
    static let pressed = Notification.Name("echo.hotkey")
    static var onPress = { NotificationCenter.default.post(name: pressed, object: nil) } // swapped by the test
    private(set) static var status: OSStatus = -1
    private static var ref: EventHotKeyRef?

    static func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.onPress()
            return noErr
        }, 1, &spec, nil, nil)
        status = RegisterEventHotKey(UInt32(kVK_Space), UInt32(controlKey | shiftKey), EventHotKeyID(signature: OSType(0x4543484F), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}
