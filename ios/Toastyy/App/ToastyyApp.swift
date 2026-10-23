import SwiftUI

@main
struct ToastyyApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GameView(store: store)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in store.setActive(phase == .active) }
        }
    }
}
