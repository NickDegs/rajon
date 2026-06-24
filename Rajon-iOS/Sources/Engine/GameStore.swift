import SwiftUI
import Combine

/// Diske kaydedilen oyun durumu.
/// Decodable manuel: yeni alanlar `decodeIfPresent` ile okunur → eski kayıt güncellemede
/// silinmez (ilerleme korunur). Yeni alan eklerken aynı kalıbı kullan.
struct SaveState: Codable {
    var cash: Int
    var respect: Int            // toplam itibar = seviye/ilerleme
    var crew: [Enforcer]
    var squad: [UUID]           // sahadaki ekip (max 4), sıralı
    var rackets: [Racket]
    var rivals: [RivalNode]
    var lastSeen: Date
    var devsirmeCost: Int       // bir sonraki devşirme maliyeti
    var vipAktif: Bool = false  // Kan Parası VIP (2x gelir)
    var vipSonBonus: Date = .distantPast
    var gunlukBonusTarih: Date = .distantPast   // son alınan günlük bonus
    var gunlukSeri: Int = 0                      // ardışık gün serisi
    var envanter: [Gear] = []                    // takılı olmayan teçhizat
    var gorevler: [Gorev] = []                   // günlük görevler
    var gorevTarih: Date = .distantPast          // görevlerin üretildiği gün
    var binalar: [Bina] = []                     // mahalle binaları
    var ordu: [String: Int] = [:]                // asker sayıları
    var egitim: EgitimIs? = nil                  // eğitim kuyruğu
    var seferler: [Sefer] = []                   // aktif akınlar
    var cephane: Int = 200                       // mühimmat
    var raporlar: [Rapor] = []                   // raporlar
    var bolgeler: [Bolge] = []                   // şehir bölgeleri

    init(cash: Int, respect: Int, crew: [Enforcer], squad: [UUID], rackets: [Racket],
         rivals: [RivalNode], lastSeen: Date, devsirmeCost: Int, vipAktif: Bool,
         vipSonBonus: Date, gunlukBonusTarih: Date, gunlukSeri: Int, envanter: [Gear],
         gorevler: [Gorev], gorevTarih: Date, binalar: [Bina],
         ordu: [String: Int], egitim: EgitimIs?, seferler: [Sefer], cephane: Int,
         raporlar: [Rapor], bolgeler: [Bolge]) {
        self.cash = cash; self.respect = respect; self.crew = crew; self.squad = squad
        self.rackets = rackets; self.rivals = rivals; self.lastSeen = lastSeen
        self.devsirmeCost = devsirmeCost; self.vipAktif = vipAktif; self.vipSonBonus = vipSonBonus
        self.gunlukBonusTarih = gunlukBonusTarih; self.gunlukSeri = gunlukSeri; self.envanter = envanter
        self.gorevler = gorevler; self.gorevTarih = gorevTarih; self.binalar = binalar
        self.ordu = ordu; self.egitim = egitim; self.seferler = seferler
        self.cephane = cephane; self.raporlar = raporlar; self.bolgeler = bolgeler
    }

