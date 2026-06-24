import SwiftUI

/// Ayarlar — hesap, satın alma geri yükleme, oyunu sıfırlama.
struct AyarlarView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var online: OnlineService

    @State private var adDuzenle = ""
    @State private var sifirlaUyari = false
    @State private var bilgi: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Online hesap
                VStack(alignment: .leading, spacing: 10) {
                    Text("ONLINE HESAP").sectionHeader()
                    if online.girisli {
                        Text("Patron: \(online.me?.ad ?? online.ad)")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        HStack {
                            TextField("Yeni patron adı", text: $adDuzenle)
                                .padding(10).background(Theme.panelHi)
                                .clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(.white)
                            Button("Kaydet") {
                                Task {
                                    online.ad = adDuzenle.isEmpty ? online.ad : adDuzenle
                                    await online.sync(game: game)
                                    await online.liderTablosu()
                                    bilgi = "Patron adı güncellendi."
                                }
                            }
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                        }
                    } else {
                        Text("Online moda 'Online' sekmesinden giriş yap.")
                            .font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    }
                }
                .cardStyle(14)

                // Satın almalar
                VStack(alignment: .leading, spacing: 10) {
                    Text("SATIN ALMALAR").sectionHeader()
                    if store.vipAktif {
                        Label("Kan Parası VIP aktif", systemImage: "star.circle.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                    }
                    Button {
                        Task { await store.geriYukle(); bilgi = "Satın alımlar geri yüklendi." }
                    } label: {
                        Text("Satın Alımları Geri Yükle")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .cardStyle(14)

                // Tehlikeli bölge
                VStack(alignment: .leading, spacing: 10) {
                    Text("OYUN").sectionHeader()
                    Button(role: .destructive) {
                        sifirlaUyari = true
                    } label: {
                        Text("Oyunu Sıfırla")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.blood)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Theme.bloodDim.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text("Tüm ilerleme silinir, baştan başlarsın. Online hesabın kalır.")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                }
                .cardStyle(14)

                if let b = bilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }

                Text("Rajon · sürüm 1.0\nBütün karakterler ve olaylar kurgudur.")
                    .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                    .multilineTextAlignment(.center).padding(.top, 6)
            }
            .padding(16)
        }
        .onAppear { adDuzenle = online.me?.ad ?? online.ad }
        .alert("Emin misin?", isPresented: $sifirlaUyari) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive) { game.sifirla(); bilgi = "Oyun sıfırlandı." }
        } message: {
            Text("Bütün ilerlemen silinecek. Bu geri alınamaz.")
        }
    }
}
