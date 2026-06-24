import SwiftUI

// MARK: - Nadirlik (rarity)

enum Rarity: Int, Codable, CaseIterable, Comparable {
    case sokak = 0      // gri  — sıradan it
    case tetikci = 1    // yeşil — işini bilen
    case kabadayi = 2   // mavi  — sağlam adam
    case patron = 3     // mor   — ağır abi
    case efsane = 4     // altın — efsane

    static func < (l: Rarity, r: Rarity) -> Bool { l.rawValue < r.rawValue }

    var label: String {
        switch self {
        case .sokak:    return "Sokak İti"
        case .tetikci:  return "Tetikçi"
        case .kabadayi: return "Kabadayı"
        case .patron:   return "Patron"
        case .efsane:   return "Efsane"
        }
    }

    var color: Color {
        switch self {
        case .sokak:    return Theme.smoke
        case .tetikci:  return Color(red: 0.40, green: 0.78, blue: 0.42)
        case .kabadayi: return Color(red: 0.35, green: 0.60, blue: 0.95)
        case .patron:   return Color(red: 0.70, green: 0.45, blue: 0.95)
        case .efsane:   return Theme.gold
        }
    }

    /// Bu nadirlikteki adamın temel güç çarpanı.
    var powerMult: Double {
        switch self {
        case .sokak:    return 1.0
        case .tetikci:  return 1.35
        case .kabadayi: return 1.8
        case .patron:   return 2.4
        case .efsane:   return 3.2
        }
    }

    /// Devşirmede çıkma ağırlığı (yüksek = sık).
    var dropWeight: Double {
        switch self {
        case .sokak:    return 56
        case .tetikci:  return 27
        case .kabadayi: return 12
        case .patron:   return 4
        case .efsane:   return 1
        }
    }
}

// MARK: - Sınıf (rol)

enum Klas: String, Codable, CaseIterable {
    case yumruk     // tank / kabadayı
    case tetik      // hasar / nişancı
    case bicak      // hızlı / suikast
    case beyin      // destek / taktik

    var label: String {
        switch self {
        case .yumruk: return "Kabadayı"
        case .tetik:  return "Nişancı"
        case .bicak:  return "Bıçakçı"
        case .beyin:  return "Beyin"
        }
    }

    var icon: String {
        switch self {
        case .yumruk: return "figure.boxing"
        case .tetik:  return "scope"
        case .bicak:  return "bolt.fill"
        case .beyin:  return "brain.head.profile"
        }
    }

    /// rol → (can, saldırı, hız) ağırlığı
    var bias: (hp: Double, atk: Double, spd: Double) {
        switch self {
        case .yumruk: return (1.5, 0.85, 0.7)
        case .tetik:  return (0.85, 1.5, 0.9)
        case .bicak:  return (0.8, 1.1, 1.6)
        case .beyin:  return (1.0, 0.95, 1.0)
        }
    }
}

// MARK: - Adam (enforcer)

struct Enforcer: Identifiable, Codable, Equatable {
    var id = UUID()
    var ad: String            // lakap
    var rarity: Rarity
    var klas: Klas
    var level: Int = 1
    var xp: Int = 0
    var taunt: String         // dövüşte basacağı laf
    var equippedGear: Gear? = nil   // takılı teçhizat (opsiyonel → eski kayıt uyumlu)

    // Türetilmiş istatistikler (teçhizat bonusu dahil)
    var maxHP: Int {
        let base = 80.0 * rarity.powerMult * klas.bias.hp
        return Int(base * (1.0 + Double(level - 1) * 0.12)) + (equippedGear?.hpBonus ?? 0)
    }
    var atk: Int {
        let base = 18.0 * rarity.powerMult * klas.bias.atk
        return Int(base * (1.0 + Double(level - 1) * 0.12)) + (equippedGear?.atkBonus ?? 0)
    }
    var spd: Int {
        Int(10.0 * klas.bias.spd * (1.0 + Double(rarity.rawValue) * 0.08))
    }
    /// Listelerde gösterilen tek skor.
    var guc: Int { maxHP / 4 + atk * 3 + spd }

    var xpToNext: Int { 60 + (level - 1) * 45 }

    static func == (l: Enforcer, r: Enforcer) -> Bool { l.id == r.id }
}

// MARK: - Teçhizat / silah (gear)

struct Gear: Identifiable, Codable, Equatable {
    var id = UUID()
    var ad: String
    var rarity: Rarity
    var atkBonus: Int
    var hpBonus: Int
    var ikon: String

    var guc: Int { atkBonus * 3 + hpBonus / 4 }
}

// MARK: - Haraç / işletme (racket)

struct Racket: Identifiable, Codable {
    var id = UUID()
    var ad: String
    var tier: Int = 1                 // seviye
    var basePerMin: Int               // sn başına değil, dk başına temel üretim
    var baseUpgradeCost: Int
    var owned: Bool = false

    var perMin: Int { Int(Double(basePerMin) * pow(1.6, Double(tier - 1))) }
    var upgradeCost: Int { Int(Double(baseUpgradeCost) * pow(1.9, Double(tier - 1))) }
    var perSec: Double { Double(perMin) / 60.0 }
}

// MARK: - Rakip çete (kademe / görev)

struct RivalNode: Identifiable, Codable {
    var id = UUID()
    var ad: String
    var aciklama: String
    var power: Int                    // tavsiye edilen ekip gücü
    var crew: [Enforcer]              // düşman ekibi
    var oduuncash: Int
    var odulRespect: Int
    var cleared: Bool = false
}
