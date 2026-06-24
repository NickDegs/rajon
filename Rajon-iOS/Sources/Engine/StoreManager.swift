import StoreKit

/// IAP ürünleri — YALNIZCA KOZMETİK. Hiçbiri oyunu güçlendirmez (pay-to-win YOK).
/// Online profilde görünen rozet/çerçeve + geliştiriciye destek. Bundle: app.realvirtuality.blockings
enum RajonUrun: String, CaseIterable {
    case vip           = "app.realvirtuality.blockings.vipmonthly"    // Aylık VIP (tüm kozmetikler)
    case destekci      = "app.realvirtuality.blockings.supporter"     // Destekçi rozeti
    case rozetKafatasi = "app.realvirtuality.blockings.badge.skull"   // Kafatası rozeti
    case cerceveAltin  = "app.realvirtuality.blockings.frame.gold"    // Altın çerçeve

    var abonelik: Bool { self == .vip }

    var baslik: String {
        switch self {
        case .vip:           return "Kan Parası VIP"
        case .destekci:      return "Destekçi Paketi"
        case .rozetKafatasi: return "Kafatası Rozeti"
        case .cerceveAltin:  return "Altın Çerçeve"
        }
    }
    var altyazi: String {
        switch self {
        case .vip:           return "Aylık · TÜM kozmetikler + VIP'e özel hayvan, altın isim, taç"
        case .destekci:      return "Profilinde 🎩 Destekçi rozeti — oyunu desteklemiş ol"
        case .rozetKafatasi: return "Adının yanında kafatası rozeti"
        case .cerceveAltin:  return "Online profilinde altın çerçeve"
        }
    }
    var ikon: String {
        switch self {
        case .vip:           return "crown.fill"
        case .destekci:      return "hands.clap.fill"
        case .rozetKafatasi: return "flag.checkered"
        case .cerceveAltin:  return "seal.fill"
        }
    }
    /// Profil yanında gösterilecek kozmetik simge (sahip olunca).
    var rozetSembol: String? {
        switch self {
        case .vip:           return "👑"
        case .destekci:      return "🎩"
        case .rozetKafatasi: return "💀"
        case .cerceveAltin:  return "⭐️"
        }
    }
}

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var unlocked: Set<String> = []   // sahip olunan kozmetikler
    @Published var sonHata: String?
    @Published var yukleniyor = false

    private var updates: Task<Void, Never>?
    private let kayitAnahtar = "rajon_kozmetikler"

    init() {
        unlocked = Set(UserDefaults.standard.stringArray(forKey: kayitAnahtar) ?? [])
        updates = dinle()
    }
    deinit { updates?.cancel() }

    func basla(game: GameStore) {
        Task {
            await urunleriYukle()
            // Tamamlanmamış işlemler (iPad cache gecikmesi için direkt set)
            for await sonuc in Transaction.unfinished {
                if case .verified(let t) = sonuc { ode(t); await t.finish() }
            }
            await kozmetikGuncelle()
        }
    }

    /// VIP aktif (aylık abonelik). Tüm kozmetikleri açar; bittiğinde kapanır.
    @Published var vipAktif = false

    /// Bir kozmetiğe sahip miyiz? VIP aktifse tüm kozmetikler açık.
    func sahip(_ u: RajonUrun) -> Bool {
        if u == .vip { return vipAktif }
        return unlocked.contains(u.rawValue) || vipAktif
    }
    var destekciMi: Bool { unlocked.contains(RajonUrun.destekci.rawValue) }
    /// Premium kozmetik kilidi açık mı (VIP veya Destekçi).
    var premiumAcik: Bool { vipAktif || destekciMi }
    /// Profilde gösterilecek en üst kozmetik rozet.
    var aktifRozet: String? {
        if vipAktif { return RajonUrun.vip.rozetSembol }   // 👑
        for u in [RajonUrun.cerceveAltin, .rozetKafatasi, .destekci] where sahip(u) {
            return u.rozetSembol
        }
        return nil
    }

    func urunleriYukle() async {
        do {
            let p = try await Product.products(for: RajonUrun.allCases.map { $0.rawValue })
            products = p.sorted { $0.price < $1.price }
        } catch { sonHata = "Ürünler yüklenemedi: \(error.localizedDescription)" }
    }
    func urun(_ u: RajonUrun) -> Product? { products.first { $0.id == u.rawValue } }

    func satinAl(_ product: Product) async {
        yukleniyor = true; defer { yukleniyor = false }
        do {
            switch try await product.purchase() {
            case .success(let dogrulama):
                if case .verified(let t) = dogrulama { ode(t); await t.finish() }
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch { sonHata = "Satın alma başarısız: \(error.localizedDescription)" }
    }

    /// Kozmetiği aç (cache'i bekleme — iPad race fix). Hiçbir oyun etkisi YOK.
    private func ode(_ t: Transaction) {
        guard t.revocationDate == nil, let u = RajonUrun(rawValue: t.productID) else { return }
        if u == .vip {
            vipAktif = true   // abonelik — kalıcı sete eklenmez
        } else {
            unlocked.insert(t.productID)
            UserDefaults.standard.set(Array(unlocked), forKey: kayitAnahtar)
        }
        Haptics.basari()
    }

    func geriYukle() async {
        yukleniyor = true; defer { yukleniyor = false }
        try? await AppStore.sync()
        await kozmetikGuncelle()
    }

    func kozmetikGuncelle() async {
        var sahipOlunan = Set<String>()
        var vip = false
        for await sonuc in Transaction.currentEntitlements {
            if case .verified(let t) = sonuc, t.revocationDate == nil {
                if t.productID == RajonUrun.vip.rawValue { vip = true }
                else { sahipOlunan.insert(t.productID) }
            }
        }
        vipAktif = vip                    // abonelik canlı durumu (bitince kapanır)
        unlocked.formUnion(sahipOlunan)   // kalıcı kozmetikler sadece eklenir
        UserDefaults.standard.set(Array(unlocked), forKey: kayitAnahtar)
    }

    private func dinle() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await sonuc in Transaction.updates {
                guard let self else { continue }
                if case .verified(let t) = sonuc { await self.ode(t); await t.finish() }
            }
        }
    }
}
