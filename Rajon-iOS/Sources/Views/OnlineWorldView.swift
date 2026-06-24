import SwiftUI

/// SUNUCU-OTORİTER canlı dünya — tüm arayüz sunucudan gelen state'le çalışır.
/// Online'a girince RootView bunu gösterir; aksiyonlar /world/* uçlarına gider.
struct OnlineWorldView: View {
    @EnvironmentObject var online: OnlineService
    @State private var tab = 0

    private static let binaAd: [String: String] = [
        "karargah": "Karargah", "kasa": "Kasa Dairesi", "depo": "Depo",
        "cephanelik": "Cephanelik", "kisla": "Kışla", "korunak": "Korunak",
    ]
    private static let binaIkon: [String: String] = [
        "karargah": "flag.2.crossed.fill", "kasa": "banknote.fill", "depo": "shippingbox.fill",
        "cephanelik": "shield.lefthalf.filled", "kisla": "person.3.sequence.fill", "korunak": "lock.shield.fill",
    ]
    private static let askerAd: [String: String] = ["tetikci": "Tetikçi", "kabadayi": "Kabadayı", "sofor": "Şoför"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                kaynakBar
                if let d = online.dunya {
                    TabView(selection: $tab) {
                        usSekme(d).tag(0).tabItem { Label("Üs", systemImage: "building.2.fill") }
                        haritaSekme(d).tag(1).tabItem { Label("Harita", systemImage: "map.fill") }
                        orduSekme(d).tag(2).tabItem { Label("Ordu", systemImage: "figure.walk") }
                        dunyaSekme().tag(3).tabItem { Label("Dünya", systemImage: "trophy.fill") }
                    }
                    .tint(Theme.blood)
                } else {
                    Spacer()
                    ProgressView().tint(Theme.gold)
                    Text("Canlı dünya yükleniyor…").font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 8)
                    Spacer()
                }
            }
        }
        .task {
            await online.dunyaCek()
            // Canlı poll: her 3 sn durumu tazele
            while online.dunyaAktif {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await online.dunyaCek()
            }
        }
    }

    // MARK: Üst kaynak barı
    private var kaynakBar: some View {
        let d = online.dunya
        return HStack(spacing: 10) {
            kaynak("dollarsign.circle.fill", fmt(d?.cash ?? 0), Theme.gold)
            kaynak("circle.hexagongrid.fill", fmt(d?.cephane ?? 0), Theme.smoke)
            kaynak("flame.fill", fmt(d?.respect ?? 0), Theme.blood)
            Spacer()
            Text("Sv.\(d?.bossLevel ?? 1)").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Button { online.dunyadanCik() } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 15)).foregroundStyle(Theme.smoke)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.coal)
    }

    private func kaynak(_ icon: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
    }

    // MARK: Üs (ekonomi + işletme + bina)
    private func usSekme(_ d: DunyaView) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.blood)
                        .frame(maxWidth: .infinity).padding(8).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                // Kasa / idle
                VStack(spacing: 10) {
                    Text("KASADA BİRİKEN").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.smoke)
                    Text("₺\(fmt(d.idle))").font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                    Text("Dakikada ₺\(fmt(d.incomePerMin))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                    Button { Task { await online.dunyaTopla() } } label: {
                        Text(d.idle > 0 ? "HARACI TOPLA" : "KASA BOŞ")
                            .font(.system(size: 16, weight: .black)).frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(d.idle > 0 ? Theme.blood : Theme.panelHi).foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }.disabled(d.idle <= 0)
                }.frame(maxWidth: .infinity).cardStyle(18)

                // Binalar
                Text("MAHALLE — İNŞAAT").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(d.buildings) { b in binaSatir(b, d) }

                // İşletmeler
                Text("İŞLETMELER").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(d.rackets) { r in isletmeSatir(r, d) }
            }.padding(16)
        }
    }

    private func binaSatir(_ b: DBina, _ d: DunyaView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: Self.binaIkon[b.tip] ?? "building.2.fill").font(.system(size: 22)).foregroundStyle(Theme.gold).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Self.binaAd[b.tip] ?? b.tip) · Sv.\(b.seviye)").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                if b.insaatta {
                    Text("İnşaatta · \(sureMetni(b.kalan))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                } else {
                    Text("Yükselt ₺\(fmt(b.fiyat)) · \(sureMetni(b.sure))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                }
            }
            Spacer()
            if !b.insaatta {
                Button { Task { await online.dunyaBina(b.tip) } } label: {
                    Text("YÜKSELT").font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(d.insaatMesgul || d.cash < b.fiyat ? Theme.panelHi : Theme.bloodDim)
                        .foregroundStyle(d.insaatMesgul || d.cash < b.fiyat ? Theme.smoke : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }.disabled(d.insaatMesgul || d.cash < b.fiyat)
            }
        }.cardStyle(12)
    }

    private func isletmeSatir(_ r: DRacket, _ d: DunyaView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: r.owned ? "storefront.fill" : "lock.fill").font(.system(size: 18))
                .foregroundStyle(r.owned ? Theme.gold : Theme.smoke).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(r.owned ? "Sv.\(r.tier) · dk/₺\(fmt(r.perMin))" : "dk/₺\(fmt(r.perMin)) üretir")
                    .font(.system(size: 12)).foregroundStyle(r.owned ? Theme.gold : Theme.smoke)
            }
            Spacer()
            Button { Task { await online.dunyaIsletme(r.idx) } } label: {
                VStack(spacing: 1) {
                    Text(r.owned ? "YÜKSELT" : "AL").font(.system(size: 11, weight: .black))
                    Text("₺\(fmt(r.fiyat))").font(.system(size: 12, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(d.cash >= r.fiyat ? .white : Theme.smoke)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(d.cash >= r.fiyat ? Theme.bloodDim : Theme.panelHi)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }.disabled(d.cash < r.fiyat)
        }.cardStyle(12)
    }

    // MARK: Harita (bölge + vaha fethi + nüfuz)
    private func haritaSekme(_ d: DunyaView) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Label("Nüfuz \(d.nufuzKullanim)/\(d.nufuzKapasite)", systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(d.nufuzKullanim < d.nufuzKapasite ? Theme.gold : Theme.blood)
                    Spacer()
                }
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.blood)
                }
                Text("BÖLGELER").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(d.regions) { b in fetihSatir(ad: b.ad, alt: "dk/₺\(fmt(b.gelirDk))", owned: b.owned, fetihte: b.fetihte, kalan: b.kalan, fiyat: b.fiyat, sure: b.sure, renk: Theme.gold) {
                    Task { await online.dunyaFethet("region", b.idx) }
                } }
                Text("KAÇAK NOKTALARI").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(d.oases) { v in fetihSatir(ad: v.ad, alt: "dk +\(fmt(v.bonusDk)) \(v.tip)", owned: v.owned, fetihte: v.fetihte, kalan: v.kalan, fiyat: v.fiyat, sure: v.sure, renk: v.tip == "nakit" ? Theme.gold : Theme.blood) {
                    Task { await online.dunyaFethet("oasis", v.idx) }
                } }
            }.padding(16)
        }
    }

    private func fetihSatir(ad: String, alt: String, owned: Bool, fetihte: Bool, kalan: Int, fiyat: Int, sure: Int, renk: Color, eylem: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: owned ? "checkmark.seal.fill" : (fetihte ? "flag.fill" : "mappin.and.ellipse"))
                .font(.system(size: 20)).foregroundStyle(owned || fetihte ? renk : Theme.smoke).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(owned ? alt : (fetihte ? "Fethediliyor · \(sureMetni(kalan))" : "₺\(fmt(fiyat)) · \(sureMetni(sure))"))
                    .font(.system(size: 12)).foregroundStyle(owned ? renk : Theme.smoke)
            }
            Spacer()
            if owned {
                Image(systemName: "checkmark").foregroundStyle(renk)
            } else if !fetihte {
                Button(action: eylem) {
                    Text("ELE GEÇİR").font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.bloodDim).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }.cardStyle(12)
    }

    // MARK: Ordu (asker eğitimi + saldırı)
    private func orduSekme(_ d: DunyaView) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.blood)
                }
                if let s = online.sonSaldiri {
                    Text(s.won ? "Baskın başarılı! +₺\(fmt(s.loot)) yağma" : "Baskın patladı — savunma sağlamdı")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(s.won ? Theme.gold : Theme.blood)
                        .frame(maxWidth: .infinity).padding(8).cardStyle(10)
                }
                Text("ORDUN").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    orduKutu("tetikci", d.army["tetikci"] ?? 0)
                    orduKutu("kabadayi", d.army["kabadayi"] ?? 0)
                    orduKutu("sofor", d.army["sofor"] ?? 0)
                }
                if let t = d.train {
                    Text("Eğitimde: \(Self.askerAd[t.tip] ?? t.tip) ×\(t.count) · \(sureMetni(t.kalan))")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }
                Text("ASKER EĞİT (5'er)").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(["tetikci", "kabadayi", "sofor"], id: \.self) { tip in
                    Button { Task { await online.dunyaAsker(tip, 5) } } label: {
                        HStack {
                            Text("\(Self.askerAd[tip] ?? tip) ×5 eğit").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.gold)
                        }.cardStyle(12)
                    }.disabled(d.train != nil)
                }

                Text("SALDIRILACAK OYUNCULAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                if online.dunyaOyuncular.isEmpty {
                    Text("Henüz başka oyuncu yok. Sen ilk reissin.").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                }
                ForEach(online.dunyaOyuncular.prefix(20)) { p in
                    HStack(spacing: 10) {
                        Text(p.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                        Spacer()
                        Text("Güç \(fmt(p.power))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                        Button { Task { await online.dunyaSaldir(p.id) } } label: {
                            Text("SALDIR").font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.blood).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.cardStyle(10)
                }
            }.padding(16)
        }
        .task { await online.dunyaHaritasi() }
    }

    private func orduKutu(_ tip: String, _ sayi: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(sayi)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            Text(Self.askerAd[tip] ?? tip).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity).cardStyle(12)
    }

    // MARK: Dünya (lider tablosu + sendika)
    private func dunyaSekme() -> some View {
        ScrollView {
            VStack(spacing: 12) {
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
                ForEach(Array(online.lider.prefix(30).enumerated()), id: \.element.id) { i, s in
                    HStack(spacing: 10) {
                        Text("#\(i + 1)").font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(i < 3 ? Theme.gold : Theme.smoke).frame(width: 34, alignment: .leading)
                        Text(s.ad).font(.system(size: 14, weight: .bold))
                            .foregroundStyle(s.id == online.me?.id ? Theme.gold : .white).lineLimit(1)
                        Spacer()
                        Text("⚔︎\(s.wins)  ★\(fmt(s.respect))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                    }
                    .padding(.vertical, 4)
                    Divider().background(Color.white.opacity(0.05))
                }
            }.padding(16)
        }
        .task { await online.liderTablosu() }
    }
}
