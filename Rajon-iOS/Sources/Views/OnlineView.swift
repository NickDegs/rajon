import SwiftUI

/// Online mod — anonim hesap, PvP baskın, lider tablosu.
struct OnlineView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var online: OnlineService
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var kozmetik: CosmeticStore
    @State private var kozmetikAcik = false

    @State private var adGirisi = ""
    @State private var hedef: PvpTarget?
    @State private var pvpNode: RivalNode?
    @State private var sonPvpHedef: PvpTarget?
    @State private var bilgi: String?
    @State private var clanAcik = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !online.girisli {
                    girisKart
                } else {
                    profilKart
                    sendikaButon
                    baskinKart
                    liderKart
                }
                if let b = bilgi {
                    Text(b).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.gold).multilineTextAlignment(.center)
                }
                if let h = online.hata {
                    Text(h).font(.system(size: 12)).foregroundStyle(Theme.blood)
                }
            }
            .padding(16)
        }
        .task {
            await online.otomatikGiris()
            if online.girisli { await online.sync(game: game); await online.liderTablosu() }
        }
        .fullScreenCover(item: $pvpNode) { node in
            CombatView(node: node) { kazandi in
                Task { await pvpSonuc(kazandi) }
            }
            .environmentObject(game)
        }
        .sheet(isPresented: $clanAcik) {
            NavigationStack {
                ClanView()
                    .navigationTitle("Sendika")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { clanAcik = false } } }
                    .background(Theme.coal)
            }
            .preferredColorScheme(.dark)
            .environmentObject(game)
            .environmentObject(online)
        }
        .sheet(isPresented: $kozmetikAcik) {
            NavigationStack {
                KozmetikView()
                    .navigationTitle("Özelleştir")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { kozmetikAcik = false } } }
                    .background(Theme.bg)
            }
            .preferredColorScheme(.dark)
            .environmentObject(kozmetik)
            .environmentObject(store)
            .environmentObject(online)
        }
    }

    private var sendikaButon: some View {
        Button { clanAcik = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 22)).foregroundStyle(Theme.blood)
                VStack(alignment: .leading, spacing: 2) {
                    Text(online.clanim?.ad ?? "ÇETE / SENDİKA")
                        .font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                    Text(online.clanim == nil ? "Çete kur ya da katıl, birlikte yüksel."
                                              : "\(online.clanim!.uye) üye · ★\(fmt(online.clanim!.toplam_respect))")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.smoke)
            }
            .cardStyle(14)
        }
        .buttonStyle(.plain)
        .task { await online.clanGetir() }
    }

    // MARK: Giriş
    private var girisKart: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 50)).foregroundStyle(Theme.blood)
            Text("ONLINE — ŞEHRİN KRALI KİM?")
                .font(.system(size: 16, weight: .black)).foregroundStyle(.white)
            Text("Bir patron adı seç, sokağa adını yaz. Başka oyunculara baskın yap, lider tablosuna tırman.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke)
                .multilineTextAlignment(.center)
            TextField("Patron adın", text: $adGirisi)
                .textInputAutocapitalization(.words)
                .font(.system(size: 16, weight: .bold))
                .padding(12).background(Theme.panelHi)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            Button {
                Task {
                    await online.girisYap(ad: adGirisi.isEmpty ? "Patron" : adGirisi)
                    if online.girisli { await online.sync(game: game); await online.liderTablosu() }
                }
            } label: {
                Text(online.mesgul ? "Bağlanıyor…" : "SOKAĞA ÇIK")
                    .font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.blood).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(online.mesgul)
        }
        .cardStyle(20)
    }

    // MARK: Profil
    private var profilKart: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(kozmetik.avatar).resizable().scaledToFill()
                    .frame(width: 64, height: 64).clipShape(Circle())
                    .overlay(Circle().stroke(kozmetik.seciliRenk, lineWidth: 3))
                    .onTapGesture { kozmetikAcik = true }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if !kozmetik.unvan.isEmpty {
                            Text(kozmetik.unvan).font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Theme.panelHi).foregroundStyle(Theme.gold).clipShape(Capsule())
                        }
                        Text(online.me?.ad ?? online.ad).font(.system(size: 18, weight: .black))
                            .foregroundStyle(kozmetik.seciliRenk)
                        if let r = store.aktifRozet { Text(r).font(.system(size: 15)) }
                    }
                    Text("Güç \(fmt(game.squadPower)) · İtibar \(fmt(online.me?.respect ?? 0))")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }
                Spacer()
                if let r = online.myRank {
                    VStack(spacing: 0) {
                        Text("#\(r)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                        Text("SIRA").font(.system(size: 8, weight: .black)).foregroundStyle(Theme.smoke)
                    }
                }
            }
            HStack(spacing: 16) {
                skor("Saldırı G.", online.me?.wins ?? 0, Color.green)
                skor("Yenilgi", online.me?.losses ?? 0, Theme.blood)
                skor("Savunma G.", online.me?.def_wins ?? 0, Theme.gold)
            }
            Button { kozmetikAcik = true } label: {
                Label("Görünümünü Özelleştir", systemImage: "paintpalette.fill")
                    .font(.system(size: 14, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Theme.panelHi).foregroundStyle(Theme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .cardStyle(16)
    }

    // MARK: Baskın
    private var baskinKart: some View {
        VStack(spacing: 12) {
            if let h = hedef {
                Text("RAKİP BULUNDU").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.smoke)
                Text(h.ad).font(.system(size: 20, weight: .heavy)).foregroundStyle(.white)
                HStack(spacing: 16) {
                    etiket("Güç \(fmt(h.power))", h.power > game.squadPower ? Theme.blood : Color.green)
                    etiket("Yağma ₺\(fmt(h.loot))", Theme.gold)
                    etiket("\(h.crew.count) adam", Theme.smoke)
                }
                Button {
                    sonPvpHedef = h
                    pvpNode = h.toRivalNode()
                    hedef = nil
                } label: {
                    Text("BASKINI BAŞLAT").font(.system(size: 15, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.blood).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            } else {
                Image(systemName: "scope").font(.system(size: 34)).foregroundStyle(Theme.blood)
                Text("Bir rakip bul, ekibini ez, kasasını boşalt.")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                Button {
                    Task {
                        await online.sync(game: game)
                        hedef = await online.hedefBul()
                        if hedef == nil { bilgi = "Şu an uygun rakip yok — biraz sonra dene." }
                    }
                } label: {
                    Text(online.mesgul ? "Aranıyor…" : "RAKİP ARA").font(.system(size: 15, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Theme.bloodDim).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .disabled(online.mesgul || game.squadEnforcers.isEmpty)
                if game.squadEnforcers.isEmpty {
                    Text("Önce Ekip'ten sahaya adam koy.").font(.system(size: 11)).foregroundStyle(Theme.blood)
                }
            }
        }
        .cardStyle(16)
    }

    // MARK: Lider
    private var liderKart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LİDER TABLOSU").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Button { Task { await online.liderTablosu() } } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13)).foregroundStyle(Theme.smoke)
                }
            }
            if online.lider.isEmpty {
                Text("Henüz kimse yok. İlk sen ol.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            ForEach(Array(online.lider.prefix(20).enumerated()), id: \.element.id) { i, s in
                HStack(spacing: 10) {
                    Text("#\(i + 1)").font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(i < 3 ? Theme.gold : Theme.smoke).frame(width: 34, alignment: .leading)
                    Text(s.ad).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(s.id == online.me?.id ? Theme.gold : .white).lineLimit(1)
                    Spacer()
                    Text("⚔︎\(s.wins)  ★\(fmt(s.respect))")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                }
                .padding(.vertical, 4)
                if i < min(online.lider.count, 20) - 1 { Divider().background(Color.white.opacity(0.05)) }
            }
        }
        .cardStyle(16)
    }

    private func pvpSonuc(_ kazandi: Bool) async {
        guard let h = sonPvpHedef else { return }
        await online.sonucBildir(defenderID: h.id, won: kazandi, loot: h.loot)
        if kazandi {
            game.cash += h.loot
            game.respect += 15
            game.gorevIlerlet(.baskin)
            game.raporEkle("Baskın: \(h.ad)", "₺\(fmt(h.loot)) yağma + 15 itibar", kazandi: true)
            game.save()
            bilgi = "Baskın başarılı! ₺\(fmt(h.loot)) yağma + itibar."
        } else {
            game.raporEkle("Baskın: \(h.ad)", "Savunma sağlam çıktı, eli boş döndün", kazandi: false)
            bilgi = "Baskın patladı. Ekibini güçlendir, tekrar dene."
        }
        await online.liderTablosu()
    }

    // MARK: Yardımcı görünümler
    private func skor(_ ad: String, _ v: Int, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(v)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(c)
            Text(ad).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity)
    }
    private func etiket(_ t: String, _ c: Color) -> some View {
        Text(t).font(.system(size: 12, weight: .bold)).foregroundStyle(c)
    }
}

extension PvpTarget {
    /// PvP hedefini dövüş düğümüne çevir.
    func toRivalNode() -> RivalNode {
        let crewE = crew.map { $0.toEnforcer() }
        let fallback = crewE.isEmpty ? [Factory.makeEnforcer(rarity: .tetikci, level: 3)] : crewE
        return RivalNode(
            ad: ad, aciklama: "Online rakip · güç \(power)",
            power: power, crew: fallback,
            oduuncash: loot, odulRespect: 15
        )
    }
}
