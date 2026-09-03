import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecordingStore()

    var body: some View {
        TabView {
            RecordView(store: store)
            HistoryView(store: store)
        }
        .tabViewStyle(.verticalPage)
    }
}
