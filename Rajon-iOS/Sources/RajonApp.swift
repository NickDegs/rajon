import SwiftUI

@main
struct RajonApp: App {
    @StateObject private var game = GameStore()
    @StateObject private var store = StoreManager()
    @StateObject private var online = OnlineService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(store)
                .environmentObject(online)
                .preferredColorScheme(.dark)
                .tint(Theme.blood)
                .onAppear {
                    game.bootstrap()
                    store.basla(game: game)
                }
        }
    }
}
