import SwiftUI

/// İmparatorluk / endgame — "Şehrin Kralı" hedefi. Tüm adımlar tamamlanınca zafer.
struct SehrinKraliView: View {
    @EnvironmentObject var game: GameStore
    @State private var flare = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                baslik
                ilerlemeKart
                ForEach(Array(game.imparatorlukAdimlari.enumerated()), id: \.offset) { _, a in
                    adimSatir(a.ad, a.tamam, a.durum)
                }
                if game.imparatorlukTamam { zaferKart }
            }
            .padding(16)
        }
        .lensFlareSweep(trigger: flare, tint: Theme.gold)
        .onAppear { if game.imparatorlukTamam { flare += 1 } }
    }

    private var baslik: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill").font(.system(size: 46)).foregroundStyle(Theme.gold)
            Text("ŞEHRİN KRALI").font(.system(size: 22, weight: .black)).foregroundStyle(.white)
            Text("Nihai hedef: şehrin tamamına hükmet. Tüm bölgeleri, kaçak noktalarını ve çeteleri ele geçir, karargahını ve adını zirveye taşı.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
        }
    }

    private var ilerlemeKart: some View {
        VStack(spacing: 8) {
            HStack {
                Text("İMPARATORLUK").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Text("%\(Int(game.imparatorlukYuzde * 100))").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            }
            HealthBar(hp: Int(game.imparatorlukYuzde * 100), maxHP: 100, color: Theme.gold)
                .frame(height: 10)
        }
        .cardStyle(16)
    }

    private func adimSatir(_ ad: String, _ tamam: Bool, _ durum: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tamam ? "checkmark.seal.fill" : "circle")
                .font(.system(size: 22)).foregroundStyle(tamam ? Theme.gold : Theme.smoke)
            Text(ad).font(.system(size: 14, weight: .bold)).foregroundStyle(tamam ? .white : Theme.smoke)
            Spacer()
            Text(durum).font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(tamam ? Theme.gold : Theme.smoke)
        }
        .cardStyle(12)
    }

    private var zaferKart: some View {
        VStack(spacing: 10) {
            Text("👑").font(.system(size: 60))
            Text("ŞEHRİN KRALI OLDUN!").font(.system(size: 22, weight: .black)).foregroundStyle(Theme.gold)
            Text("Şehir artık tamamen senin. Bu tahtı kimse senden alamaz. Tebrikler reis.")
                .font(.system(size: 13)).foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24).cardStyle(20)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.gold, lineWidth: 2))
    }
}