    init(from dec: Decoder) throws {
        let c = try dec.container(keyedBy: CodingKeys.self)
        cash = try c.decode(Int.self, forKey: .cash)
        respect = try c.decode(Int.self, forKey: .respect)
        crew = try c.decode([Enforcer].self, forKey: .crew)
        squad = try c.decode([UUID].self, forKey: .squad)
        rackets = try c.decode([Racket].self, forKey: .rackets)
        rivals = try c.decode([RivalNode].self, forKey: .rivals)
        lastSeen = try c.decode(Date.self, forKey: .lastSeen)
        devsirmeCost = try c.decode(Int.self, forKey: .devsirmeCost)
        vipAktif = try c.decodeIfPresent(Bool.self, forKey: .vipAktif) ?? false
        vipSonBonus = try c.decodeIfPresent(Date.self, forKey: .vipSonBonus) ?? .distantPast
        gunlukBonusTarih = try c.decodeIfPresent(Date.self, forKey: .gunlukBonusTarih) ?? .distantPast
        gunlukSeri = try c.decodeIfPresent(Int.self, forKey: .gunlukSeri) ?? 0
        envanter = try c.decodeIfPresent([Gear].self, forKey: .envanter) ?? []
        gorevler = try c.decodeIfPresent([Gorev].self, forKey: .gorevler) ?? []
        gorevTarih = try c.decodeIfPresent(Date.self, forKey: .gorevTarih) ?? .distantPast
        binalar = try c.decodeIfPresent([Bina].self, forKey: .binalar) ?? []
        ordu = try c.decodeIfPresent([String: Int].self, forKey: .ordu) ?? [:]
        egitim = try c.decodeIfPresent(EgitimIs.self, forKey: .egitim)
        seferler = try c.decodeIfPresent([Sefer].self, forKey: .seferler) ?? []
        cephane = try c.decodeIfPresent(Int.self, forKey: .cephane) ?? 200
        raporlar = try c.decodeIfPresent([Rapor].self, forKey: .raporlar) ?? []
        bolgeler = try c.decodeIfPresent([Bolge].self, forKey: .bolgeler) ?? []
    }
}

/// Bütün oyun mantığını yöneten gözlemlenebilir depo.
@MainActor
final class GameStore: ObservableObject {
    @Published var cash: Int = 0
    @Published var cephane: Int = 200       // mühimmat (2. kaynak)
    @Published var respect: Int = 0
    @Published var crew: [Enforcer] = []
    @Published var squad: [UUID] = []
    @Published var rackets: [Racket] = []
    @Published var rivals: [RivalNode] = []
    @Published var devsirmeCost: Int = 500
    @Published var vipAktif: Bool = false   // Kan Parası VIP — 2x gelir + günlük bonus

    @Published var envanter: [Gear] = []    // takılı olmayan teçhizat
    @Published var binalar: [Bina] = []     // mahalle binaları
    @Published var bolgeler: [Bolge] = []   // şehir bölgeleri
    @Published var ordu: [String: Int] = [:]   // AskerTip.rawValue -> sayı
    @Published var egitim: EgitimIs? = nil     // asker eğitim kuyruğu
    @Published var seferler: [Sefer] = []      // aktif akınlar
    @Published var raporlar: [Rapor] = []      // akın/baskın/savunma raporları
    @Published var gorevler: [Gorev] = []   // günlük görevler
    private var gorevTarih = Date.distantPast
    @Published var idleKazanc: Int = 0      // toplanmayı bekleyen nakit
    @Published var gunlukSeri: Int = 0      // ardışık giriş günü serisi
    private var lastSeen = Date()
    private var vipSonBonus = Date.distantPast
    private var gunlukBonusTarih = Date.distantPast
    private var cephaneAcc: Double = 0      // mühimmat üretim kesir biriktirici
    private var timer: AnyCancellable?

