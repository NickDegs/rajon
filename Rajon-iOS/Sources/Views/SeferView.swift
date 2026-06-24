import SwiftUI

/// Ordu & Sefer — asker eğit, akına gönder (Travian tarzı zamanlı sefer).
struct SeferView: View {
    @EnvironmentObject var game: GameStore
    @State private var secimTip: AskerTip = .tetikci
    @State private var adet = 5

    // Akın hedefleri (özgün NPC kampları)
    private let hedefler: [(ad: String, guc: Int, sure: Double, yagma: Int, gorsel: String)] = [
        ("Sıçan Sokağı Deposu", 180, 60, 9_000, "hedef_0"),
        ("Liman Antreposu", 650, 180, 34_000, "hedef_1"),
        ("Rakip Kerhane", 1_300, 300, 78_000, "hedef_2"),
        ("Kaçak Mazot Rafinerisi", 2_600, 600, 180_000, "hedef_3"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                orduKart
                karaborsaKart
                egitimKart
                if !game.seferler.isEmpty { aktifSeferler }
                hedeflerKart
                if !game.raporlar.isEmpty { raporlarKart }
            }
            .padding(16)
        }
    }

    private var raporlarKart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAPORLAR").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(game.raporlar.prefix(8)) { r in
                HStack(spacing: 10) {
                    Image(systemName: r.kazandi ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .foregroundStyle(r.kazandi ? Color.green : Theme.blood)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.baslik).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        Text(r.detay).font(.system(size: 11)).foregroundStyle(Theme.smoke).lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
        .cardStyle(14)
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

    // MARK: Karaborsa
    private var karaborsaKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("KARABORSA").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
                Spacer()
                Label("\(fmt(game.cephane)) mühimmat", systemImage: "circle.hexagongrid.fill")
                    .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
            }
            Text("Mühimmat al/sat. Al: \(game.cephaneAlisKuru)₺ · Sat: \(game.cephaneSatisKuru)₺ (adet)")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke)
            HStack(spacing: 8) {
                ForEach([50, 100, 250], id: \.self) { m in
                    Button { game.cephaneAl(m) } label: {
                        VStack(spacing: 0) {
                            Text("+\(m)").font(.system(size: 13, weight: .black))
                            Text("₺\(fmt(m * game.cephaneAlisKuru))").font(.system(size: 10, weight: .semibold)).opacity(0.85)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(game.cash >= m * game.cephaneAlisKuru ? Theme.bloodDim : Theme.panelHi)
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain).disabled(game.cash < m * game.cephaneAlisKuru)
                }
                Button { game.cephaneSat(100) } label: {
                    VStack(spacing: 0) {
                        Text("Sat 100").font(.system(size: 13, weight: .black))
                        Text("+₺\(fmt(100 * game.cephaneSatisKuru))").font(.system(size: 10, weight: .semibold)).opacity(0.85)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(game.cephane >= 100 ? Theme.gold.opacity(0.85) : Theme.panelHi)
                    .foregroundStyle(game.cephane >= 100 ? .black : Theme.smoke).clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain).disabled(game.cephane < 100)
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
                let cephaneFiyat = secimTip.cephaneMaliyet * adet
                let yeter = game.cash >= fiyat && game.cephane >= cephaneFiyat
                Button { game.askerEgit(secimTip, sayi: adet) } label: {
                    VStack(spacing: 1) {
                        Text("EĞİT").font(.system(size: 15, weight: .black))
                        Text("₺\(fmt(fiyat))  ·  \(cephaneFiyat) mühimmat").font(.system(size: 11, weight: .semibold)).opacity(0.85)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(yeter ? Theme.blood : Theme.panelHi)
                    .foregroundStyle(yeter ? .white : Theme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
                .disabled(!yeter)
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
                    Image(h.gorsel).resizable().scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
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
