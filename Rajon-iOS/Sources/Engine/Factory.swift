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
                odulRespect: 20 + zorluk * 25
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

    static func makeRackets() -> [Racket] {
        Argo.racketIsimleri.enumerated().map { idx, info in
            let (ad, perMin, cost) = info
            // İlki bedava başlasın (sahip)
            return Racket(ad: ad, basePerMin: perMin, baseUpgradeCost: cost, owned: idx == 0)
        }
    }
}
