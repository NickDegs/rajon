import SwiftUI

/// Ordu & Sefer — asker eğit, akına gönder (Travian tarzı zamanlı sefer).
struct SeferView: View {
    @EnvironmentObject var game: GameStore
    @State private var secimTip: AskerTip = .tetikci
    @State private var adet = 5

    // Akın hedefleri (özgün NPC kampları)
    private let hedefler: [(ad: String, guc: Int, sure: Double, yagma: Int)] = [
        ("Sıçan Sokağı Deposu", 180, 60, 9_000),
        ("Liman Antreposu", 650, 180, 34_000),
        ("Rakip Kerhane", 1_300, 300, 78_000),
        ("Kaçak Mazot Rafinerisi", 2_600, 600, 180_000),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                orduKart
                egitimKart
                if !game.seferler.isEmpty { aktifSeferler }
                hedeflerKart
            }
            .padding(16)
        }
    }

    // MARK: Ordu
    private var orduKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ORDUN").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Text("Saldırı \(fmt(game.orduSaldiri)) · Savunma \(fmt(game.orduSavunma))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            }
            HStack(spacing: 10) {
                ForEach(AskerTip.allCases, id: \.self) { tip in
                    VStack(spacing: 4) {
                        Image(tip.gorsel).resizable().scaledToFill()
                            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                        Text(tip.ad).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        Text("\(game.orduSayi(tip))").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle(14)
    }

    // MARK: Eğitim
    private var egitimKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASKER EĞİT").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            if let e = game.egitim {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let kalan = max(0, Int(e.bitis.timeIntervalSinceNow))
                    HStack {
                        Image(e.tip.gorsel).resizable().scaledToFill().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("\(e.sayi)× \(e.tip.ad) eğitiliyor").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Text(sureMetni(kalan)).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                    }
                }
            } else {
                Picker("", selection: $secimTip) {
                    ForEach(AskerTip.allCases, id: \.self) { Text($0.ad).tag($0) }
                }.pickerStyle(.segmented)
                Text(secimTip.aciklama).font(.system(size: 11)).foregroundStyle(Theme.smoke)
                Stepper("Adet: \(adet)", value: $adet, in: 1...50).foregroundStyle(.white)
                let fiyat = secimTip.maliyet * adet
                Button { game.askerEgit(secimTip, sayi: adet) } label: {
                    Text("EĞİT  ·  ₺\(fmt(fiyat))").font(.system(size: 15, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(game.cash >= fiyat ? Theme.blood : Theme.panelHi)
                        .foregroundStyle(game.cash >= fiyat ? .white : Theme.smoke)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .disabled(game.cash < fiyat)
            }
        }
        .cardStyle(14)
    }

    // MARK: Aktif seferler
    private var aktifSeferler: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOLDAKİ SEFERLER").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(game.seferler) { s in
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let kalan = max(0, Int(s.donus.timeIntervalSinceNow))
                    HStack {
                        Image(systemName: "car.fill").foregroundStyle(Theme.blood)
                        Text(s.hedefAd).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Spacer()
                        Text(kalan > 0 ? sureMetni(kalan) : "dönüyor…")
                            .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
                    }
                }
            }
        }
        .cardStyle(14)
    }

    // MARK: Hedefler
    private var hedeflerKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AKIN HEDEFLERİ").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            if game.orduToplam == 0 {
                Text("Önce asker eğit, sonra akına çık.").font(.system(size: 12)).foregroundStyle(Theme.blood)
            }
            ForEach(Array(hedefler.enumerated()), id: \.offset) { _, h in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Theme.panelHi)
                        Image(systemName: "shippingbox.fill").foregroundStyle(Theme.blood)
                    }.frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(h.ad).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("Savunma \(fmt(h.guc)) · Yağma ₺\(fmt(h.yagma)) · \(sureMetni(Int(h.sure)))")
                            .font(.system(size: 11)).foregroundStyle(game.orduSaldiri >= h.guc ? Color.green : Theme.smoke)
                    }
                    Spacer()
                    Button {
                        game.seferGonder(hedefAd: h.ad, hedefGuc: h.guc, sure: h.sure, taliMax: h.yagma)
                    } label: {
                        Text("AKIN").font(.system(size: 12, weight: .black))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(game.orduToplam > 0 ? Theme.bloodDim : Theme.panelHi)
                            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disabled(game.orduToplam == 0)
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle(14)
    }
}
