import SwiftUI

@main
struct EchoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
