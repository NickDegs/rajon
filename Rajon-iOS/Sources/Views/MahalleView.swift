import SwiftUI

/// Mahalle — Travian tarzı bina yönetimi: seviye, zamanlı inşaat kuyruğu, canlı geri sayım.
struct MahalleView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                baslik
                // İnşaat kuyruğu durumu
                if let b = game.insaattakiBina {
                    insaatKuyrugu(b)
                }
                ForEach(game.binalar) { bina in
                    BinaKart(bina: bina)
                }
            }
            .padding(16)
        }
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MAHALLE").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
            Text("Binalarını kur ve yükselt. Karargah inşaatı hızlandırır, Kasa para basar, Kışla kadronu büyütür.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insaatKuyrugu(_ b: Bina) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let kalan = max(0, Int(b.insaatBitis?.timeIntervalSinceNow ?? 0))
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill").foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("İNŞAATTA: \(b.tip.ad) → Sv.\(b.seviye + 1)")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    Text(sureMetni(kalan)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }
                Spacer()
                Button { game.binaHizlandir(b.id) } label: {
                    Text("HIZLANDIR").font(.system(size: 11, weight: .black))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.gold.opacity(0.85)).foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
            .cardStyle(14)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
        }
    }
}

struct BinaKart: View {
    @EnvironmentObject var game: GameStore
    let bina: Bina

    private var guncel: Bina { game.binalar.first { $0.id == bina.id } ?? bina }

    var body: some View {
        let b = guncel
        let mesgul = game.insaatMesgul
        let fiyat = b.yukseltmeMaliyet
        let yeter = game.cash >= fiyat
        return HStack(spacing: 14) {
            // Flux bina görseli
            Image(b.tip.gorsel)
                .resizable().scaledToFill()
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .overlay(alignment: .bottomLeading) {
                    Text("Sv.\(b.seviye)")
                        .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.black.opacity(0.6)).clipShape(Capsule())
                        .padding(5)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(b.tip.ad).font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
                Text(b.tip.aciklama).font(.system(size: 11)).foregroundStyle(Theme.smoke).lineLimit(2)
                Text(bonusMetni(b)).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
            }
            Spacer(minLength: 4)

            Button { game.binaYukselt(b.id) } label: {
                VStack(spacing: 1) {
                    Text(b.seviye == 0 ? "İNŞA ET" : "YÜKSELT").font(.system(size: 11, weight: .black))
                    Text("₺\(fmt(fiyat))").font(.system(size: 12, weight: .heavy, design: .rounded))
                    Text(sureKisa(game.binaSure(b))).font(.system(size: 9, weight: .semibold)).opacity(0.8)
                }
                .foregroundStyle(yeter && !mesgul ? .white : Theme.smoke)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(yeter && !mesgul ? Theme.blood : Theme.panelHi)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!yeter || mesgul || b.insaatta)
        }
        .cardStyle(12)
    }

    private func bonusMetni(_ b: Bina) -> String {
        switch b.tip {
        case .karargah:   return "İnşaat hızı +\(b.seviye * 7)%"
        case .kasa:       return "dk / ₺\(fmt(80 * b.seviye))"
        case .depo:       return "Kapasite ₺\(fmt(200_000 + b.seviye * 250_000))"
        case .cephanelik: return "Saldırı +\(b.seviye * 7)%"
        case .kisla:      return "Saha kadrosu \(min(6, 4 + b.seviye / 2))"
        case .korunak:    return "Savunma \(60 * b.seviye)"
        }
    }
}

// Süre biçimleme yardımcıları
func sureMetni(_ sn: Int) -> String {
    if sn >= 3600 { return String(format: "%d sa %d dk", sn / 3600, (sn % 3600) / 60) }
    if sn >= 60 { return String(format: "%d dk %d sn", sn / 60, sn % 60) }
    return "\(sn) sn"
}
func sureKisa(_ s: Double) -> String {
    let sn = Int(s)
    if sn >= 60 { return "\(sn / 60)dk \(sn % 60)sn" }
    return "\(sn)sn"
}
