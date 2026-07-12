import SwiftUI

/// Dünya Harikası — çeteler inşa eder, ilk 100. seviyeye ulaşan sezonu KAZANIR. Kilometre taşları eser verir.
struct HarikaView: View {
    @EnvironmentObject var online: OnlineService
    @State private var miktar = 5000

    var body: some View {
        ScrollView {
            if let h = online.harika {
                VStack(spacing: 14) {
                    if h.clan.isEmpty {
                        Text("Dünya Harikası bir çete işidir. Önce bir çeteye katıl.")
                            .font(.system(size: 14)).foregroundStyle(Theme.smoke).padding(.top, 30)
                    } else {
                        durumKart(h)
                        katkiKart(h)
                        if !h.eserler.isEmpty { eserKart(h) }
                    }
                    siralamaKart(h)
                }.padding(14)
            } else {
                ProgressView().padding(.top, 40)
            }
        }
        .task { await online.harikaCek() }
    }

    private func durumKart(_ h: HarikaDurum) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.gold)
            Text("Çeten: \(h.clan)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.smoke)
            Text("Harika Seviyesi \(h.seviye) / \(h.maks)").font(.system(size: 20, weight: .black)).foregroundStyle(Theme.ink)
            ProgressView(value: Double(h.seviye), total: Double(h.maks)).tint(Theme.blood)
            if h.seviye >= h.maks {
                Label("SEZON ZAFERİ KAZANILDI!", systemImage: "crown.fill").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.gold)
            } else {
                Text("Sonraki seviye: ₺\(h.sonrakiMaliyet) · biriken ₺\(h.biriken)")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            Text("Toplam katkı: ₺\(h.toplam)").font(.system(size: 11)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity).cardStyle(16)
    }

    private func katkiKart(_ h: HarikaDurum) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KATKI YAP").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            Stepper("Miktar: ₺\(miktar)", value: $miktar, in: 1000...5_000_000, step: 1000)
            Button { Task { await online.harikaKatki(miktar) } } label: {
                Label("Harikaya Bağışla", systemImage: "hammer.fill").font(.system(size: 15, weight: .black)).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Theme.blood)
            Text("Kuruşun harikaya akar. Çete olarak birlikte inşa edip sezonu kazanın; 25/50/75/100. seviyelerde eser kazanılır.")
                .font(.system(size: 10)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func eserKart(_ h: HarikaDurum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÇETE ESERLERİ").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(h.eserler) { e in
                HStack {
                    Image(systemName: "seal.fill").foregroundStyle(Theme.gold)
                    Text(e.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func siralamaKart(_ h: HarikaDurum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HARİKA SIRALAMASI").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            if h.siralama.isEmpty {
                Text("Henüz kimse harika inşa etmedi. İlk sizsiniz!").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(Array(h.siralama.enumerated()), id: \.element.id) { i, s in
                HStack {
                    Text("\(i + 1).").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.gold).frame(width: 26, alignment: .leading)
                    Text(s.clan).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text("Sv.\(s.seviye)").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.ink)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }
}
