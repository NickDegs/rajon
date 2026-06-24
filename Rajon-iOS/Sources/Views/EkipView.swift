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
                ForEach(0..<4, id: \.self) { i in
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

    private var sahada: Bool { game.squad.contains(enforcer.id) }

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
                statMini("CAN", fmt(enforcer.maxHP), "heart.fill")
                statMini("VURUŞ", fmt(enforcer.atk), "burst.fill")
                statMini("HIZ", "\(enforcer.spd)", "hare.fill")
            }
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
                    let f = game.yukseltMaliyet(enforcer)
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
                .disabled(game.cash < game.yukseltMaliyet(enforcer))
            }
        }
        .cardStyle(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(sahada ? Theme.blood.opacity(0.6) : .clear, lineWidth: 1.5)
        )
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
