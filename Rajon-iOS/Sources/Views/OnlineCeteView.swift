import SwiftUI

/// FULL ONLINE çete/sendika ekranı — kur, katıl, üye listesi, hazine bağışı, savaş.
/// Tüm veriler sunucudan (OnlineService); aksiyonlar /rajon/clan/* ve /world/clan_donate.
struct OnlineCeteView: View {
    @EnvironmentObject var online: OnlineService
    @State private var ceteAd = ""
    @State private var ceteAciklama = ""
    @State private var bagisMetin = ""
    @State private var savasHedef: ClanOzet?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.blood)
                        .frame(maxWidth: .infinity).padding(8).cardStyle(8)
                }
                if let c = online.clanim {
                    cetemVar(c)
                } else {
                    cetemYok()
                }
            }
            .padding(16)
        }
        .task {
            await online.clanGetir()
            await online.clanListele()
            await online.clanSavasGetir()
        }
        .alert("Savaş ilan et", isPresented: Binding(get: { savasHedef != nil }, set: { if !$0 { savasHedef = nil } })) {
            Button("Vazgeç", role: .cancel) { savasHedef = nil }
            Button("İlan Et", role: .destructive) {
                if let h = savasHedef { Task { await online.clanSavasIlan(h.id); await online.clanSavasGetir() } }
                savasHedef = nil
            }
        } message: {
            Text("\(savasHedef?.ad ?? "") çetesine 24 saatlik savaş açılacak.")
        }
    }

    // MARK: Çeten varken
    @ViewBuilder private func cetemVar(_ c: Clan) -> some View {
        // Başlık kartı
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled").font(.system(size: 34)).foregroundStyle(Theme.gold)
            Text(c.ad).font(.system(size: 22, weight: .black)).foregroundStyle(Theme.ink)
            if !c.aciklama.isEmpty {
                Text(c.aciklama).font(.system(size: 13)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
            }
            HStack(spacing: 16) {
                istat("Üye", "\(c.uye)", Theme.ink)
                istat("Güç", fmt(c.toplam_guc), Theme.gold)
                istat("İtibar", fmt(c.toplam_respect), Theme.blood)
                istat("Hazine", fmt(c.hazine ?? 0), Theme.gold)
            }
            if (c.savas_galibi ?? 0) > 0 {
                Label("\(c.savas_galibi ?? 0) savaş zaferi", systemImage: "crown.fill")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
            }
        }
        .frame(maxWidth: .infinity).cardStyle(16)

        // Aktif savaş
        if let w = online.clanSavas {
            VStack(spacing: 8) {
                Text("SAVAŞ").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.blood)
                HStack {
                    skor("Biz", w.benim_skor, w.benim_skor >= w.rakip_skor)
                    Text("vs").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.smoke)
                    skor(w.rakip_ad, w.rakip_skor, w.rakip_skor > w.benim_skor)
                }
                Text("Düşman çetenin üyelerine baskın yap → savaş puanı kazan.")
                    .font(.system(size: 11)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).cardStyle(14)
        }

        // Hazine bağışı (dünya nakdinden düşülür)
        VStack(alignment: .leading, spacing: 8) {
            Text("HAZİNEYE BAĞIŞ").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            HStack {
                TextField("Tutar ₺", text: $bagisMetin)
                    .keyboardType(.numberPad)
                    .padding(10).background(Theme.panelHi)
                    .clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(Theme.ink)
                Button("Bağışla") {
                    let m = Int(bagisMetin) ?? 0
                    if m > 0 { Task { await online.dunyaClanBagis(m); bagisMetin = "" } }
                }
                .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.blood).clipShape(RoundedRectangle(cornerRadius: 9))
            }
            Text("Kasandaki ₺\(fmt(online.dunya?.cash ?? 0)) nakitten düşülür.")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity).cardStyle(14)

        // Üyeler
        VStack(alignment: .leading, spacing: 8) {
            Text("ÜYELER").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(c.members) { m in
                HStack(spacing: 10) {
                    Image(systemName: m.id == c.lider ? "crown.fill" : "person.fill")
                        .font(.system(size: 13)).foregroundStyle(m.id == c.lider ? Theme.gold : Theme.smoke).frame(width: 20)
                    Text(m.ad).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(m.id == online.me?.id ? Theme.gold : Theme.ink).lineLimit(1)
                    Spacer()
                    Text("Güç \(fmt(m.power)) · ★\(fmt(m.respect))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity).cardStyle(14)

        // Lider: savaş ilan et
        if c.lider_mi && online.clanSavas == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("SAVAŞ İLAN ET").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                ForEach(online.clanListesi.filter { $0.id != c.id }) { d in
                    Button { savasHedef = d } label: {
                        HStack {
                            Text(d.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("Güç \(fmt(d.toplam_guc))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                            Image(systemName: "flag.fill").foregroundStyle(Theme.blood)
                        }.padding(.vertical, 4)
                    }
                }
                if online.clanListesi.filter({ $0.id != c.id }).isEmpty {
                    Text("Savaşacak başka çete yok.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                }
            }
            .frame(maxWidth: .infinity).cardStyle(14)
        }

        // Çeteden çık
        Button(role: .destructive) {
            Task { await online.clanCik() }
        } label: {
            Text("Çeteden Ayrıl").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.blood)
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(Theme.bloodDim.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Çeten yokken
    @ViewBuilder private func cetemYok() -> some View {
        // Kur
        VStack(alignment: .leading, spacing: 10) {
            Text("ÇETE KUR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            TextField("Çete adı", text: $ceteAd)
                .padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(Theme.ink)
            TextField("Açıklama (isteğe bağlı)", text: $ceteAciklama)
                .padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(Theme.ink)
            Button {
                if ceteAd.count >= 3 { Task { await online.clanKur(ad: ceteAd, aciklama: ceteAciklama) } }
            } label: {
                Text("ÇETEYİ KUR").font(.system(size: 15, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(ceteAd.count >= 3 ? Theme.blood : Theme.panelHi)
                    .foregroundStyle(ceteAd.count >= 3 ? .white : Theme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .disabled(ceteAd.count < 3)
            Text("En az 3 harf. Kuran lider olur.").font(.system(size: 11)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity).cardStyle(14)

        // Listele + katıl
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ÇETELER").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Button { Task { await online.clanListele() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(Theme.smoke)
                }
            }
            if online.clanListesi.isEmpty {
                Text("Henüz çete yok. İlk çeteyi sen kur.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(online.clanListesi) { c in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Text("\(c.uye) üye · güç \(fmt(c.toplam_guc))").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                    }
                    Spacer()
                    Button { Task { await online.clanKatil(id: c.id) } } label: {
                        Text("KATIL").font(.system(size: 11, weight: .black))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.bloodDim).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .frame(maxWidth: .infinity).cardStyle(14)
    }

    // MARK: Yardımcılar
    private func istat(_ b: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(c)
            Text(b).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.smoke)
        }
    }

    private func skor(_ ad: String, _ s: Int, _ onde: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(s)").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(onde ? Theme.gold : Theme.ink)
            Text(ad).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.smoke).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
