import SwiftUI

@main
struct RajonApp: App {
    @StateObject private var game = GameStore()
    @StateObject private var store = StoreManager()
    @StateObject private var online = OnlineService()

    @State private var splash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(game)
                    .environmentObject(store)
                    .environmentObject(online)
                    .opacity(splash ? 0 : 1)

                if splash {
                    SplashView { withAnimation(.easeInOut(duration: 0.5)) { splash = false } }
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.blood)
            .onAppear {
                game.bootstrap()
                store.basla(game: game)
            }
        }
    }
}
