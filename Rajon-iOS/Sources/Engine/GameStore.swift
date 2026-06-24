import SwiftUI
import Combine

/// Diske kaydedilen oyun durumu.
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

    @Published var idleKazanc: Int = 0      // toplanmayı bekleyen nakit
    private var lastSeen = Date()
    private var vipSonBonus = Date.distantPast
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
        Haptics.tik()
        save()
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
        Haptics.basari()
        save()
        return yeni
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
        // Ara sıra bedava adam düşür
        if Double.random(in: 0...1) < 0.30 {
            let dusen = Factory.makeEnforcer(level: max(1, bossLevel - 1))
            crew.append(dusen)
        }
        Haptics.basari()
        save()
    }

    // MARK: Kalıcılık

    func save() {
        let state = SaveState(
            cash: cash, respect: respect, crew: crew, squad: squad,
            rackets: rackets, rivals: rivals, lastSeen: Date(),
            devsirmeCost: devsirmeCost, vipAktif: vipAktif, vipSonBonus: vipSonBonus
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
