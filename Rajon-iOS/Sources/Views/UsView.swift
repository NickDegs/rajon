import SwiftUI

/// Üs / karargah — haraç toplama ve işletmeler.
struct UsView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                idleKart
                gelirOzet
                Text("İŞLETMELER")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                ForEach(game.rackets) { r in
                    RacketRow(racket: r)
                }
            }
            .padding(16)
        }
    }

    private var idleKart: some View {
        VStack(spacing: 12) {
            Text("KASADA BİRİKEN")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.smoke)
            Text("₺\(fmt(game.idleKazanc))")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gold)
                .contentTransition(.numericText())
                .animation(.snappy, value: game.idleKazanc)
            Button {
                game.haracTopla()
            } label: {
                Text(game.idleKazanc > 0 ? "HARACI TOPLA" : "KASA BOŞ LAN")
                    .font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(game.idleKazanc > 0 ? Theme.blood : Theme.panelHi)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(game.idleKazanc <= 0)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(20)
    }

    private var gelirOzet: some View {
        HStack {
            Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Theme.gold)
            Text("Dakikada ₺\(fmt(game.gelirPerMin))")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(game.ownedRackets.count)/\(game.rackets.count) işletme")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.smoke)
        }
        .cardStyle(12)
    }
}

struct RacketRow: View {
    @EnvironmentObject var game: GameStore
    let racket: Racket

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.panelHi)
                Image(systemName: racket.owned ? "storefront.fill" : "lock.fill")
                    .foregroundStyle(racket.owned ? Theme.gold : Theme.smoke)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(racket.ad)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                if racket.owned {
                    Text("Sv. \(racket.tier) · dk/₺\(fmt(racket.perMin))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                } else {
                    Text("dk/₺\(fmt(racket.perMin)) üretir")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.smoke)
                }
            }
            Spacer()

            Button {
                game.racketSatinAlVeyaYukselt(racket.id)
            } label: {
                let fiyat = racket.owned ? racket.upgradeCost : racket.baseUpgradeCost
                VStack(spacing: 1) {
                    Text(racket.owned ? "YÜKSELT" : "AL")
                        .font(.system(size: 11, weight: .black))
                    Text("₺\(fmt(fiyat))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(yeterMi ? .white : Theme.smoke)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(yeterMi ? Theme.bloodDim : Theme.panelHi)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .disabled(!yeterMi)
        }
        .cardStyle(12)
    }

    private var yeterMi: Bool {
        game.cash >= (racket.owned ? racket.upgradeCost : racket.baseUpgradeCost)
    }
}
