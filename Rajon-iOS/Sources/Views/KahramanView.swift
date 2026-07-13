import SwiftUI

/// Kahraman: seviye/xp, yetenek dağıtımı, maceralar ve ekipman.
struct KahramanView: View {
    @EnvironmentObject var online: OnlineService

    var body: some View {
        ScrollView {
            if let h = online.hero {
                VStack(spacing: 14) {
                    baslik(h)
                    NavigationLink {
                        MuzayedeView().environmentObject(online)
                            .navigationTitle("Eşya Müzayedesi").navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Eşya Müzayedesi — al/sat", systemImage: "bag.fill")
                            .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10).background(Theme.blood).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    yetenekler(h)
                    maceraBolum(h)
                    esyaBolum(h)
                }.padding(14)
            } else {
                ProgressView().padding(.top, 40)
            }
        }
        .task { await online.heroCek() }
    }

    private func baslik(_ h: HeroBilgi) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.stand").font(.system(size: 44)).foregroundStyle(Theme.gold)
            Text(h.ad).font(.system(size: 20, weight: .black)).foregroundStyle(Theme.ink)
            Text("Seviye \(h.level)").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.gold)
            ProgressView(value: Double(h.xp), total: Double(max(1, h.xpGerek)))
                .tint(Theme.blood)
            Text("\(h.xp) / \(h.xpGerek) XP").font(.system(size: 11)).foregroundStyle(Theme.smoke)
            HStack(spacing: 16) {
                rozet("Saldırı", "+\(h.atkBonus)", Theme.blood)
                rozet("Savunma", "+\(h.defBonus)", Theme.gold)
                rozet("Gelir", "+\(h.gelirBonus)%", Theme.gold)
            }
            if !h.evde {
                Label("Kahraman macerada — savaşta yok", systemImage: "figure.walk.motion")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.blood)
            }
        }.frame(maxWidth: .infinity).cardStyle(16)
    }

    private func rozet(_ ad: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 15, weight: .black)).foregroundStyle(c)
            Text(LocalizedStringKey(ad)).font(.system(size: 10)).foregroundStyle(Theme.smoke)
        }
    }

    private func yetenekler(_ h: HeroBilgi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YETENEKLER").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                if h.sp > 0 {
                    Text("\(h.sp) puan").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                }
            }
            yetenekSatir("Savaş Gücü", "flame.fill", h.savas, "savas", h.sp > 0)
            yetenekSatir("Liderlik", "person.3.fill", h.liderlik, "liderlik", h.sp > 0)
            yetenekSatir("Servet", "dollarsign.circle.fill", h.servet, "servet", h.sp > 0)
            Text("Savaş: kahraman saldırı/savunması • Liderlik: orduya % güç • Servet: % gelir")
                .font(.system(size: 10)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func yetenekSatir(_ ad: String, _ ikon: String, _ deger: Int, _ kod: String, _ acik: Bool) -> some View {
        HStack {
            Image(systemName: ikon).foregroundStyle(Theme.gold).frame(width: 26)
            Text(LocalizedStringKey(ad)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            Spacer()
            Text("\(deger)").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
            Button { Task { await online.heroYetenek(kod) } } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 22))
                    .foregroundStyle(acik ? Theme.blood : Theme.smoke.opacity(0.4))
            }.disabled(!acik)
        }
    }

    private func maceraBolum(_ h: HeroBilgi) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MACERA").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            if let m = h.macera {
                if m.biterMi {
                    Button { Task { await online.maceraTopla() } } label: {
                        Label("Ödülü Topla", systemImage: "gift.fill").font(.system(size: 15, weight: .black))
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(Theme.gold)
                } else {
                    HStack {
                        ProgressView()
                        Text("Macerada — \(sure(m.kalan)) kaldı").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                }
            } else {
                ForEach(h.zorluklar) { z in
                    Button { Task { await online.maceraBaslat(z.kod) } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(z.kod.capitalized).font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                                Text("\(sure(z.sure)) • ~\(z.cash)₺ • \(z.xp) XP • eşya %\(z.itemSans)")
                                    .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").foregroundStyle(Theme.blood)
                        }.frame(maxWidth: .infinity).padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func esyaBolum(_ h: HeroBilgi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EŞYALAR").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            if h.esyalar.isEmpty {
                Text("Henüz eşya yok. Maceralardan ekipman düşer.")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(h.esyalar) { e in
                HStack {
                    Image(systemName: slotIkon(e.slot)).foregroundStyle(nadirRenk(e.nadir)).frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                        Text(bonusMetin(e)).font(.system(size: 11)).foregroundStyle(Theme.gold)
                    }
                    Spacer()
                    Button { Task { if e.takili { await online.esyaCikar(e.id) } else { await online.esyaTak(e.id) } } } label: {
                        Text(e.takili ? "Çıkar" : "Tak").font(.system(size: 12, weight: .black))
                            .foregroundStyle(e.takili ? Theme.smoke : .white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(e.takili ? Theme.panelHi : Theme.blood).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func slotIkon(_ s: String) -> String {
        switch s { case "silah": return "flame.fill"; case "zirh": return "shield.fill"; default: return "sparkles" }
    }
    private func nadirRenk(_ n: String) -> Color {
        switch n { case "efsanevi": return Theme.gold; case "nadir": return Theme.blood; default: return Theme.smoke }
    }
    private func bonusMetin(_ e: HeroEsya) -> String {
        switch e.bonusTip {
        case "atk": return "+\(e.bonus) saldırı"
        case "def": return "+\(e.bonus) savunma"
        case "gelir": return "+\(e.bonus)% gelir"
        default: return "+\(e.bonus)"
        }
    }
    private func sure(_ sn: Int) -> String {
        if sn >= 60 { return "\(sn / 60) dk" }
        return "\(sn) sn"
    }
}
