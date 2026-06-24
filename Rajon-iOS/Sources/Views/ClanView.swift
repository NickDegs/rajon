import SwiftUI

/// Çete / sendika ekranı — kur, katıl, üyeler, çete listesi.
struct ClanView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var online: OnlineService

    @State private var yeniAd = ""
    @State private var yeniAciklama = ""
    @State private var savasSecAcik = false
    @State private var bilgi: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let c = online.clanim {
                    clanimKart(c)
                } else {
                    kurKart
                    listeKart
                }
            }
            .padding(16)
        }
        .task {
            await online.clanGetir()
            await online.clanListele()
            await online.clanSavasGetir()
        }
    }

    // MARK: Savaş + takviye
    private func savasTakviyeKart(_ c: Clan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAVAŞ & TAKVİYE").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Text("🏆 \(c.savas_galibi ?? 0)").font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.gold)
            }
            // Hazine + bağış
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("HAZİNE").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.smoke)
                    Text("₺\(fmt(c.hazine ?? 0))").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                }
                Spacer()
                ForEach([10_000, 50_000], id: \.self) { m in
                    Button {
                        guard game.cash >= m else { bilgi = "Yetersiz nakit"; return }
                        game.cash -= m; game.save()
                        Task { await online.clanBagis(m) }
                    } label: {
                        Text("Bağış ₺\(fmt(m))").font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(game.cash >= m ? Theme.bloodDim : Theme.panelHi)
                            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain).disabled(game.cash < m)
                }
            }
            // Savaş durumu
            if let w = online.clanSavas {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let kalan = max(0, Int(w.bitis - Date().timeIntervalSince1970))
                    VStack(spacing: 4) {
                        Text("SAVAŞ: \(w.rakip_ad)").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.blood)
                        HStack {
                            Text("Biz \(w.benim_skor)").foregroundStyle(w.benim_skor >= w.rakip_skor ? Color.green : .white)
                            Spacer()
                            Text(sureMetni(kalan)).foregroundStyle(Theme.gold)
                            Spacer()
                            Text("\(w.rakip_skor) Onlar").foregroundStyle(w.rakip_skor > w.benim_skor ? Theme.blood : .white)
                        }.font(.system(size: 14, weight: .heavy, design: .rounded))
                        Text("Rakip çete üyelerine baskın yap → savaş puanı kazan.")
                            .font(.system(size: 10)).foregroundStyle(Theme.smoke)
                    }
                    .padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else if c.lider_mi {
                Button { savasSecAcik = true } label: {
                    Label("Savaş İlan Et", systemImage: "flag.fill")
                        .font(.system(size: 13, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Theme.blood).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .confirmationDialog("Hangi çeteye savaş?", isPresented: $savasSecAcik, titleVisibility: .visible) {
                    ForEach(online.clanListesi.filter { $0.id != c.id }.prefix(8)) { hedef in
                        Button(hedef.ad) { Task { await online.clanSavasIlan(hedef.id) } }
                    }
                    Button("Vazgeç", role: .cancel) {}
                }
            } else {
                Text("Savaşı çete lideri ilan eder.").font(.system(size: 11)).foregroundStyle(Theme.smoke)
            }
            if let b = bilgi { Text(b).font(.system(size: 11)).foregroundStyle(Theme.blood) }
        }
        .cardStyle(14)
    }

    // MARK: Çetem
    private func clanimKart(_ c: Clan) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 40)).foregroundStyle(Theme.blood)
                Text(c.ad).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                if !c.aciklama.isEmpty {
                    Text(c.aciklama).font(.system(size: 12)).foregroundStyle(Theme.smoke)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 16) {
                    miniStat("ÜYE", "\(c.uye)")
                    miniStat("İTİBAR", fmt(c.toplam_respect))
                    miniStat("GÜÇ", fmt(c.toplam_guc))
                }
                if c.lider_mi {
                    Text("Sen lidersin").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity).cardStyle(18)

            savasTakviyeKart(c)

            VStack(alignment: .leading, spacing: 8) {
                Text("ÜYELER").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                ForEach(Array(c.members.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 10) {
                        Text("#\(i + 1)").font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(m.id == c.lider ? Theme.gold : Theme.smoke).frame(width: 30, alignment: .leading)
                        Text(m.ad).font(.system(size: 14, weight: .bold))
                            .foregroundStyle(m.id == online.me?.id ? Theme.gold : .white)
                        if m.id == c.lider {
                            Image(systemName: "crown.fill").font(.system(size: 10)).foregroundStyle(Theme.gold)
                        }
                        Spacer()
                        Text("★\(fmt(m.respect))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                    }
                    .padding(.vertical, 3)
                }
            }
            .cardStyle(14)

            Button(role: .destructive) {
                Task { await online.clanCik(); await online.clanListele() }
            } label: {
                Text("Çeteden Ayrıl").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.blood)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Theme.bloodDim.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Kur
    private var kurKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ÇETE KUR").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
            TextField("Çete adı", text: $yeniAd)
                .padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(.white)
            TextField("Slogan (isteğe bağlı)", text: $yeniAciklama)
                .padding(10).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(.white)
            Button {
                Task {
                    await online.clanKur(ad: yeniAd, aciklama: yeniAciklama)
                    await online.clanListele()
                }
            } label: {
                Text(online.mesgul ? "Kuruluyor…" : "ÇETEYİ KUR").font(.system(size: 15, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(yeniAd.count >= 3 ? Theme.blood : Theme.panelHi).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .disabled(yeniAd.count < 3 || online.mesgul)
            if let h = online.hata { Text(h).font(.system(size: 11)).foregroundStyle(Theme.blood) }
        }
        .cardStyle(16)
    }

    // MARK: Liste
    private var listeKart: some View {
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
                    Image(systemName: "shield.fill").foregroundStyle(Theme.blood)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("\(c.uye) üye · ★\(fmt(c.toplam_respect))")
                            .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                    }
                    Spacer()
                    Button {
                        Task { await online.clanKatil(id: c.id); await online.clanListele() }
                    } label: {
                        Text("KATIL").font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.bloodDim).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle(16)
    }

    private func miniStat(_ ad: String, _ v: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(ad).font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity)
    }
}
