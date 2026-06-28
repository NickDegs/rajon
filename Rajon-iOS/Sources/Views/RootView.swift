import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var online: OnlineService
    @State private var tab = 0
    @State private var magazaAcik = false
    @State private var ayarAcik = false

    var body: some View {
        // Uygulama TAMAMEN ONLINE — her zaman sunucu-otoriter canlı dünya (Travian gibi).
        OnlineWorldView()
    }

    private var offlineRoot: some View {
        ZStack {
            Theme.bg
            VStack(spacing: 0) {
                TopBar(magazaAcik: $magazaAcik, ayarAcik: $ayarAcik)
                TabView(selection: $tab) {
                    UsView()
                        .tag(0)
                        .tabItem { Label("Üs", systemImage: "building.2.fill") }
                    EkipView()
                        .tag(1)
                        .tabItem { Label("Ekip", systemImage: "person.3.fill") }
                    SokakView()
                        .tag(2)
                        .tabItem { Label("Sokak", systemImage: "map.fill") }
                    DevsirView()
                        .tag(3)
                        .tabItem { Label("Devşir", systemImage: "dice.fill") }
                    OnlineView()
                        .tag(4)
                        .tabItem { Label("Online", systemImage: "globe") }
                }
                .tint(Theme.blood)
            }
        }
        .sheet(isPresented: $magazaAcik) {
            NavigationStack {
                MagazaView()
                    .navigationTitle("Mağaza")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Kapat") { magazaAcik = false }
                        }
                    }
                    .background(Theme.coal)
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $ayarAcik) {
            NavigationStack {
                AyarlarView()
                    .navigationTitle("Ayarlar")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Kapat") { ayarAcik = false }
                        }
                    }
                    .background(Theme.coal)
            }
            .preferredColorScheme(.dark)
        }
    }
}

/// Üstte sabit para / itibar / seviye barı.
struct TopBar: View {
    @EnvironmentObject var game: GameStore
    @Binding var magazaAcik: Bool
    @Binding var ayarAcik: Bool

    var body: some View {
        HStack(spacing: 10) {
            statChip(icon: "dollarsign.circle.fill", value: fmt(game.cash), tint: Theme.gold)
            statChip(icon: "circle.hexagongrid.fill", value: fmt(game.cephane), tint: Theme.smoke)
            statChip(icon: "flame.fill", value: fmt(game.respect), tint: Theme.blood)
            Spacer()
            Button { magazaAcik = true } label: {
                Image(systemName: "cart.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
            }
            Button { ayarAcik = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 16)).foregroundStyle(Theme.smoke)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text("Sv. \(game.bossLevel)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.coal)
    }

    private func statChip(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Ortak bileşenler

/// Can barı.
struct HealthBar: View {
    var hp: Int
    var maxHP: Int
    var color: Color = Theme.blood

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.5))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, hp)) / CGFloat(max(1, maxHP)))
                    .animation(.easeOut(duration: 0.25), value: hp)
            }
        }
        .frame(height: 7)
    }
}

/// Nadirlik rozeti.
struct RarityTag: View {
    var rarity: Rarity
    var body: some View {
        Text(rarity.label.uppercased())
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(rarity.color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(rarity.color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(rarity.color.opacity(0.5), lineWidth: 1))
    }
}

/// Adam avatar dairesi (Flux sınıf portresi + nadirlik halkası).
struct AvatarCircle: View {
    var enforcer: Enforcer
    var size: CGFloat = 52
    var body: some View {
        Image(enforcer.klas.gorsel)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(Theme.panelHi)
            .clipShape(Circle())
            .overlay(Circle().stroke(enforcer.rarity.color, lineWidth: 2.5))
    }
}
