import SwiftUI

/// SMS ile giriş — telefon numarana hesabını bağla, her cihazda geri yükle.
struct SmsLoginView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) private var dismiss

    enum Adim { case telefon, kod }
    @State private var adim: Adim = .telefon
    @State private var telefon = ""
    @State private var kod = ""
    @State private var bilgi: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                baslik
                if online.smsGirisli {
                    girisliKart
                } else if adim == .telefon {
                    telefonKart
                } else {
                    kodKart
                }
                if let b = bilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                        .multilineTextAlignment(.center)
                }
                if let h = online.hata {
                    Text(h).font(.system(size: 12)).foregroundStyle(Theme.blood)
                }
            }
            .padding(16)
        }
    }

    private var baslik: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.and.arrow.up.fill").font(.system(size: 46)).foregroundStyle(Theme.blood)
            Text("TELEFONLA YEDEKLE").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
            Text("Numaranı bağla; ilerlemen telefonuna kaydedilir ve yeni cihazda otomatik geri yüklenir. Ayrıca iCloud'a da yedeklenir.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
        }
    }

    private var telefonKart: some View {
        VStack(spacing: 12) {
            TextField("+90 5xx xxx xx xx", text: $telefon)
                .keyboardType(.phonePad)
                .font(.system(size: 18, weight: .bold)).padding(12)
                .background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
            Button {
                Task {
                    if await online.smsKodGonder(phone: telefon) {
                        adim = .kod; bilgi = "Kod gönderildi, SMS'ini kontrol et."
                    }
                }
            } label: {
                Text(online.mesgul ? "Gönderiliyor…" : "KOD GÖNDER").font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(telefon.count >= 7 ? Theme.blood : Theme.panelHi).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(telefon.count < 7 || online.mesgul)
        }
        .cardStyle(18)
    }

    private var kodKart: some View {
        VStack(spacing: 12) {
            Text("\(telefon) numarasına gelen kodu gir").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            TextField("6 haneli kod", text: $kod)
                .keyboardType(.numberPad)
                .font(.system(size: 24, weight: .heavy, design: .rounded)).multilineTextAlignment(.center).padding(12)
                .background(Theme.panelHi).clipShape(RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
            Button {
                Task {
                    if await online.smsDogrula(phone: telefon, code: kod, game: game) {
                        bilgi = "Hesabın telefonuna bağlandı ✓"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
                    }
                }
            } label: {
                Text(online.mesgul ? "Doğrulanıyor…" : "DOĞRULA").font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(kod.count >= 4 ? Theme.blood : Theme.panelHi).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(kod.count < 4 || online.mesgul)
            Button("Numarayı değiştir") { adim = .telefon; kod = "" }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke)
        }
        .cardStyle(18)
    }

    private var girisliKart: some View {
        VStack(spacing: 12) {
            Label("Telefonla yedek aktif", systemImage: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .black)).foregroundStyle(Color.green)
            Text("İlerlemen telefonuna ve iCloud'a otomatik yedekleniyor. Yeni bir cihazda aynı numarayla giriş yap, kaldığın yerden devam et.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
            Button(role: .destructive) {
                online.smsCikis(game: game); bilgi = "Telefon bağlantısı kaldırıldı (ilerlemen cihazda kalır)."
            } label: {
                Text("Bağlantıyı Kaldır").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.blood)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Theme.bloodDim.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .cardStyle(18)
    }
}
