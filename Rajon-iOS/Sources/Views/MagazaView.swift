import SwiftUI
import StoreKit

/// Mağaza — YALNIZCA KOZMETİK. Hiçbir ürün oyunu güçlendirmez.
struct MagazaView: View {
    @EnvironmentObject var store: StoreManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                bilgiNotu

                Text("KOZMETİK").sectionHeader()
                ForEach(RajonUrun.allCases, id: \.self) { u in
                    if let p = store.urun(u) {
                        KozmetikRow(urun: u, product: p, owned: store.sahip(u))
                    } else {
                        KozmetikRow(urun: u, product: nil, owned: store.sahip(u))
                    }
                }

                if store.urun(.vip) != nil { abonelikNotu }

                Button {
                    Task { await store.geriYukle() }
                } label: {
                    Text("Satın Alımları Geri Yükle")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke)
                }
                .padding(.top, 6)

                if store.products.isEmpty {
                    Text("Ürünler yükleniyor… (TestFlight'ta ASC ürünleri onaylı olmalı)")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
                }
                if let e = store.sonHata {
                    Text(e).font(.system(size: 11)).foregroundStyle(Theme.blood)
                }
            }
            .padding(16)
        }
    }

    private var bilgiNotu: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(Color.green)
            Text("Adil oyun: Bu satın alımlar **tamamen kozmetiktir**. Oyunu güçlendirmez, pay-to-win yoktur. Her şey oynayarak kazanılır.")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink)
        }
        .cardStyle(14)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.green.opacity(0.4), lineWidth: 1))
    }

    // Apple 3.1.2 — abonelik açıklaması + zorunlu linkler
    private var abonelikNotu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kan Parası VIP — aylık abonelik")
                .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.gold)
            Text("Ödeme, satın alma onayında Apple Kimliği hesabına işlenir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir; hesabına dönem sonundan 24 saat içinde yenileme ücreti yansır. Aboneliği, satın aldıktan sonra App Store hesap ayarlarından yönetebilir veya iptal edebilirsin.")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke)
            HStack(spacing: 14) {
                Link("Gizlilik Politikası", destination: URL(string: "https://rajon.nickdegs.com/privacy")!)
                Link("Kullanım Şartları (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
        }
        .cardStyle(14)
    }
}

struct KozmetikRow: View {
    @EnvironmentObject var store: StoreManager
    let urun: RajonUrun
    let product: Product?
    var owned: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.panelHi)
                if let s = urun.rozetSembol {
                    Text(s).font(.system(size: 26))
                } else {
                    Image(systemName: urun.ikon).font(.system(size: 22)).foregroundStyle(Theme.gold)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(urun.baslik).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.ink)
                Text(urun.altyazi).font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            Spacer()

            Button {
                if let p = product { Task { await store.satinAl(p) } }
            } label: {
                Text(owned ? "SAHİP" : (product?.displayPrice ?? "—"))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(owned ? Theme.gold : .white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(owned ? Theme.panelHi : Theme.blood)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .disabled(owned || product == nil || store.yukleniyor)
        }
        .cardStyle(12)
    }
}

extension Text {
    func sectionHeader() -> some View {
        self.font(.system(size: 12, weight: .black))
            .foregroundStyle(Theme.smoke)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
