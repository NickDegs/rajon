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

    init(cash: Int, respect: Int, crew: [Enforcer], squad: [UUID], rackets: [Racket],
         rivals: [RivalNode], lastSeen: Date, devsirmeCost: Int, vipAktif: Bool,
         vipSonBonus: Date, gunlukBonusTarih: Date, gunlukSeri: Int, envanter: [Gear],
         gorevler: [Gorev], gorevTarih: Date) {
        self.cash = cash; self.respect = respect; self.crew = crew; self.squad = squad
        self.rackets = rackets; self.rivals = rivals; self.lastSeen = lastSeen
        self.devsirmeCost = devsirmeCost; self.vipAktif = vipAktif; self.vipSonBonus = vipSonBonus
        self.gunlukBonusTarih = gunlukBonusTarih; self.gunlukSeri = gunlukSeri; self.envanter = envanter
        self.gorevler = gorevler; self.gorevTarih = gorevTarih
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
    }
}

/// Bütün oyun mantığını yöneten gözlemlenebilir depo.
@MainActor
final class GameStore: ObservableObject {
    @Published var cash: Int = 0
    @Published var respect: Int = 0
    @Published var crew: [Enforcer] = []
    @Published var squad: [UUID] = []
    @Published var rackets: [Racket] = []
    @Published var rivals: [RivalNode] = []
    @Published var devsirmeCost: Int = 500
    @Published var vipAktif: Bool = false   // Kan Parası VIP — 2x gelir + günlük bonus

    @Published var envanter: [Gear] = []    // takılı olmayan teçhizat
    @Published var gorevler: [Gorev] = []   // günlük görevler
    private var gorevTarih = Date.distantPast
    @Published var idleKazanc: Int = 0      // toplanmayı bekleyen nakit
    @Published var gunlukSeri: Int = 0      // ardışık giriş günü serisi
    private var lastSeen = Date()
    private var vipSonBonus = Date.distantPast
    private var gunlukBonusTarih = Date.distantPast
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

    /// VIP aktifse gelir 2 katı.
    var gelirCarpani: Double { vipAktif ? 2.0 : 1.0 }

    private func tick() {
        let kazanc = ownedRackets.reduce(0.0) { $0 + $1.perSec } * gelirCarpani
        idleKazanc += Int(kazanc.rounded())
        // VIP günlük bonus
        if vipAktif, Date().timeIntervalSince(vipSonBonus) >= 86_400 {
            vipSonBonus = Date()
            cash += 50_000
        }
        // periyodik kayıt (her ~15 sn)
        if Int(Date().timeIntervalSince1970) % 15 == 0 { save() }
    }

    /// Uygulama kapalıyken biriken idle kazancı hesapla.
    private func accrueIdle() {
        let dt = Date().timeIntervalSince(lastSeen)
        guard dt > 0 else { return }
        let capped = min(dt, 8 * 3600)  // en fazla 8 saat birikir
        let perSec = ownedRackets.reduce(0.0) { $0 + $1.perSec } * gelirCarpani
        idleKazanc += Int(perSec * capped)
    }

    // MARK: Ekonomi

    var ownedRackets: [Racket] { rackets.filter { $0.owned } }
    var gelirPerMin: Int { Int(Double(ownedRackets.reduce(0) { $0 + $1.perMin }) * gelirCarpani) }

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
        if squad.count < 4 { squad.append(yeni.id) }
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
        if squad.count < 4 { squad.append(yeni.id) }
        Haptics.basari()
        save()
        return yeni
    }

    // MARK: Ekip yönetimi

    func toggleSquad(_ id: UUID) {
        if let idx = squad.firstIndex(of: id) {
            squad.remove(at: idx)
        } else if squad.count < 4 {
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

    func save() {
        let state = SaveState(
            cash: cash, respect: respect, crew: crew, squad: squad,
            rackets: rackets, rivals: rivals, lastSeen: Date(),
            devsirmeCost: devsirmeCost, vipAktif: vipAktif, vipSonBonus: vipSonBonus,
            gunlukBonusTarih: gunlukBonusTarih, gunlukSeri: gunlukSeri, envanter: envanter,
            gorevler: gorevler, gorevTarih: gorevTarih
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    @discardableResult
    private func load() -> Bool {
        guard let data = try? Data(contentsOf: saveURL),
              let s = try? JSONDecoder().decode(SaveState.self, from: data)
        else { return false }
        cash = s.cash; respect = s.respect; crew = s.crew; squad = s.squad
        rackets = s.rackets; rivals = s.rivals; lastSeen = s.lastSeen
        devsirmeCost = s.devsirmeCost
        vipAktif = s.vipAktif; vipSonBonus = s.vipSonBonus
        gunlukBonusTarih = s.gunlukBonusTarih; gunlukSeri = s.gunlukSeri
        envanter = s.envanter
        gorevler = s.gorevler; gorevTarih = s.gorevTarih
        return true
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
