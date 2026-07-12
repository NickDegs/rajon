import SwiftUI

/// Kahraman eşya müzayedesi — eşyalarını sat, başkalarınınkini al (açık pazar, kuruşla).
struct MuzayedeView: View {
    @EnvironmentObject var online: OnlineService
    @State private var fiyat = 5000
    @State private var satilacak: HeroEsya? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                satBolum
                if let m = online.muzayede, !m.benim.isEmpty { benimBolum(m) }
                pazarBolum
            }.padding(14)
        }
        .task { await online.heroCek(); await online.muzayedeCek() }
        .sheet(item: $satilacak) { e in satSheet(e) }
    }

    private var satBolum: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SATILACAK EŞYALARIM").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            let satilabilir = (online.hero?.esyalar ?? []).filter { !$0.takili }
            if satilabilir.isEmpty {
                Text("Satılabilir (takılı olmayan) eşyan yok.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(satilabilir) { e in
                HStack {
                    Text(e.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { fiyat = 5000; satilacak = e } label: {
                        Text("Sat").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.gold).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func benimBolum(_ m: MuzayedeDurum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AÇIK İLANLARIM").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(m.benim) { i in
                HStack {
                    Text("\(i.ad) · ₺\(i.fiyat)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { Task { await online.muzayedeIptal(i.id) } } label: { Text("İptal").font(.system(size: 12, weight: .bold)) }.tint(Theme.smoke)
                }.cardStyle(10)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private var pazarBolum: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAZARDAKİ EŞYALAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            if (online.muzayede?.ilanlar ?? []).isEmpty {
                Text("Şu an satılan eşya yok.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(online.muzayede?.ilanlar ?? []) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i.ad).font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                        Text("\(bonusMetin(i)) · \(i.satici)").font(.system(size: 11)).foregroundStyle(Theme.gold)
                    }
                    Spacer()
                    Button { Task { await online.muzayedeAl(i.id) } } label: {
                        Text("₺\(i.fiyat)").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(Theme.blood).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func satSheet(_ e: HeroEsya) -> some View {
        NavigationStack {
            Form {
                Section(e.ad) {
                    Stepper("Fiyat: ₺\(fiyat)", value: $fiyat, in: 500...5_000_000, step: 500)
                }
                Section {
                    Button {
                        Task { await online.muzayedeKoy(e.id, fiyat); satilacak = nil }
                    } label: { Text("Müzayedeye Koy").frame(maxWidth: .infinity).font(.system(size: 15, weight: .black)) }
                }
            }
            .navigationTitle("Eşya Sat").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("İptal") { satilacak = nil } } }
        }
    }

    private func bonusMetin(_ i: MuzayedeIlan) -> String {
        switch i.bonusTip {
        case "atk": return "+\(i.bonus) saldırı"
        case "def": return "+\(i.bonus) savunma"
        case "gelir": return "+\(i.bonus)% gelir"
        default: return "+\(i.bonus)"
        }
    }
}
