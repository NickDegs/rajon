import Foundation

/// Adam ve rakip çete üretimi.
enum Factory {

    static func makeEnforcer(rarity: Rarity? = nil, klas: Klas? = nil, level: Int = 1) -> Enforcer {
        let r = rarity ?? rollRarity()
        let k = klas ?? Klas.allCases.randomElement()!
        return Enforcer(
            ad: Argo.rastlakap(),
            rarity: r,
            klas: k,
            level: level,
            taunt: Argo.taunt(for: r)
        )
    }

    /// Ağırlıklı nadirlik çekilişi (gacha).
    static func rollRarity() -> Rarity {
        let total = Rarity.allCases.reduce(0.0) { $0 + $1.dropWeight }
        var roll = Double.random(in: 0..<total)
        for r in Rarity.allCases.sorted(by: { $0.dropWeight > $1.dropWeight }) {
            if roll < r.dropWeight { return r }
            roll -= r.dropWeight
        }
        return .sokak
    }

    /// Sokak haritası için kademeli rakip düğümleri üretir.
    static func makeRivalLadder() -> [RivalNode] {
        Argo.ceteler.enumerated().map { idx, info in
            let (ad, aciklama) = info
            let zorluk = idx
            // Düşman ekibi: kademeye göre seviye/nadirlik artar
            let mevcut = 2 + min(zorluk, 2)            // 2..4 kişi
            let lvl = 1 + zorluk * 2
            let rar: Rarity = {
                switch zorluk {
                case 0, 1: return .sokak
                case 2, 3: return .tetikci
                case 4, 5: return .kabadayi
                case 6:    return .patron
                default:   return .efsane
                }
            }()
            let crew = (0..<mevcut).map { i -> Enforcer in
                // Boss son kademede daha güçlü
                let r: Rarity = (i == 0 && zorluk >= 4) ? (rar > .sokak ? rar : .tetikci) : rar
                return makeEnforcer(rarity: r, level: lvl)
            }
            let teamGuc = crew.reduce(0) { $0 + $1.guc }
            return RivalNode(
                ad: ad,
                aciklama: aciklama,
                power: teamGuc,
                crew: crew,
                oduuncash: 400 + zorluk * zorluk * 650,
                odulRespect: 20 + zorluk * 25,
                gorsel: "cete_\(idx)"
            )
        }
    }

    /// Rasgele teçhizat üret (nadirlik verilmezse ağırlıklı çekiliş).
    static func makeGear(rarity: Rarity? = nil) -> Gear {
        let r = rarity ?? rollRarity()
        let (ad, ikon) = Argo.rastSilah()
        let taban = 6.0 * r.powerMult
        return Gear(
            ad: ad,
            rarity: r,
            atkBonus: Int(taban * Double.random(in: 0.8...1.3)),
            hpBonus: Int(taban * 6 * Double.random(in: 0.7...1.2)),
            ikon: ikon
        )
    }

    /// Günlük 3 görev üret (patron seviyesine göre ölçekli ödül).
    static func makeDailyMissions(bossLevel: Int) -> [Gorev] {
        let odulTaban = 4_000 + bossLevel * 1_500
        let tanim: [(GorevTip, Int)] = [
            (.dovus, 3),
            (.devsir, 2),
            (.baskin, 2),
            (.harac, 4),
        ]
        return tanim.shuffled().prefix(3).map { tip, hedef in
            Gorev(tip: tip, hedef: hedef, odul: odulTaban + Int.random(in: 0...2000))
        }
    }

    /// Şehir bölgeleri (Flux semt görselleriyle). İlki bedava başlar (ele geçirilmiş).
    static func makeBolgeler() -> [Bolge] {
        // (ad, görsel, gelir, harita x, harita y)
        let tanim: [(String, String, Int, Int, Int)] = [
            ("Çarşı", "bolge_carsi", 120, 1, 1),
            ("Liman", "bolge_liman", 280, 3, 0),
            ("Yokuş", "bolge_yokus", 520, 0, 3),
            ("Meydan", "bolge_meydan", 900, 2, 3),
            ("Sanayi", "bolge_sanayi", 1_500, 4, 2),
            ("Kordon", "bolge_kordon", 2_400, 4, 4),
        ]
        return tanim.enumerated().map { idx, t in
            let (ad, gorsel, gelir, hx, hy) = t
            return Bolge(
                ad: ad, gorsel: gorsel, gelirDk: gelir,
                maliyet: Int(2_500.0 * pow(2.4, Double(idx))),
                sure: 60.0 * pow(1.8, Double(idx)),
                eleGecirildi: idx == 0, fetihBitis: nil, hx: hx, hy: hy
            )
        }
    }

    /// Vahalar (kaçak noktaları) — haritada ele geçip üretim artırır.
    static func makeVahalar() -> [Vaha] {
        // (ad, görsel, tip, bonus/dk, x, y)
        let tanim: [(String, String, VahaTip, Int, Int, Int)] = [
            ("Mazot Kuyusu", "vaha_mazot", .nakit, 200, 2, 1),
            ("Cephane Deposu", "vaha_cephane", .cephane, 18, 0, 1),
            ("Kumar Çadırı", "vaha_kumar", .nakit, 380, 3, 2),
            ("Tefeci Köşesi", "vaha_tefeci", .nakit, 600, 1, 4),
            ("Kaçak İskele", "vaha_iskele", .nakit, 950, 4, 0),
            ("Silah Atölyesi", "vaha_atolye", .cephane, 40, 3, 4),
        ]
        return tanim.enumerated().map { idx, t in
            let (ad, gorsel, tip, bonus, hx, hy) = t
            return Vaha(
                ad: ad, gorsel: gorsel, tip: tip, bonusDk: bonus,
                maliyet: Int(4_000.0 * pow(2.2, Double(idx))),
                sure: 90.0 * pow(1.7, Double(idx)),
                hx: hx, hy: hy
            )
        }
    }

    static func makeRackets() -> [Racket] {
        Argo.racketIsimleri.enumerated().map { idx, info in
            let (ad, perMin, cost) = info
            // İlki bedava başlasın (sahip)
            return Racket(ad: ad, basePerMin: perMin, baseUpgradeCost: cost, owned: idx == 0)
        }
    }
}
