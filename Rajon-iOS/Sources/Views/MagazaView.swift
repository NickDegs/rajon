import SwiftUI
import StoreKit

/// Mağaza — IAP ürünleri (nakit paketleri, efsane, VIP).
struct MagazaView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if store.vipAktif { vipBanner }

                Text("KAN PARASI VIP")
                    .sectionHeader()
                if let p = store.urun(.vip) {
                    UrunRow(urun: .vip, product: p, owned: store.vipAktif)
                }

                Text("NAKİT")
                    .sectionHeader()
                ForEach([RajonUrun.nakitKucuk, .nakitOrta, .nakitBuyuk, .nakitVurgun], id: \.self) { u in
                    if let p = store.urun(u) {
                        UrunRow(urun: u, product: p)
                    }
                }

                Text("ÖZEL")
                    .sectionHeader()
                if let p = store.urun(.efsaneAdam) {
                    UrunRow(urun: .efsaneAdam, product: p)
                }

                Button {
                    Task { await store.geriYukle() }
                } label: {
                    Text("Satın Alımları Geri Yükle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.smoke)
                }
                .padding(.top, 6)

                if store.products.isEmpty {
                    Text("Ürünler yükleniyor… (TestFlight'ta StoreKit ürünleri ASC'de onaylı olmalı)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.smoke)
                        .multilineTextAlignment(.center)
                }
                if let e = store.sonHata {
                    Text(e).font(.system(size: 11)).foregroundStyle(Theme.blood)
                }
            }
            .padding(16)
        }
    }

    private var vipBanner: some View {
        HStack {
            Image(systemName: "star.circle.fill").foregroundStyle(Theme.gold)
            Text("Kan Parası VIP aktif — gelir 2 katı")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            Spacer()
        }
        .cardStyle(12)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
    }
}

struct UrunRow: View {
    @EnvironmentObject var store: StoreManager
    let urun: RajonUrun
    let product: Product
    var owned: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.panelHi)
                Image(systemName: urun.ikon)
                    .font(.system(size: 22))
                    .foregroundStyle(urun == .vip || urun == .efsaneAdam ? Theme.gold : Theme.blood)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(urun.baslik).font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                Text(urun.altyazi).font(.system(size: 12)).foregroundStyle(Theme.smoke)
            }
            Spacer()

            Button {
                Task { await store.satinAl(product) }
            } label: {
                Text(owned ? "AKTİF" : product.displayPrice)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(owned ? Theme.gold : .white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(owned ? Theme.panelHi : Theme.blood)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .disabled(owned || store.yukleniyor)
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
