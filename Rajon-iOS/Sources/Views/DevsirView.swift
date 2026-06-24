import SwiftUI

/// Devşirme — para karşılığı rasgele adam (gacha).
struct DevsirView: View {
    @EnvironmentObject var game: GameStore
    @State private var sonGelen: Enforcer?
    @State private var aciliyor = false
    @State private var flare = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                baslik

                // Açılan zarf / kart
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.panel)
                        .frame(height: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke((sonGelen?.rarity.color ?? Theme.smoke).opacity(0.5), lineWidth: 2)
                        )
                    if let e = sonGelen {
                        revealKart(e)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "person.fill.questionmark")
                                .font(.system(size: 60))
                                .foregroundStyle(Theme.smoke)
                            Text("Sokaktan kim çıkacak?")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.smoke)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .lensFlareSweep(trigger: flare, tint: sonGelen?.rarity.color ?? Theme.gold)

                Button {
                    devsir()
                } label: {
                    VStack(spacing: 2) {
                        Text("ADAM DEVŞİR")
                            .font(.system(size: 17, weight: .black))
                        Text("₺\(fmt(game.devsirmeCost))")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(game.cash >= game.devsirmeCost ? Theme.blood : Theme.panelHi)
                    .foregroundStyle(game.cash >= game.devsirmeCost ? .white : Theme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(game.cash < game.devsirmeCost || aciliyor)

                oranlar
            }
            .padding(16)
        }
    }

    private func devsir() {
        guard let yeni = game.devsir() else { return }
        aciliyor = true
        sonGelen = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.15)) {
            sonGelen = yeni
        }
        // Patron/Efsane çıkınca mercek yanması
        if yeni.rarity >= .patron {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { flare += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { aciliyor = false }
    }

    private func revealKart(_ e: Enforcer) -> some View {
        VStack(spacing: 12) {
            AvatarCircle(enforcer: e, size: 90)
            Text(e.ad)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
            RarityTag(rarity: e.rarity)
            Text("\(e.klas.label) · Güç \(fmt(e.guc))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.smoke)
            Text("\"\(e.taunt)\"")
                .font(.system(size: 12, weight: .medium))
                .italic()
                .foregroundStyle(e.rarity.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEVŞİRME")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
            Text("Parayı bas, sokaktan adam çek. Kimi it çıkar, kimi efsane — şansına.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var oranlar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÇIKMA ORANLARI")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.smoke)
            ForEach(Rarity.allCases.reversed(), id: \.self) { r in
                HStack {
                    RarityTag(rarity: r)
                    Spacer()
                    Text(String(format: "%%%.0f", oran(r)))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .cardStyle(14)
    }

    private func oran(_ r: Rarity) -> Double {
        let total = Rarity.allCases.reduce(0.0) { $0 + $1.dropWeight }
        return r.dropWeight / total * 100
    }
}
