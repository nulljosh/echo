import SwiftUI

@main
struct EchoApp: App {
    @AppStorage("app_theme") private var rawTheme = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(rawTheme == "dark" ? .dark : rawTheme == "light" ? .light : nil)
                .overlay { WhatsNewSheet() }
        }
    }
}
