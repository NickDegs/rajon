import SwiftUI

@main
struct RajonApp: App {
    @StateObject private var game = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .tint(Theme.blood)
                .onAppear { game.bootstrap() }
        }
    }
}
