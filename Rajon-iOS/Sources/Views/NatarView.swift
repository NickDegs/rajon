import SwiftUI

/// Natar Eyaleti — NPC imparatorluğun eser kaleleri. Baskınla eseri ele geçir (sunucu geneli benzersiz, güçlü bonus).
struct NatarView: View {
    @EnvironmentObject var online: OnlineService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Natar kaleleri sunucu geneli benzersiz eserleri tutar. Yeterince güçlü orduyla baskın yap → eseri ele geçir. Eser sende oldukça bonusu senin; başkası fethederse elinden alır.")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke).padding(.horizontal, 4)
                ForEach(online.natarlar) { n in kart(n) }
            }.padding(14)
        }
        .task { await online.natarCek() }
    }

    private func kart(_ n: NatarKale) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                Text(n.eser).font(.system(size: 16, weight: .black)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(n.uzaklik) km").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            Text("Etki: \(n.etki)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
            HStack(spacing: 14) {
                Label("Savunma \(n.savunma)", systemImage: "shield.fill").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                Label(n.bende ? "SENDE" : n.sahip, systemImage: "person.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(n.bende ? Theme.gold : Theme.blood)
            }
            if n.bende {
                Text("Bu eser şu an sende — bonusun aktif.").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
            } else {
                Button { Task { await online.natarSaldir(n.id) } } label: {
                    Label("Baskın Yap — Eseri Al", systemImage: "flame.fill").font(.system(size: 13, weight: .black)).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Theme.blood)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }
}
