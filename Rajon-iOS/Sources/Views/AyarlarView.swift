import SwiftUI

/// Ayarlar — hesap, satın alma geri yükleme, oyunu sıfırlama.
struct AyarlarView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var online: OnlineService
    @EnvironmentObject var tema: ThemeManager

    @ObservedObject private var sound = SoundManager.shared
    @State private var adDuzenle = ""
    @State private var sifirlaUyari = false
    @State private var bilgi: String?
    @State private var smsAcik = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Online hesap
                VStack(alignment: .leading, spacing: 10) {
                    Text("ONLINE HESAP").sectionHeader()
                    if online.girisli {
                        Text("Patron: \(online.me?.ad ?? online.ad)")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                        HStack {
                            TextField("Yeni patron adı", text: $adDuzenle)
                                .padding(10).background(Theme.panelHi)
                                .clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(Theme.ink)
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

                // Telefon yedek / SMS giriş
                VStack(alignment: .leading, spacing: 10) {
                    Text("TELEFON YEDEK").sectionHeader()
                    Button { smsAcik = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: online.smsGirisli ? "checkmark.icloud.fill" : "icloud.and.arrow.up.fill")
                                .foregroundStyle(online.smsGirisli ? Color.green : Theme.blood)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(online.smsGirisli ? "Telefonla yedek aktif" : "Telefonla Yedekle / Giriş")
                                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                                Text("SMS ile bağla; iCloud + telefonuna otomatik yedek")
                                    .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .cardStyle(14)

                // Satın almalar
                VStack(alignment: .leading, spacing: 10) {
                    Text("SATIN ALMALAR").sectionHeader()
                    if store.destekciMi {
                        Label("Destekçisin — teşekkürler! 🎩", systemImage: "hands.clap.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                    }
                    Text("Tüm satın alımlar kozmetiktir, oyunu güçlendirmez.")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                    Button {
                        Task { await store.geriYukle(); bilgi = "Satın alımlar geri yüklendi." }
                    } label: {
                        Text("Satın Alımları Geri Yükle")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .cardStyle(14)

                // Görünüm (tema)
                VStack(alignment: .leading, spacing: 10) {
                    Text("GÖRÜNÜM").sectionHeader()
                    Picker("Tema", selection: $tema.mode) {
                        ForEach(ThemeMode.allCases, id: \.self) { m in
                            Label(m.ad, systemImage: m.ikon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Karanlık noir mu, açık tema mı — sen seç.")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                }
                .cardStyle(14)

                // Ses
                VStack(alignment: .leading, spacing: 10) {
                    Text("SES").sectionHeader()
                    Toggle(isOn: $sound.acik) {
                        Label("Ses efektleri", systemImage: sound.acik ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.blood)
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
        .sheet(isPresented: $smsAcik) {
            NavigationStack {
                SmsLoginView()
                    .navigationTitle("Telefon Yedek")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { smsAcik = false } } }
                    .background(Theme.bg)
            }
            .preferredColorScheme(tema.colorScheme)
            .environmentObject(game)
            .environmentObject(online)
        }
        .alert("Emin misin?", isPresented: $sifirlaUyari) {
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive) { game.sifirla(); bilgi = "Oyun sıfırlandı." }
        } message: {
            Text("Bütün ilerlemen silinecek. Bu geri alınamaz.")
        }
    }
}
