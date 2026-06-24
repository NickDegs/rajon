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
    /// Flux ile üretilen sınıf portresi (asset kataloğu adı).
    var gorsel: String { "klas_\(rawValue)" }

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

// MARK: - Bölge (çoklu mahalle / şehir ele geçirme)

struct Bolge: Identifiable, Codable {
    var id = UUID()
    var ad: String
    var gorsel: String              // Flux semt görseli
    var gelirDk: Int                // ele geçirilince dk başına gelir
    var maliyet: Int                // ele geçirme maliyeti
    var sure: Double                // ele geçirme süresi (sn)
    var eleGecirildi: Bool = false
    var fetihBitis: Date? = nil     // fetih bitiş zamanı

    var fetihte: Bool { (fetihBitis ?? .distantPast) > Date() }
}

// MARK: - Rapor (akın/baskın/savunma sonuçları)

struct Rapor: Identifiable, Codable {
    var id = UUID()
    var baslik: String
    var detay: String
    var kazandi: Bool
    var tarih: Date = Date()
}

// MARK: - Asker (kitle birlik) ve sefer/akın

enum AskerTip: String, Codable, CaseIterable {
    case tetikci    // saldırı
    case kabadayi   // savunma
    case sofor      // yağma kapasitesi + hız

    var ad: String {
        switch self {
        case .tetikci:  return "Tetikçi"
        case .kabadayi: return "Kabadayı"
        case .sofor:    return "Şoför"
        }
    }
    var aciklama: String {
        switch self {
        case .tetikci:  return "Yüksek saldırı"
        case .kabadayi: return "Sağlam savunma"
        case .sofor:    return "Bol yağma taşır, sefer hızlı"
        }
    }
    var gorsel: String { "asker_\(rawValue)" }

    var saldiri: Int  { self == .tetikci ? 14 : (self == .kabadayi ? 5 : 6) }
    var savunma: Int  { self == .kabadayi ? 16 : (self == .tetikci ? 5 : 6) }
    var yagma: Int    { self == .sofor ? 220 : 40 }      // taşıma kapasitesi
    var maliyet: Int  { self == .sofor ? 900 : (self == .kabadayi ? 700 : 600) }
    var cephaneMaliyet: Int { self == .tetikci ? 8 : (self == .kabadayi ? 3 : 2) } // birim başına
    var egitimSure: Double { 8 }                          // birim başına sn
}

/// Devam eden akın/sefer.
struct Sefer: Identifiable, Codable {
    var id = UUID()
    var hedefAd: String
    var hedefGuc: Int                 // hedef savunma gücü
    var gonderilen: [String: Int]     // AskerTip.rawValue -> sayı
    var donus: Date                   // birliklerin döneceği an
    var oduuncash: Int                // başarı yağması

    var dondu: Bool { donus <= Date() }
}

/// Asker eğitim kuyruğu öğesi.
struct EgitimIs: Codable {
    var tip: AskerTip
    var sayi: Int
    var bitis: Date
}

// MARK: - Mahalle binaları (Travian tarzı zamanlı inşaat)

enum BinaTip: String, Codable, CaseIterable {
    case karargah    // inşaat hızı
    case kasa        // nakit/dk
    case depo        // birikim kapasitesi (saat)
    case cephanelik  // ekip saldırı %
    case kisla       // kadro slotu
    case korunak     // savunma

    var ad: String {
        switch self {
        case .karargah:   return "Karargah"
        case .kasa:       return "Kasa Dairesi"
        case .depo:       return "Depo"
        case .cephanelik: return "Cephanelik"
        case .kisla:      return "Kışla"
        case .korunak:    return "Korunak"
        }
    }
    var aciklama: String {
        switch self {
        case .karargah:   return "İnşaatları hızlandırır"
        case .kasa:       return "Dakikalık nakit üretir"
        case .depo:       return "Kasada birikim sınırını artırır"
        case .cephanelik: return "Ekibin saldırı gücünü artırır"
        case .kisla:      return "Sahaya daha çok adam çıkarırsın"
        case .korunak:    return "Baskınlarda savunmanı artırır"
        }
    }
    /// SF Symbol (Flux görseli yoksa yedek).
    var sembol: String {
        switch self {
        case .karargah:   return "building.columns.fill"
        case .kasa:       return "banknote.fill"
        case .depo:       return "shippingbox.fill"
        case .cephanelik: return "scope"
        case .kisla:      return "person.3.fill"
        case .korunak:    return "shield.lefthalf.filled"
        }
    }
    /// Asset kataloğundaki Flux görsel adı.
    var gorsel: String { "bina_\(rawValue)" }

    /// Başlangıç seviyesi (karargah ve kasa hazır gelir).
    var baslangic: Int { (self == .karargah || self == .kasa) ? 1 : 0 }
}

struct Bina: Identifiable, Codable {
    var id = UUID()
    var tip: BinaTip
    var seviye: Int
    var insaatBitis: Date? = nil   // inşaat bitiş zamanı (nil = boşta)

    var insaatta: Bool {
        guard let b = insaatBitis else { return false }
        return b > Date()
    }
    /// Bir sonraki seviye için maliyet.
    var yukseltmeMaliyet: Int { Int(220.0 * pow(1.7, Double(seviye))) }
    /// Temel inşaat süresi (sn) — karargah ayrıca hızlandırır.
    var temelSure: Double { 30.0 * pow(1.45, Double(seviye)) }
}

// MARK: - Günlük görev

enum GorevTip: String, Codable, CaseIterable {
    case baskin      // online PvP baskını kazan
    case dovus       // kampanya dövüşü kazan
    case devsir      // adam devşir
    case harac       // haraç topla (kez)

    var label: String {
        switch self {
        case .baskin: return "Baskın kazan"
        case .dovus:  return "Çeteyi dağıt"
        case .devsir: return "Adam devşir"
        case .harac:  return "Haraç topla"
        }
    }
    var ikon: String {
        switch self {
        case .baskin: return "scope"
        case .dovus:  return "person.2.slash.fill"
        case .devsir: return "dice.fill"
        case .harac:  return "dollarsign.circle.fill"
        }
    }
}

struct Gorev: Identifiable, Codable {
    var id = UUID()
    var tip: GorevTip
    var hedef: Int
    var ilerleme: Int = 0
    var odul: Int
    var alindi: Bool = false

    var tamam: Bool { ilerleme >= hedef }
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
    var gorsel: String? = nil         // Flux çete amblemi (cete_N)
}
