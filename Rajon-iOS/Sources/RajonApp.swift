import SwiftUI

@main
struct RajonApp: App {
    @StateObject private var game = GameStore()
    @StateObject private var store = StoreManager()
    @StateObject private var online = OnlineService()
    @StateObject private var kozmetik = CosmeticStore()
    @StateObject private var tema = ThemeManager()

    @State private var splash = true

    // App Store görsel modu: `-shot <ekran>` argümanıyla açılırsa gerçek arayüzü demo veriyle gösterir.
    private var shotEkran: String? { UserDefaults.standard.string(forKey: "shot") }

    var body: some Scene {
        WindowGroup {
            if let ekran = shotEkran {
                ShotHostView(ekran: ekran)
                    .environmentObject(online)
                    .environmentObject(game)
                    .environmentObject(store)
                    .environmentObject(kozmetik)
                    .environmentObject(tema)
            } else {
            ZStack {
                RootView()
                    .environmentObject(game)
                    .environmentObject(store)
                    .environmentObject(online)
                    .environmentObject(kozmetik)
                    .environmentObject(tema)
                    .opacity(splash ? 0 : 1)

                if splash {
                    SplashView { withAnimation(.easeInOut(duration: 0.5)) { splash = false } }
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(tema.colorScheme)
            .tint(Theme.blood)
            .onAppear {
                game.bootstrap()
                store.basla(game: game)
                if AuthService.girisli {
                    game.bulutaYedek = { blob in Task { await online.durumYedekle(blob) } }
                }
            }
            }
        }
    }
}
