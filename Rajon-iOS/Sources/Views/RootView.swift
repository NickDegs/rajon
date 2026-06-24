import SwiftUI

struct RootView: View {
    @EnvironmentObject var game: GameStore
    @State private var tab = 0

    var body: some View {
        ZStack {
            Theme.bg
            VStack(spacing: 0) {
                TopBar()
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
                }
                .tint(Theme.blood)
            }
        }
    }
}

/// Üstte sabit para / itibar / seviye barı.
struct TopBar: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        HStack(spacing: 14) {
            statChip(icon: "dollarsign.circle.fill", value: fmt(game.cash), tint: Theme.gold)
            statChip(icon: "flame.fill", value: fmt(game.respect), tint: Theme.blood)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("PATRON")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.smoke)
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

/// Adam avatar dairesi (sınıf ikonu + nadirlik halkası).
struct AvatarCircle: View {
    var enforcer: Enforcer
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            Circle().fill(Theme.panelHi)
            Image(systemName: enforcer.klas.icon)
                .font(.system(size: size * 0.42))
                .foregroundStyle(enforcer.rarity.color)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(enforcer.rarity.color, lineWidth: 2))
    }
}
