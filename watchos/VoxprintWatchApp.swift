import SwiftUI
import CoreText

@main
struct VoxprintWatchApp: App {
    // ponytail: the watch Info.plist is generated, so register Echo Sans here instead of UIAppFonts
    init() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
