import SwiftUI

/// SUNUCU-OTORİTER canlı dünya — tüm arayüz sunucudan gelen state'le çalışır.
/// Online'a girince RootView bunu gösterir; aksiyonlar /world/* uçlarına gider.
struct OnlineWorldView: View {
    @EnvironmentObject var online: OnlineService
    @EnvironmentObject var tema: ThemeManager
    @State private var tab = 0
    @State private var magazaAcik = false
    @State private var ayarAcik = false
    @State private var gorevAcik = false
    @State private var fraksiyonAcik = false
    @State private var uslerAcik = false
    @State private var heroAcik = false
    @State private var pazarAcik = false
    @State private var demirciAcik = false
    @State private var harikaAcik = false
    @State private var rehberAcik = false
    @State private var akademiAcik = false
    @State private var rumuzGirildi = false
    @State private var denemeler = 0

    private static let binaAd: [String: String] = [
        "karargah": "Karargah", "kasa": "Kasa Dairesi", "depo": "Depo",
        "cephanelik": "Cephanelik", "kisla": "Kışla", "korunak": "Korunak", "zula": "Zula",
        "belediye": "Belediye", "akademi": "Akademi",
    ]
    private static let binaIkon: [String: String] = [
        "karargah": "flag.2.crossed.fill", "kasa": "banknote.fill", "depo": "shippingbox.fill",
        "cephanelik": "shield.lefthalf.filled", "kisla": "person.3.sequence.fill", "korunak": "lock.shield.fill",
        "zula": "archivebox.fill", "belediye": "building.columns.fill", "akademi": "graduationcap.fill",
    ]
    private static let askerAd: [String: String] = ["tetikci": "Tetikçi", "kabadayi": "Kabadayı", "sofor": "Şoför", "yikici": "Yıkıcı", "sef": "Şef", "suvari": "Süvari", "muhafiz": "Muhafız", "izci": "İzci"]
    private static let askerNot: [String: String] = ["yikici": "bina yıkar", "sef": "üs+başkent fetheder", "suvari": "hızlı saldırı", "muhafiz": "ağır savunma", "izci": "keşif"]

