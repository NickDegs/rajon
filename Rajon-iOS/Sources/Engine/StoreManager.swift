import StoreKit

/// IAP ürün kimlikleri — App Store Connect'te aynı ID ile oluşturulmalı.
/// Bundle: app.realvirtuality.blockings
enum RajonUrun: String, CaseIterable {
    // Tüketilebilir nakit paketleri (consumable)
    case nakitKucuk   = "app.realvirtuality.blockings.cash.small"
    case nakitOrta    = "app.realvirtuality.blockings.cash.medium"
    case nakitBuyuk   = "app.realvirtuality.blockings.cash.large"
    case nakitVurgun  = "app.realvirtuality.blockings.cash.huge"
    // Garantili efsane devşirme (consumable)
    case efsaneAdam   = "app.realvirtuality.blockings.recruit.legendary"
    // VIP — aylık abonelik (auto-renewable): 2x gelir + günlük bonus
    case vip          = "app.realvirtuality.blockings.vip.monthly"

    /// Satın alma karşılığı verilecek nakit (consumable'lar için).
    var nakitOdul: Int {
        switch self {
        case .nakitKucuk:  return 25_000
        case .nakitOrta:   return 90_000
        case .nakitBuyuk:  return 300_000
        case .nakitVurgun: return 1_200_000
        default:           return 0
        }
    }

    var baslik: String {
        switch self {
        case .nakitKucuk:  return "Köşe Kapması"
        case .nakitOrta:   return "Vurgun"
        case .nakitBuyuk:  return "Soygun"
        case .nakitVurgun: return "Büyük Hortum"
        case .efsaneAdam:  return "Garantili Efsane"
        case .vip:         return "Kan Parası VIP"
        }
    }

    var altyazi: String {
        switch self {
        case .nakitKucuk:  return "₺25K cebe insin"
        case .nakitOrta:   return "₺90K — işler büyüsün"
        case .nakitBuyuk:  return "₺300K — mahalle senin"
        case .nakitVurgun: return "₺1.2M — şehri al"
        case .efsaneAdam:  return "Kesin efsane bir adam çek"
        case .vip:         return "2x gelir + her gün nakit · aylık"
        }
    }

    var ikon: String {
        switch self {
        case .efsaneAdam: return "crown.fill"
        case .vip:        return "star.circle.fill"
        default:          return "dollarsign.circle.fill"
        }
    }
}

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var vipAktif = false
    @Published var sonHata: String?
    @Published var yukleniyor = false

    private var updates: Task<Void, Never>?
    weak var game: GameStore?

    init() {
        updates = dinle()
    }

    deinit { updates?.cancel() }

    func basla(game: GameStore) {
        self.game = game
        Task { await urunleriYukle(); await vipDurumGuncelle() }
    }

    func urunleriYukle() async {
        do {
            let ids = RajonUrun.allCases.map { $0.rawValue }
            let p = try await Product.products(for: ids)
            products = p.sorted { ($0.price) < ($1.price) }
        } catch {
            sonHata = "Ürünler yüklenemedi: \(error.localizedDescription)"
        }
    }

    func urun(_ u: RajonUrun) -> Product? {
        products.first { $0.id == u.rawValue }
    }

    func satinAl(_ product: Product) async {
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            let sonuc = try await product.purchase()
            switch sonuc {
            case .success(let dogrulama):
                if case .verified(let transaction) = dogrulama {
                    await odulVer(transaction)
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            sonHata = "Satın alma başarısız: \(error.localizedDescription)"
        }
    }

    /// Satın alımı oyuna yansıt.
    private func odulVer(_ t: Transaction) async {
        guard let u = RajonUrun(rawValue: t.productID) else { return }
        switch u {
        case .nakitKucuk, .nakitOrta, .nakitBuyuk, .nakitVurgun:
            game?.cash += u.nakitOdul
            game?.save()
        case .efsaneAdam:
            game?.efsaneDevsir()
        case .vip:
            vipAktif = true
            game?.vipAktif = true
            game?.save()
        }
        Haptics.basari()
    }

    /// Geri yükleme (Restore Purchases).
    func geriYukle() async {
        yukleniyor = true
        defer { yukleniyor = false }
        try? await AppStore.sync()
        await vipDurumGuncelle()
    }

    /// Aktif abonelik / kalıcı haklar.
    func vipDurumGuncelle() async {
        var aktif = false
        for await sonuc in Transaction.currentEntitlements {
            if case .verified(let t) = sonuc, t.productID == RajonUrun.vip.rawValue {
                if t.revocationDate == nil { aktif = true }
            }
        }
        vipAktif = aktif
        game?.vipAktif = aktif
    }

    private func dinle() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await sonuc in Transaction.updates {
                guard let self else { continue }
                if case .verified(let t) = sonuc {
                    await self.odulVer(t)
                    await t.finish()
                }
            }
        }
    }
}