    private let saveURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rajon_save.json")
    }()

    // MARK: Seviye

    /// İtibara göre patron seviyesi.
    var bossLevel: Int { 1 + Int((Double(respect) / 100.0).squareRoot()) }

    var squadEnforcers: [Enforcer] { squad.compactMap { id in crew.first { $0.id == id } } }
    var squadPower: Int { squadEnforcers.reduce(0) { $0 + $1.guc } }

    // MARK: Yaşam döngüsü

    func bootstrap() {
        if !load() { newGame() }
        accrueIdle()
        gorevleriTazele()
        startTimer()
    }

    private func newGame() {
        cash = 1_500
        respect = 0
        rackets = Factory.makeRackets()
        rivals = Factory.makeRivalLadder()
        binalar = BinaTip.allCases.map { Bina(tip: $0, seviye: $0.baslangic) }
        bolgeler = Factory.makeBolgeler()
        devsirmeCost = 500
        // Başlangıç ekibi: 3 adam
        let baslangic = [
            Factory.makeEnforcer(rarity: .tetikci, klas: .yumruk),
            Factory.makeEnforcer(rarity: .sokak, klas: .tetik),
            Factory.makeEnforcer(rarity: .sokak, klas: .bicak)
        ]
        crew = baslangic
        squad = baslangic.map { $0.id }
        lastSeen = Date()
        save()
    }

    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    /// Gelir çarpanı her zaman 1.0 — pay-to-win YOK, satın alımlar gücü etkilemez.
    var gelirCarpani: Double { 1.0 }

    private func tick() {
        let kazanc = saniyelikGelir
        idleKazanc += Int(kazanc.rounded())
        insaatlariKontrolEt()
        fetihleriKontrolEt()
        egitimVeSeferleriKontrolEt()
        cephaneUret()
        // birikim kapasitesini aşma
        let cap = depoKapasite
        if idleKazanc > cap { idleKazanc = cap }
        // periyodik kayıt (her ~15 sn)
        if Int(Date().timeIntervalSince1970) % 15 == 0 { save() }
    }

    /// Uygulama kapalıyken biriken idle kazancı hesapla.
    private func accrueIdle() {
        let dt = Date().timeIntervalSince(lastSeen)
        guard dt > 0 else { return }
        let capped = min(dt, depoCapSaat * 3600)
        idleKazanc += Int(saniyelikGelir * capped)
        if idleKazanc > depoKapasite { idleKazanc = depoKapasite }
    }

    // MARK: Ekonomi

    var ownedRackets: [Racket] { rackets.filter { $0.owned } }
    /// Ele geçirilmiş bölgelerin dakikalık geliri.
    var bolgeGeliriDk: Int { bolgeler.filter { $0.eleGecirildi }.reduce(0) { $0 + $1.gelirDk } }

    /// Saniyelik toplam gelir (haraç + Kasa binası + bölgeler).
    var saniyelikGelir: Double {
        let racket = ownedRackets.reduce(0.0) { $0 + $1.perSec }
        let kasaVeBolge = Double(kasaBonusPerMin + bolgeGeliriDk) / 60.0
        return (racket + kasaVeBolge) * gelirCarpani
    }
    var gelirPerMin: Int {
        Int((Double(ownedRackets.reduce(0) { $0 + $1.perMin }) + Double(kasaBonusPerMin + bolgeGeliriDk)) * gelirCarpani)
    }

    // MARK: Bölge fethi (çoklu mahalle)
    var fetihMesgul: Bool { bolgeler.contains { $0.fetihte } }
    var fetihtekiBolge: Bolge? { bolgeler.first { $0.fetihte } }
    var eleGecirilen: Int { bolgeler.filter { $0.eleGecirildi }.count }

    func bolgeFethet(_ id: UUID) {
        guard !fetihMesgul, let i = bolgeler.firstIndex(where: { $0.id == id }),
              !bolgeler[i].eleGecirildi else { return }
        let fiyat = bolgeler[i].maliyet
        guard cash >= fiyat else { return }
        cash -= fiyat
        // Karargah fethi de hızlandırır
        bolgeler[i].fetihBitis = Date().addingTimeInterval(bolgeler[i].sure * insaatHizCarpani)
        Haptics.tik()
        save()
    }

    private func fetihleriKontrolEt() {
        var degisti = false
        for i in bolgeler.indices {
            if let b = bolgeler[i].fetihBitis, b <= Date() {
                bolgeler[i].eleGecirildi = true
                bolgeler[i].fetihBitis = nil
                degisti = true
                raporEkle("Bölge ele geçirildi: \(bolgeler[i].ad)",
                          "Artık dk/₺\(bolgeler[i].gelirDk) gelir getiriyor", kazandi: true)
            }
        }
        if degisti { save() }
    }

    // MARK: Mahalle / inşaat (Travian tarzı)

    func binaSeviye(_ tip: BinaTip) -> Int { binalar.first { $0.tip == tip }?.seviye ?? 0 }

    var kasaBonusPerMin: Int { 80 * binaSeviye(.kasa) }
    var depoCapSaat: Double { 8 + 3 * Double(binaSeviye(.depo)) }       // birikim süresi
    var depoKapasite: Int { 200_000 + binaSeviye(.depo) * 250_000 }     // tavan nakit
    var maxKadro: Int { min(6, 4 + binaSeviye(.kisla) / 2) }            // saha kadrosu
    var cephanelikBonus: Double { 1.0 + 0.07 * Double(binaSeviye(.cephanelik)) } // saldırı çarpanı
    var korunakSavunma: Int { 60 * binaSeviye(.korunak) }

    // Mühimmat (2. kaynak) — Cephanelik üretir
    var cephaneUretimDk: Int { 30 * binaSeviye(.cephanelik) }
    var cephaneMax: Int { 1_500 + 700 * binaSeviye(.cephanelik) }
    private func cephaneUret() {
        guard cephaneUretimDk > 0, cephane < cephaneMax else { return }
        cephaneAcc += Double(cephaneUretimDk) / 60.0
        if cephaneAcc >= 1 {
            cephane = min(cephaneMax, cephane + Int(cephaneAcc))
            cephaneAcc -= Double(Int(cephaneAcc))
        }
    }
    // Karaborsa kurları
    let cephaneAlisKuru = 12   // 1 mühimmat = 12 nakit (al)
    let cephaneSatisKuru = 6   // 1 mühimmat = 6 nakit (sat)
    func cephaneAl(_ miktar: Int) {
        let fiyat = miktar * cephaneAlisKuru
        guard miktar > 0, cash >= fiyat, cephane + miktar <= cephaneMax else { return }
        cash -= fiyat; cephane += miktar; Haptics.tik(); save()
    }
    func cephaneSat(_ miktar: Int) {
        guard miktar > 0, cephane >= miktar else { return }
        cephane -= miktar; cash += miktar * cephaneSatisKuru; Haptics.tik(); save()
    }
    /// Karargah inşaatları hızlandırır.
    var insaatHizCarpani: Double { 1.0 / (1.0 + 0.07 * Double(binaSeviye(.karargah))) }
    var insaatMesgul: Bool { binalar.contains { $0.insaatta } }
    var insaattakiBina: Bina? { binalar.first { $0.insaatta } }

    func binaSure(_ bina: Bina) -> Double { bina.temelSure * insaatHizCarpani }

    /// Bir binayı inşa et / bir seviye yükselt (tek kuyruk).
    func binaYukselt(_ id: UUID) {
        guard !insaatMesgul, let i = binalar.firstIndex(where: { $0.id == id }) else { return }
        let fiyat = binalar[i].yukseltmeMaliyet
        guard cash >= fiyat else { return }
        cash -= fiyat
        binalar[i].insaatBitis = Date().addingTimeInterval(binaSure(binalar[i]))
        Haptics.tik()
        save()
    }

    /// İnşaatı nakitle anında bitir (hızlandır).
    func binaHizlandir(_ id: UUID) {
        guard let i = binalar.firstIndex(where: { $0.id == id }),
              let bitis = binalar[i].insaatBitis else { return }
        let kalan = max(0, bitis.timeIntervalSinceNow)
        let fiyat = Int(kalan * 50) + 500
        guard cash >= fiyat else { return }
        cash -= fiyat
        binalar[i].seviye += 1
        binalar[i].insaatBitis = nil
        Haptics.basari()
        save()
    }

    private func insaatlariKontrolEt() {
        var degisti = false
        for i in binalar.indices {
            if let b = binalar[i].insaatBitis, b <= Date() {
                binalar[i].seviye += 1
                binalar[i].insaatBitis = nil
                degisti = true
            }
        }
        if degisti { save() }
    }

    // MARK: Asker eğitimi + sefer/akın

    func orduSayi(_ tip: AskerTip) -> Int { ordu[tip.rawValue] ?? 0 }
    var orduToplam: Int { ordu.values.reduce(0, +) }
    var orduSaldiri: Int { AskerTip.allCases.reduce(0) { $0 + orduSayi($1) * $1.saldiri } }
    var orduSavunma: Int { AskerTip.allCases.reduce(0) { $0 + orduSayi($1) * $1.savunma } }
    var orduYagmaKap: Int { AskerTip.allCases.reduce(0) { $0 + orduSayi($1) * $1.yagma } }
    var seferdeMi: Bool { !seferler.isEmpty }

    /// Kışla seviyesi eğitimi hızlandırır.
    private var egitimHiz: Double { 1.0 / (1.0 + 0.05 * Double(binaSeviye(.kisla))) }

    func askerEgit(_ tip: AskerTip, sayi: Int) {
        guard egitim == nil, sayi > 0 else { return }
        let fiyat = tip.maliyet * sayi
        let cephaneFiyat = tip.cephaneMaliyet * sayi
        guard cash >= fiyat, cephane >= cephaneFiyat else { return }
        cash -= fiyat
        cephane -= cephaneFiyat
        let sure = tip.egitimSure * Double(sayi) * egitimHiz
        egitim = EgitimIs(tip: tip, sayi: sayi, bitis: Date().addingTimeInterval(sure))
        Haptics.tik()
        save()
    }

    /// Tüm orduyu bir hedefe akına gönder.
    func seferGonder(hedefAd: String, hedefGuc: Int, sure: Double, taliMax: Int) {
        guard orduToplam > 0 else { return }
        let yagma = min(taliMax, orduYagmaKap)
        let s = Sefer(hedefAd: hedefAd, hedefGuc: hedefGuc, gonderilen: ordu,
                      donus: Date().addingTimeInterval(sure), oduuncash: yagma)
        seferler.append(s)
        ordu = [:]   // birlikler yola çıktı
        Haptics.tik()
        save()
    }

    func raporEkle(_ baslik: String, _ detay: String, kazandi: Bool) {
        raporlar.insert(Rapor(baslik: baslik, detay: detay, kazandi: kazandi), at: 0)
        if raporlar.count > 40 { raporlar = Array(raporlar.prefix(40)) }
        save()
    }

    private func egitimVeSeferleriKontrolEt() {
        var degisti = false
        // eğitim bitti mi
        if let e = egitim, e.bitis <= Date() {
            ordu[e.tip.rawValue, default: 0] += e.sayi
            egitim = nil
            degisti = true
        }
        // dönen seferler
        for s in seferler where s.dondu {
            let gonderilenSaldiri = AskerTip.allCases.reduce(0) {
                $0 + (s.gonderilen[$1.rawValue] ?? 0) * $1.saldiri
            }
            let kazandi = gonderilenSaldiri >= s.hedefGuc
            let gonderilenSayi = s.gonderilen.values.reduce(0, +)
            if kazandi {
                cash += s.oduuncash
                respect += 10
                // birliklerin çoğu döner (küçük kayıp)
                var donen = 0
                for (k, v) in s.gonderilen { let d = Int(Double(v) * 0.92); ordu[k, default: 0] += d; donen += d }
                gorevIlerlet(.baskin)
                raporEkle("Akın başarılı: \(s.hedefAd)",
                          "₺\(s.oduuncash) yağma · \(donen)/\(gonderilenSayi) adam döndü", kazandi: true)
            } else {
                // yenilgi: yarısı döner
                var donen = 0
                for (k, v) in s.gonderilen { let d = v / 2; ordu[k, default: 0] += d; donen += d }
                raporEkle("Akın başarısız: \(s.hedefAd)",
                          "Yağma yok · \(donen)/\(gonderilenSayi) adam döndü, gerisi kaldı", kazandi: false)
            }
            degisti = true
        }
        seferler.removeAll { $0.dondu }
        if degisti { save() }
    }

    func haracTopla() {
        guard idleKazanc > 0 else { return }
        cash += idleKazanc
        idleKazanc = 0
        gorevIlerlet(.harac)
        SoundManager.shared.cal(.coin)
        Haptics.tik()
        save()
    }

    // MARK: Günlük bonus

    /// Bugün günlük bonus alınabilir mi.
    var gunlukBonusVar: Bool {
        !Calendar.current.isDate(gunlukBonusTarih, inSameDayAs: Date())
    }

    /// Günlük bonus tutarı (seri + patron seviyesiyle artar, VIP 2x).
    var gunlukBonusTutar: Int {
        let taban = 5_000 + bossLevel * 2_000
        let seriCarpan = 1.0 + Double(min(gunlukSeri, 6)) * 0.25   // 7. günde ~2.5x
        return Int(Double(taban) * seriCarpan * gelirCarpani)
    }

    @discardableResult
    func gunlukBonusAl() -> Int {
        guard gunlukBonusVar else { return 0 }
        // Seri: dün alındıysa devam, değilse sıfırla
        let dun = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if Calendar.current.isDate(gunlukBonusTarih, inSameDayAs: dun) {
            gunlukSeri = min(gunlukSeri + 1, 6)
        } else {
            gunlukSeri = 0
        }
        let tutar = gunlukBonusTutar
        cash += tutar
        gunlukBonusTarih = Date()
        SoundManager.shared.cal(.coin)
        Haptics.basari()
        save()
        return tutar
    }

    func racketSatinAlVeyaYukselt(_ id: UUID) {
        guard let i = rackets.firstIndex(where: { $0.id == id }) else { return }
        if !rackets[i].owned {
            let fiyat = rackets[i].baseUpgradeCost
            guard cash >= fiyat else { return }
            cash -= fiyat
            rackets[i].owned = true
        } else {
            let fiyat = rackets[i].upgradeCost
            guard cash >= fiyat else { return }
            cash -= fiyat
            rackets[i].tier += 1
        }
        Haptics.tik()
        save()
    }

    // MARK: Devşirme (gacha)

    func devsir() -> Enforcer? {
        guard cash >= devsirmeCost else { return nil }
        cash -= devsirmeCost
        let yeni = Factory.makeEnforcer()
        crew.append(yeni)
        // Ekipte yer varsa otomatik sahaya al
        if squad.count < maxKadro { squad.append(yeni.id) }
        devsirmeCost = Int(Double(devsirmeCost) * 1.25)
        gorevIlerlet(.devsir)
        Haptics.basari()
        save()
        return yeni
    }

    // MARK: Günlük görevler

    /// Gün değiştiyse görevleri yenile.
    func gorevleriTazele() {
        if gorevler.isEmpty || !Calendar.current.isDate(gorevTarih, inSameDayAs: Date()) {
            gorevler = Factory.makeDailyMissions(bossLevel: bossLevel)
            gorevTarih = Date()
            save()
        }
    }

    /// Bir görev tipinde ilerleme kaydet.
    func gorevIlerlet(_ tip: GorevTip, _ miktar: Int = 1) {
        var degisti = false
        for i in gorevler.indices where gorevler[i].tip == tip && !gorevler[i].tamam {
            gorevler[i].ilerleme = min(gorevler[i].hedef, gorevler[i].ilerleme + miktar)
            degisti = true
        }
        if degisti { save() }
    }

    func gorevOdulAl(_ id: UUID) {
        guard let i = gorevler.firstIndex(where: { $0.id == id }),
              gorevler[i].tamam, !gorevler[i].alindi else { return }
        cash += gorevler[i].odul
        gorevler[i].alindi = true
        SoundManager.shared.cal(.coin)
        Haptics.basari()
        save()
    }

    var alinabilirGorevSayisi: Int { gorevler.filter { $0.tamam && !$0.alindi }.count }

    // MARK: Teçhizat

    /// Bir adama envanterden teçhizat tak (varsa eskisini envantere geri koy).
    func gearTak(_ gear: Gear, to enforcerID: UUID) {
        guard let ci = crew.firstIndex(where: { $0.id == enforcerID }),
              let gi = envanter.firstIndex(where: { $0.id == gear.id }) else { return }
        if let eski = crew[ci].equippedGear { envanter.append(eski) }
        crew[ci].equippedGear = gear
        envanter.remove(at: gi)
        Haptics.tik()
        save()
    }

    /// Takılı teçhizatı çıkar, envantere geri koy.
    func gearCikar(from enforcerID: UUID) {
        guard let ci = crew.firstIndex(where: { $0.id == enforcerID }),
              let g = crew[ci].equippedGear else { return }
        envanter.append(g)
        crew[ci].equippedGear = nil
        Haptics.tik()
        save()
    }

    /// Teçhizatı sat (nadirliğe göre nakit).
    func gearSat(_ gear: Gear) {
        guard let gi = envanter.firstIndex(where: { $0.id == gear.id }) else { return }
        cash += 500 + gear.guc * 20
        envanter.remove(at: gi)
        Haptics.tik()
        save()
    }

    /// Garantili efsane adam (IAP ödülü).
    @discardableResult
    func efsaneDevsir() -> Enforcer {
        let yeni = Factory.makeEnforcer(rarity: .efsane, level: max(1, bossLevel))
        crew.append(yeni)
        if squad.count < maxKadro { squad.append(yeni.id) }
        Haptics.basari()
        save()
        return yeni
    }

    // MARK: Ekip yönetimi

    func toggleSquad(_ id: UUID) {
        if let idx = squad.firstIndex(of: id) {
            squad.remove(at: idx)
        } else if squad.count < maxKadro {
            squad.append(id)
        }
        save()
    }

    func yukseltMaliyet(_ e: Enforcer) -> Int {
        Int(120.0 * Double(e.level) * e.rarity.powerMult)
    }

    func adamYukselt(_ id: UUID) {
        guard let i = crew.firstIndex(where: { $0.id == id }) else { return }
        let fiyat = yukseltMaliyet(crew[i])
        guard cash >= fiyat else { return }
        cash -= fiyat
        crew[i].level += 1
        Haptics.tik()
        save()
    }

    // MARK: Dövüş sonucu uygula

    func dovusKazanildi(node: RivalNode, hayatta: [UUID]) {
        cash += node.oduuncash
        respect += node.odulRespect
        // Sahada kalan adamlara XP
        for id in hayatta {
            if let i = crew.firstIndex(where: { $0.id == id }) {
                crew[i].xp += node.odulRespect
                while crew[i].xp >= crew[i].xpToNext {
                    crew[i].xp -= crew[i].xpToNext
                    crew[i].level += 1
                }
            }
        }
        if let i = rivals.firstIndex(where: { $0.id == node.id }) {
            rivals[i].cleared = true
        }
        gorevIlerlet(.dovus)
        // Ara sıra bedava adam düşür
        if Double.random(in: 0...1) < 0.30 {
            let dusen = Factory.makeEnforcer(level: max(1, bossLevel - 1))
            crew.append(dusen)
        }
        // Sık sık teçhizat düşür (ganimet)
        if Double.random(in: 0...1) < 0.55 {
            envanter.append(Factory.makeGear())
        }
        Haptics.basari()
        save()
    }

    // MARK: Kalıcılık

    /// Mevcut oyun durumunu SaveState olarak topla.
    private func mevcutDurum() -> SaveState {
        SaveState(
            cash: cash, respect: respect, crew: crew, squad: squad,
            rackets: rackets, rivals: rivals, lastSeen: Date(),
            devsirmeCost: devsirmeCost, vipAktif: vipAktif, vipSonBonus: vipSonBonus,
            gunlukBonusTarih: gunlukBonusTarih, gunlukSeri: gunlukSeri, envanter: envanter,
            gorevler: gorevler, gorevTarih: gorevTarih, binalar: binalar,
            ordu: ordu, egitim: egitim, seferler: seferler, cephane: cephane,
            raporlar: raporlar, bolgeler: bolgeler
        )
    }

    func save() {
        guard let data = try? JSONEncoder().encode(mevcutDurum()) else { return }
        try? data.write(to: saveURL, options: .atomic)
        // Otomatik iCloud yedeği (iCloud Key-Value Store)
        let kv = NSUbiquitousKeyValueStore.default
        kv.set(data, forKey: "rajon_save")
        kv.synchronize()
        // Telefon hesabı varsa sunucuya tam-durum yedeği (debounced)
        bulutaYedekDebounce()
    }

    /// Tüm durumu JSON string olarak (sunucu yedeği için).
    func durumBlobu() -> String {
        (try? JSONEncoder().encode(mevcutDurum())).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    /// Sunucudan/iCloud'dan gelen durumu uygula (geri yükleme).
    func durumYukle(_ blob: String) {
        guard let data = blob.data(using: .utf8),
              let s = try? JSONDecoder().decode(SaveState.self, from: data) else { return }
        uygula(s)
        try? data.write(to: saveURL, options: .atomic)
    }

    private func uygula(_ s: SaveState) {
        cash = s.cash; respect = s.respect; crew = s.crew; squad = s.squad
        rackets = s.rackets; rivals = s.rivals; lastSeen = s.lastSeen
        devsirmeCost = s.devsirmeCost
        vipAktif = s.vipAktif; vipSonBonus = s.vipSonBonus
        gunlukBonusTarih = s.gunlukBonusTarih; gunlukSeri = s.gunlukSeri
        envanter = s.envanter
        gorevler = s.gorevler; gorevTarih = s.gorevTarih
        binalar = s.binalar
        if binalar.isEmpty { binalar = BinaTip.allCases.map { Bina(tip: $0, seviye: $0.baslangic) } }
        ordu = s.ordu; egitim = s.egitim; seferler = s.seferler
        cephane = s.cephane; raporlar = s.raporlar
        bolgeler = s.bolgeler
        if bolgeler.isEmpty { bolgeler = Factory.makeBolgeler() }
    }

    @discardableResult
    private func load() -> Bool {
        // En yeni kaydı seç: yerel vs iCloud (lastSeen'e göre)
        let yerel = (try? Data(contentsOf: saveURL)).flatMap { try? JSONDecoder().decode(SaveState.self, from: $0) }
        let bulut = (NSUbiquitousKeyValueStore.default.data(forKey: "rajon_save")).flatMap { try? JSONDecoder().decode(SaveState.self, from: $0) }
        let secilen: SaveState?
        switch (yerel, bulut) {
        case let (y?, b?): secilen = b.lastSeen > y.lastSeen ? b : y
        case let (y?, nil): secilen = y
        case let (nil, b?): secilen = b
        default: secilen = nil
        }
        guard let s = secilen else { return false }
        uygula(s)
        return true
    }

    // Sunucuya tam-durum yedeği (telefon hesabı için). OnlineService set eder.
    var bulutaYedek: ((String) -> Void)?
    private var yedekTimer: Timer?
    private func bulutaYedekDebounce() {
        guard bulutaYedek != nil else { return }
        yedekTimer?.invalidate()
        yedekTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.bulutaYedek?(self.durumBlobu()) }
        }
    }

    func sifirla() {
        timer?.cancel()
        try? FileManager.default.removeItem(at: saveURL)
        idleKazanc = 0
        newGame()
        startTimer()
    }
}

/// Basit haptik yardımcıları.
enum Haptics {
    static func tik() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func basari() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    static func vurus() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
}
