import SwiftUI

/// Ekip yönetimi — sahadaki kadro + tüm adamlar, yükseltme.
struct EkipView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sahaKart
                Text("BÜTÜN ADAMLARIN (\(game.crew.count))")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                ForEach(sortedCrew) { e in
                    EnforcerRow(enforcer: e)
                }
            }
            .padding(16)
        }
    }

    private var sortedCrew: [Enforcer] {
        game.crew.sorted {
            if $0.rarity != $1.rarity { return $0.rarity > $1.rarity }
            return $0.guc > $1.guc
        }
    }

    private var sahaKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SAHADAKİ EKİP")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.smoke)
                Spacer()
                Text("Güç \(fmt(game.squadPower))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.gold)
            }
            HStack(spacing: 10) {
                ForEach(0..<game.maxKadro, id: \.self) { i in
                    if i < game.squadEnforcers.count {
                        let e = game.squadEnforcers[i]
                        VStack(spacing: 4) {
                            AvatarCircle(enforcer: e, size: 50)
                            Text(e.ad.split(separator: " ").last.map(String.init) ?? e.ad)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 4) {
                            Circle().stroke(Theme.smoke.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [4]))
                                .frame(width: 50, height: 50)
                                .overlay(Image(systemName: "plus").foregroundStyle(Theme.smoke.opacity(0.5)))
                            Text("boş").font(.system(size: 9)).foregroundStyle(Theme.smoke)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            Text("Sahaya en fazla 4 adam çıkar. Aşağıdan seç.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.smoke)
        }
        .cardStyle(16)
    }
}

struct EnforcerRow: View {
    @EnvironmentObject var game: GameStore
    let enforcer: Enforcer
    @State private var gearSheet = false

    private var sahada: Bool { game.squad.contains(enforcer.id) }
    /// Bu adamın güncel hali (envanterden tak/çıkar sonrası tazelensin).
    private var current: Enforcer { game.crew.first { $0.id == enforcer.id } ?? enforcer }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                AvatarCircle(enforcer: enforcer, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(enforcer.ad)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        RarityTag(rarity: enforcer.rarity)
                    }
                    Text("\(enforcer.klas.label) · Sv. \(enforcer.level) · Güç \(fmt(enforcer.guc))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.smoke)
                    // XP barı
                    HealthBar(hp: enforcer.xp, maxHP: enforcer.xpToNext, color: Theme.gold.opacity(0.8))
                        .frame(height: 5)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                statMini("CAN", fmt(current.maxHP), "heart.fill")
                statMini("VURUŞ", fmt(current.atk), "burst.fill")
                statMini("HIZ", "\(current.spd)", "hare.fill")
            }
            // Takılı teçhizat / tak butonu
            Button { gearSheet = true } label: {
                HStack(spacing: 8) {
                    if let g = current.equippedGear {
                        Image(systemName: g.ikon).font(.system(size: 13)).foregroundStyle(g.rarity.color)
                        Text(g.ad).font(.system(size: 12, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                        Text("+\(g.atkBonus) vuruş").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.gold)
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                        Text("Teçhizat tak").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                Button {
                    game.toggleSquad(enforcer.id)
                } label: {
                    Text(sahada ? "SAHADAN ÇEK" : "SAHAYA AL")
                        .font(.system(size: 12, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(sahada ? Theme.panelHi : Theme.bloodDim)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                Button {
                    game.adamYukselt(enforcer.id)
                } label: {
                    let f = game.yukseltMaliyet(current)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("₺\(fmt(f))").font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .font(.system(size: 12, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(game.cash >= f ? Theme.gold.opacity(0.85) : Theme.panelHi)
                    .foregroundStyle(game.cash >= f ? .black : Theme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .disabled(game.cash < game.yukseltMaliyet(current))
            }
        }
        .cardStyle(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(sahada ? Theme.blood.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .sheet(isPresented: $gearSheet) {
            NavigationStack {
                GearSheet(enforcerID: enforcer.id)
                    .navigationTitle("Teçhizat")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { gearSheet = false } } }
                    .background(Theme.coal)
            }
            .preferredColorScheme(.dark)
        }
    }

    private func statMini(_ ad: String, _ deger: String, _ icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Theme.blood)
            VStack(alignment: .leading, spacing: 0) {
                Text(ad).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.smoke)
                Text(deger).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Theme.panelHi)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Bir adamın teçhizatını yönetme sayfası.
struct GearSheet: View {
    @EnvironmentObject var game: GameStore
    let enforcerID: UUID

    private var enforcer: Enforcer? { game.crew.first { $0.id == enforcerID } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let e = enforcer {
                    // Takılı
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TAKILI").sectionHeader()
                        if let g = e.equippedGear {
                            GearCard(gear: g, aksiyon: "ÇIKAR") { game.gearCikar(from: enforcerID) }
                        } else {
                            Text("Takılı teçhizat yok.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                        }
                    }
                    .cardStyle(14)
                }
                // Envanter
                VStack(alignment: .leading, spacing: 8) {
                    Text("ENVANTER (\(game.envanter.count))").sectionHeader()
                    if game.envanter.isEmpty {
                        Text("Envanter boş. Dövüş kazanınca teçhizat düşer.")
                            .font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    }
                    ForEach(game.envanter.sorted { $0.guc > $1.guc }) { g in
                        GearCard(gear: g, aksiyon: "TAK", sat: { game.gearSat(g) }) {
                            game.gearTak(g, to: enforcerID)
                        }
                    }
                }
                .cardStyle(14)
            }
            .padding(16)
        }
    }
}

struct GearCard: View {
    let gear: Gear
    let aksiyon: String
    var sat: (() -> Void)? = nil
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Theme.panelHi)
                Image(systemName: gear.ikon).font(.system(size: 18)).foregroundStyle(gear.rarity.color)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(gear.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Text("+\(gear.atkBonus) vuruş · +\(gear.hpBonus) can")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.gold)
            }
            Spacer()
            if let sat {
                Button { sat() } label: {
                    Image(systemName: "dollarsign.circle").font(.system(size: 18)).foregroundStyle(Theme.smoke)
                }
                .buttonStyle(.plain)
            }
            Button { onTap() } label: {
                Text(aksiyon).font(.system(size: 12, weight: .black))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.blood).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}
