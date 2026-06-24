import SwiftUI

/// Kozmetik seçimleri — avatar, isim rengi, unvan. HİÇBİRİ oyunu güçlendirmez (sadece görünüm).
/// Çoğu ücretsiz; premium olanlar Destekçi paketiyle açılır.
@MainActor
final class CosmeticStore: ObservableObject {
    @Published var avatar: String { didSet { kaydet("kozmetik_avatar", avatar) } }
    @Published var renk: String   { didSet { kaydet("kozmetik_renk", renk) } }
    @Published var unvan: String  { didSet { kaydet("kozmetik_unvan", unvan) } }

    init() {
        let d = UserDefaults.standard
        avatar = d.string(forKey: "kozmetik_avatar") ?? "avatar_kopek"
        renk = d.string(forKey: "kozmetik_renk") ?? "beyaz"
        unvan = d.string(forKey: "kozmetik_unvan") ?? ""
    }
    private func kaydet(_ k: String, _ v: String) { UserDefaults.standard.set(v, forKey: k) }

    // MARK: Katalog

    /// Tüm avatarlar (Flux). Premium olanlar Destekçi ile açılır.
    static let avatarlar: [String] = [
        "avatar_kopek", "avatar_kedi", "avatar_kurt", "avatar_boga", "avatar_kobra",
        "avatar_ayi", "avatar_sahin", "avatar_gul", "avatar_zar", "avatar_puro",
        // premium ↓
        "avatar_aslan", "avatar_kartal", "avatar_panter", "avatar_kafatasi",
        "avatar_elmas", "avatar_tabanca",
    ]
    static let premiumAvatarlar: Set<String> = [
        "avatar_aslan", "avatar_kartal", "avatar_panter",
        "avatar_kafatasi", "avatar_elmas", "avatar_tabanca",
    ]

    /// İsim renkleri (id, renk, premium?).
    static let renkler: [(id: String, renk: Color, premium: Bool)] = [
        ("beyaz",  .white, false),
        ("kirmizi", Theme.blood, false),
        ("yesil",  Color(red: 0.40, green: 0.80, blue: 0.45), false),
        ("cyan",   .cyan, false),
        ("mor",    Color(red: 0.70, green: 0.45, blue: 0.95), false),
        ("turuncu", .orange, false),
        ("pembe",  Color(red: 0.96, green: 0.45, blue: 0.70), false),
        ("altin",  Theme.gold, true),       // premium
    ]
    static func renkAl(_ id: String) -> Color { renkler.first { $0.id == id }?.renk ?? .white }
    static func renkPremium(_ id: String) -> Bool { renkler.first { $0.id == id }?.premium ?? false }

    /// Unvanlar (etiket). Son üçü premium.
    static let unvanlar: [String] = [
        "", "Çaylak", "Tetikçi", "Kabadayı", "Reis", "Patron",
        "Baron", "Don", "Kral",   // premium
    ]
    static let premiumUnvanlar: Set<String> = ["Baron", "Don", "Kral"]

    func avatarPremiumMi(_ a: String) -> Bool { Self.premiumAvatarlar.contains(a) }
    func unvanPremiumMi(_ u: String) -> Bool { Self.premiumUnvanlar.contains(u) }

    var seciliRenk: Color { Self.renkAl(renk) }
}
