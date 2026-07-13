import SwiftUI

/// Tam köy yönetimi — bağımsız ekonomi: bina yükselt, kaynak topla, asker eğit.
struct KoyYonetimView: View {
    @EnvironmentObject var online: OnlineService
    let bid: Int

    static let binaAd: [String: String] = [
        "karargah": "Karargah", "kasa": "Kasa Dairesi", "depo": "Depo",
        "cephanelik": "Cephanelik", "kisla": "Kışla", "korunak": "Korunak", "zula": "Zula",
        "belediye": "Belediye", "akademi": "Akademi", "hastane": "Hastane",
        "meyhane": "Meyhane", "imalathane": "İmalathane",
    ]
    static let askerAd: [String: String] = [
        "tetikci": "Tetikçi", "kabadayi": "Kabadayı", "sofor": "Şoför", "yikici": "Yıkıcı",
        "sef": "Şef", "suvari": "Süvari", "muhafiz": "Muhafız", "izci": "İzci",
    ]

    var body: some View {
        ScrollView {
            if let k = online.aktifKoy, k.id == bid {
                VStack(spacing: 14) {
                    ustBar(k)
                    binalar(k)
                    ordu(k)
                }.padding(14)
            } else {
                ProgressView().padding(.top, 40)
            }
        }
        .task { await online.koyGor(bid) }
    }

    private func ustBar(_ k: KoyView) -> some View {
        VStack(spacing: 8) {
            Text(k.ad).font(.system(size: 18, weight: .black)).foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                deger("Nakit", "₺\(k.cash)", Theme.gold)
                deger("Kasa", "₺\(k.idle)", Theme.gold)
                deger("Cephane", "\(k.cephane)", Theme.smoke)
                deger("İçki", "\(k.icki)", Theme.blood)
                deger("Mal", "\(k.mal)", Theme.gold)
            }
            Text("Gelir: ₺\(k.incomePerMin)/dk · Savunma: \(k.savunma)").font(.system(size: 12)).foregroundStyle(Theme.smoke)
            Button { Task { await online.koyTopla(bid) } } label: {
                Label("Kasayı Topla (₺\(k.idle))", systemImage: "arrow.down.circle.fill").font(.system(size: 14, weight: .black)).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Theme.gold).disabled(k.idle <= 0)
        }.frame(maxWidth: .infinity).cardStyle(14)
    }

    private func binalar(_ k: KoyView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BİNALAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(k.buildings) { b in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(LocalizedStringKey(Self.binaAd[b.tip] ?? b.tip)) + Text(" · Sv.\(b.seviye)")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                        if b.insaatta { Text("İnşaatta · \(sure(b.kalan))").font(.system(size: 11)).foregroundStyle(Theme.gold) }
                        else { Text(b.icki > 0 ? "₺\(b.fiyat) · 🍷\(b.icki) · \(sure(b.sure))" : "₺\(b.fiyat) · \(sure(b.sure))").font(.system(size: 11)).foregroundStyle(Theme.smoke) }
                    }
                    Spacer()
                    Button { Task { await online.koyBina(bid, b.tip) } } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(k.insaatMesgul ? Theme.smoke.opacity(0.4) : Theme.gold)
                    }.disabled(k.insaatMesgul || b.insaatta)
                }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func ordu(_ k: KoyView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KÖY ORDUSU").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            let mevcut = k.army.filter { $0.value > 0 }
            if mevcut.isEmpty { Text("Köyde savunma yok — garnizon gönder veya eğit.").font(.system(size: 12)).foregroundStyle(Theme.blood) }
            else {
                Text(mevcut.map { "\(Self.askerAd[$0.key] ?? $0.key): \($0.value)" }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(Theme.ink)
            }
            if let t = k.train { Text("Eğitimde: \(Self.askerAd[t.tip] ?? t.tip) ×\(t.count) · \(sure(t.kalan))").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold) }
            Text("KÖYDE EĞİT").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.smoke).padding(.top, 4)
            ForEach(["muhafiz", "kabadayi", "tetikci", "suvari"], id: \.self) { tip in
                Button { Task { await online.koyAsker(bid, tip, 5) } } label: {
                    HStack {
                        Text("\(Self.askerAd[tip] ?? tip) ×5").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(Theme.gold)
                    }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).disabled(k.train != nil)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func deger(_ ad: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.system(size: 14, weight: .black)).foregroundStyle(c)
            Text(LocalizedStringKey(ad)).font(.system(size: 10)).foregroundStyle(Theme.smoke)
        }
    }
    private func sure(_ sn: Int) -> String { sn >= 60 ? "\(sn / 60)dk \(sn % 60)sn" : "\(sn)sn" }
}