    var body: some View {
        Group {
            if let d = online.dunya {
                ZStack {
                    Theme.bg.ignoresSafeArea()
                    VStack(spacing: 0) {
                        kaynakBar
                        if let sad = d.konakSadakat, sad < 100 {
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill").foregroundStyle(.white)
                                Text("Başkent sadakati %\(sad) — düşman şefi başkentini fethetmeye çalışıyor! Muhafız/kabadayı ile savun.")
                                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                Spacer()
                            }.padding(.horizontal, 14).padding(.vertical, 8)
                                .background(sad < 40 ? Theme.blood : Theme.bloodDim)
                        }
                        if (d.fraksiyon ?? "").isEmpty {
                            Button { fraksiyonAcik = true } label: {
                                HStack {
                                    Label("FRAKSİYONUNU SEÇ", systemImage: "shield.checkered").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                                    Spacer()
                                    Text("kalıcı bonus →").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.blood)
                            }
                        }
                        TabView(selection: $tab) {
                            OnlineKoyView().tag(0).tabItem { Label("Üs", systemImage: "building.2.fill") }
                            OnlineHaritaView().tag(1).tabItem { Label("Harita", systemImage: "map.fill") }
                            orduSekme(d).tag(2).tabItem { Label("Ordu", systemImage: "figure.walk") }
                            dunyaSekme().tag(3).tabItem { Label("Dünya", systemImage: "trophy.fill") }
                            OnlineCeteView().tag(4).tabItem { Label("Çete", systemImage: "shield.lefthalf.filled") }
                        }
                        .tint(Theme.blood)
                    }
                }
            } else if !online.hesapVar && !rumuzGirildi {
                // İlk açılış: oyuncu kendi rumuzunu oluşturur, sonra dünyaya girer.
                RumuzGirisView { ad in
                    online.ad = ad
                    rumuzGirildi = true
                    Task { await girisDongu() }
                }
            } else {
                yuklemeEkrani
            }
        }
        .task {
            // Gerçek cihaz+uygulama doğrulaması (App Attest) ARKA PLANDA — açılışı bloklamaz.
            // Okuma uçları açık; token yalnız hassas aksiyonlar için gerekir ve onlara yetişir.
            Task { await online.attestSaglat() }
            // Dönen kullanıcı (anonim/SMS hesabı var): otomatik giriş.
            if online.hesapVar { await girisDongu() }
            if online.dunya != nil { await online.gorevlerCek() }
            // Canlı poll: dünya yüklendiğinde her 3 sn tazele.
            var say = 0
            while true {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if online.dunya != nil {
                    await online.dunyaCek()
                    say += 1
                    if say % 4 == 0 { await online.gorevlerCek(); await online.heroCek() }   // ~12 sn'de görev+kahraman tazele
                }
            }
        }
        .sheet(isPresented: $magazaAcik) {
            NavigationStack {
                MagazaView()
                    .navigationTitle("Mağaza").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { magazaAcik = false } } }
                    .background(Theme.coal)
            }
            .preferredColorScheme(tema.colorScheme)
        }
        .sheet(isPresented: $ayarAcik) {
            NavigationStack {
                AyarlarView()
                    .navigationTitle("Ayarlar").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { ayarAcik = false } } }
                    .background(Theme.coal)
            }
            .preferredColorScheme(tema.colorScheme)
        }
        .sheet(isPresented: $gorevAcik) {
            NavigationStack {
                GorevlerView()
                    .navigationTitle("Günlük Görevler").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { gorevAcik = false } } }
                    .background(Theme.bg)
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $fraksiyonAcik) {
            NavigationStack {
                FraksiyonView { kod in Task { await online.fraksiyonSec(kod); fraksiyonAcik = false } }
                    .navigationTitle("Fraksiyon Seç").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $uslerAcik) {
            NavigationStack {
                UslerView()
                    .navigationTitle("Üsler & Fetih").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { uslerAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $heroAcik) {
            NavigationStack {
                KahramanView()
                    .navigationTitle("Kahraman").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { heroAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $pazarAcik) {
            NavigationStack {
                PazarView()
                    .navigationTitle("Pazar & Diplomasi").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { pazarAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $demirciAcik) {
            NavigationStack {
                DemirciView()
                    .navigationTitle("Demirci").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { demirciAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $harikaAcik) {
            NavigationStack {
                HarikaView()
                    .navigationTitle("Dünya Harikası").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { harikaAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $rehberAcik) {
            NavigationStack {
                BirlikRehberiView()
                    .navigationTitle("Birlik Rehberi").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { rehberAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
        .sheet(isPresented: $akademiAcik) {
            NavigationStack {
                AkademiView()
                    .navigationTitle("Akademi & Kültür").navigationBarTitleDisplayMode(.inline)
                    .background(Theme.bg)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { akademiAcik = false } } }
            }
            .preferredColorScheme(tema.colorScheme).environmentObject(online)
        }
    }

    // MARK: Giriş döngüsü + yükleme ekranı (kilitlenmeden kurtulur)
    /// Dünya gelene kadar dene; her başarısızlıkta sayaç artar (kurtarma UI'ı için).
    private func girisDongu() async {
        while online.dunya == nil {
            await online.dunyayaGir()
            if online.dunya == nil {
                denemeler += 1
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        denemeler = 0
    }

    private var yuklemeEkrani: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(Theme.gold)
                Text("Canlı dünya yükleniyor…")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                // Birkaç denemede yüklenmediyse hatayı göster + kurtarma seçenekleri.
                if denemeler >= 2 {
                    VStack(spacing: 12) {
                        Text(online.hata ?? "Sunucuya bağlanılamıyor. İnternet bağlantını kontrol et.")
                            .font(.system(size: 12)).foregroundStyle(Theme.blood)
                            .multilineTextAlignment(.center).padding(.horizontal, 28)
                        Button {
                            denemeler = 0
                            Task { await girisDongu() }
                        } label: {
                            Text("Tekrar Dene").font(.system(size: 15, weight: .black))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Theme.blood).foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 44)
                        Button {
                            online.tamSifirla()
                            rumuzGirildi = false
                            denemeler = 0
                        } label: {
                            Text("Sıfırdan başla (yeni hesap)")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                        }
                    }
                    .padding(.top, 12)
                }
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
            Button { gorevAcik = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "checklist").font(.system(size: 16)).foregroundStyle(Theme.gold)
                    if online.gorevler.contains(where: { $0.tamam && !$0.alindi }) {
                        Circle().fill(Theme.blood).frame(width: 8, height: 8).offset(x: 4, y: -3)
                    }
                }
            }
            Button { uslerAcik = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "map.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
                    if let d = d, (d.usSayisi ?? 0) < (d.usLimit ?? 0) {
                        Circle().fill(Theme.blood).frame(width: 8, height: 8).offset(x: 4, y: -3)
                    }
                }
            }
            Button { heroAcik = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "figure.stand").font(.system(size: 16)).foregroundStyle(Theme.gold)
                    if online.hero?.macera?.biterMi == true || (online.hero?.sp ?? 0) > 0 {
                        Circle().fill(Theme.blood).frame(width: 8, height: 8).offset(x: 4, y: -3)
                    }
                }
            }
            Button { pazarAcik = true } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
            }
            Button { magazaAcik = true } label: {
                Image(systemName: "cart.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
            }
            Button { ayarAcik = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 16)).foregroundStyle(Theme.smoke)
            }
            if (d?.gelenBaskin ?? 0) > 0 {
                Label("\(d?.gelenBaskin ?? 0)", systemImage: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.blood).clipShape(Capsule())
            }
            Text("Sv.\(d?.bossLevel ?? 1)").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.coal)
    }

    private func kaynak(_ icon: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
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
                (Text(LocalizedStringKey(Self.binaAd[b.tip] ?? b.tip)) + Text(" · Sv.\(b.seviye)")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
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
                Text(LocalizedStringKey(r.ad)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
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
                Text(LocalizedStringKey(ad)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
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

    // MARK: Ordu (asker eğitimi + zamanlı baskın + savunma)
    private func orduSekme(_ d: DunyaView) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity).padding(8).cardStyle(10)
                }
                // GELEN BASKINLAR — savunma alarmı (kırmızı, geri sayım)
                if !online.gelenBaskin.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("SANA GELEN BASKIN!", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                        ForEach(online.gelenBaskin) { g in
                            HStack {
                                Text("\(g.saldiran) · \(g.buyukluk) kuvvet").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                Spacer()
                                Text(sureMetni(g.kalan)).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            }
                        }
                        Text("Varmadan asker eğit / Korunak yükselt → savunmanı artır!")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(Theme.blood).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                // YOLDAKİ BASKINLARIM
                if !online.gidenBaskin.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOLDAKİ BASKINLARIM").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                        ForEach(online.gidenBaskin) { g in
                            HStack {
                                Image(systemName: g.durum.contains("döndü") ? "arrow.uturn.left" : "figure.walk").foregroundStyle(Theme.gold)
                                Text(g.hedef).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(g.durum) · \(sureMetni(g.kalan))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
                }
                Text("ORDUN").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(["tetikci", "kabadayi", "sofor", "suvari", "muhafiz", "yikici", "sef", "izci"], id: \.self) { tip in
                        orduKutu(tip, d.army[tip] ?? 0)
                    }
                }
                if let idame = d.idameDk, idame > 0 {
                    Text("Besleme gideri: −₺\(idame)/dk (ordu büyüdükçe gelir azalır)")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let t = d.train {
                    Text("Eğitimde: \(Self.askerAd[t.tip] ?? t.tip) ×\(t.count) · \(sureMetni(t.kalan))")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }
                HStack(spacing: 12) {
                    Text("ASKER EĞİT").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                    Spacer()
                    Button { rehberAcik = true } label: {
                        Label("Rehber", systemImage: "book.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                    }
                    Button { akademiAcik = true } label: {
                        Label("Akademi", systemImage: "graduationcap.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                    }
                    Button { demirciAcik = true } label: {
                        Label("Demirci", systemImage: "hammer.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                    }
                }.frame(maxWidth: .infinity)
                ForEach(["tetikci", "kabadayi", "sofor", "suvari", "muhafiz", "yikici", "sef", "izci"], id: \.self) { tip in
                    let adet = (tip == "yikici" || tip == "sef") ? 1 : 5
                    Button { Task { await online.dunyaAsker(tip, adet) } } label: {
                        HStack {
                            (Text(LocalizedStringKey(Self.askerAd[tip] ?? tip)) + Text(" ×\(adet)")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                            if let n = Self.askerNot[tip] { Text(n).font(.system(size: 10)).foregroundStyle(Theme.blood) }
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
                    HStack(spacing: 8) {
                        Text(p.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        Spacer(minLength: 2)
                        Button { Task { await online.casusGonder(p.id) } } label: {
                            Image(systemName: "eye.fill").font(.system(size: 13)).foregroundStyle(Theme.smoke)
                                .padding(6).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        Button { Task { await online.farmEkle(p.id) } } label: {
                            Image(systemName: "list.star").font(.system(size: 13)).foregroundStyle(Theme.gold)
                                .padding(6).background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        Button { Task { await online.dunyaSaldir(p.id) } } label: {
                            Text("SALDIR").font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Theme.blood).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.cardStyle(10)
                }

                // CASUS RAPORU
                if let cs = online.casusSonuc {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("CASUS RAPORU · \(cs.ad)", systemImage: "eye.fill").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                        Text("Ordu: tetikçi \(cs.army["tetikci"] ?? 0) · kabadayı \(cs.army["kabadayi"] ?? 0) · şoför \(cs.army["sofor"] ?? 0)")
                            .font(.system(size: 12)).foregroundStyle(Theme.ink)
                        Text("Savunma: \(fmt(cs.savunma)) · Korunak Sv.\(cs.korunak) · Yağmalanabilir: ₺\(fmt(cs.nakit))")
                            .font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
                }

                // YAĞMA LİSTESİ (farm list)
                if !online.farmHedefler.isEmpty {
                    HStack {
                        Text("YAĞMA LİSTESİ").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                        Spacer()
                        Button { Task { await online.farmAkin() } } label: {
                            Label("HEPSİNE AKIN", systemImage: "bolt.fill").font(.system(size: 11, weight: .black))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Theme.gold).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    ForEach(online.farmHedefler) { f in
                        HStack(spacing: 8) {
                            Image(systemName: f.kalkanli ? "shield.fill" : "target").foregroundStyle(f.kalkanli ? Theme.smoke : Theme.blood)
                            Text(f.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                            Spacer()
                            Text(f.kalkanli ? "kalkanlı" : "Güç \(fmt(f.guc))").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                            Button { Task { await online.farmKaldir(f.id) } } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.smoke)
                            }
                        }.cardStyle(10)
                    }
                }

                // BASKIN RAPORLARI
                if !online.baskinRapor.isEmpty {
                    Text("RAPORLAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(online.baskinRapor.prefix(12)) { r in
                        HStack(spacing: 10) {
                            Image(systemName: r.kazandim ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundStyle(r.kazandim ? Theme.gold : Theme.blood)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(r.tur == "savunma" ? "Savunma" : "Baskın") · \(r.rakip)")
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                                Text(r.kazandim ? (r.tur == "savunma" ? "Savundun" : "Kazandın · +₺\(fmt(r.yagma)) yağma") : (r.tur == "savunma" ? "Yağmalandın" : "Kaybettin"))
                                    .font(.system(size: 11)).foregroundStyle(r.kazandim ? Theme.gold : Theme.smoke)
                            }
                            Spacer()
                        }.cardStyle(10)
                    }
                }
            }.padding(16)
        }
        .task {
            await online.dunyaHaritasi()
            await online.baskinlariCek()
            await online.farmCek()
            await online.takviyeBilgiCek()
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await online.baskinlariCek()
            }
        }
    }

    private func orduKutu(_ tip: String, _ sayi: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(sayi)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            Text(LocalizedStringKey(Self.askerAd[tip] ?? tip)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity).cardStyle(12)
    }

    // MARK: Dünya (sezon + lider tablosu + onur listesi)
    private func dunyaSekme() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // DÜNYA HARİKASI — endgame zaferi
                Button { harikaAcik = true } label: {
                    HStack {
                        Image(systemName: "building.columns.circle.fill").foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DÜNYA HARİKASI").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                            Text(online.harika.map { $0.seviye >= $0.maks ? "Zafer kazanıldı!" : "Sv.\($0.seviye)/\($0.maks) — sezonu kazan" } ?? "çeteyle inşa et, sezonu kazan")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.8))
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                        .background(LinearGradient(colors: [Theme.blood, Theme.gold], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                // SEZON banner — geri sayım + kendi skorun
                if let sz = online.sezon {
                    VStack(spacing: 6) {
                        HStack {
                            Label("SEZON \(sz.no)", systemImage: "crown.fill").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.gold)
                            Spacer()
                            Text("Bitişe \(sureMetni(sz.kalan))").font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
                        }
                        HStack {
                            Text("Sezon skorun: \(fmt(sz.benimSkor))").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke)
                            Spacer()
                            Text("Sezon sonunda #1 = KRAL").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                        }
                        if let ilk = sz.top.first {
                            Text("Lider: \(ilk.ad) · \(fmt(ilk.skor))").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.frame(maxWidth: .infinity).cardStyle(14)
                    // Sezon top 5
                    if !sz.top.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SEZON SIRALAMASI").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                            ForEach(Array(sz.top.prefix(5).enumerated()), id: \.element.id) { i, r in
                                HStack {
                                    Text("#\(i+1)").font(.system(size: 13, weight: .heavy)).foregroundStyle(i < 3 ? Theme.gold : Theme.smoke).frame(width: 30, alignment: .leading)
                                    Text(r.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(fmt(r.skor)).font(.system(size: 12)).foregroundStyle(Theme.gold)
                                }.padding(.vertical, 2)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
                    }
                    // Onur listesi (geçmiş krallar)
                    if !sz.onur.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ONUR LİSTESİ — GEÇMİŞ KRALLAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                            ForEach(sz.onur) { o in
                                HStack {
                                    Image(systemName: "crown.fill").font(.system(size: 12)).foregroundStyle(Theme.gold)
                                    Text("Sezon \(o.sezon): \(o.ad)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Text(fmt(o.skor)).font(.system(size: 12)).foregroundStyle(Theme.smoke)
                                }.padding(.vertical, 2)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
                    }
                }
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
                            .foregroundStyle(s.id == online.me?.id ? Theme.gold : Theme.ink).lineLimit(1)
                        Spacer()
                        Text("⚔︎\(s.wins)  ★\(fmt(s.respect))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                    }
                    .padding(.vertical, 4)
                    Divider().background(Color.white.opacity(0.05))
                }

                // KATEGORİ SIRALAMALARI
                if let s = online.siralama {
                    siraKutu("EN ÇOK BASKIN YAPAN", s.saldirgan, "flame.fill", Theme.blood)
                    siraKutu("EN İYİ SAVUNAN", s.savunmaci, "shield.lefthalf.filled", Theme.gold)
                    siraKutu("EN GÜÇLÜ ÇETELER", s.cete, "person.3.fill", Theme.gold)
                }
            }.padding(16)
        }
        .task { await online.liderTablosu(); await online.sezonCek(); await online.siralamaCek() }
    }

    private func siraKutu(_ baslik: String, _ liste: [SiraSatir], _ ikon: String, _ renk: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(baslik, systemImage: ikon).font(.system(size: 12, weight: .black)).foregroundStyle(renk)
            if liste.isEmpty {
                Text("Henüz veri yok.").font(.system(size: 11)).foregroundStyle(Theme.smoke)
            }
            ForEach(Array(liste.prefix(5).enumerated()), id: \.element.id) { i, r in
                HStack {
                    Text("#\(i+1)").font(.system(size: 12, weight: .heavy)).foregroundStyle(i < 3 ? Theme.gold : Theme.smoke).frame(width: 28, alignment: .leading)
                    Text(r.ad).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text(fmt(r.deger)).font(.system(size: 12)).foregroundStyle(renk)
                }.padding(.vertical, 1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
    }
}
