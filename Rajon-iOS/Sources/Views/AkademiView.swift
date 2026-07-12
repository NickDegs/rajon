import SwiftUI

/// Akademi (ileri birlik araştırma) + Belediye (kutlama → kültür puanı) + genişleme.
struct AkademiView: View {
    @EnvironmentObject var online: OnlineService

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                kulturKart
                belediyeKart
                akademiKart
            }.padding(14)
        }
        .task { await online.argeCek() }
    }

    private var kulturKart: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(Theme.gold)
            Text("Kültür Puanı: \(online.dunya?.kp ?? 0)").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.ink)
            Text("Üretim: \(online.dunya?.kpSaat ?? 0)/saat · Sonraki köy: \(online.dunya?.genislemeBedeli ?? 0) KP")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke)
            Text("Kültür puanı bina seviyelerinden ve kutlamalardan gelir; yeni köy kurmak için gerekir.")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).cardStyle(16)
    }

    private var belediyeKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BELEDİYE — KUTLAMA").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            Text("Kutlama düzenle → anında kültür puanı. (Belediye binası gerekir; büyük kutlama Sv.5 ister.)")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke)
            HStack {
                Button { Task { await online.kutlama(false) } } label: {
                    VStack { Text("Küçük Kutlama").font(.system(size: 13, weight: .black)); Text("₺5.000 → +150 KP").font(.system(size: 10)) }
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Theme.gold)
                Button { Task { await online.kutlama(true) } } label: {
                    VStack { Text("Büyük Kutlama").font(.system(size: 13, weight: .black)); Text("₺25.000 → +800 KP").font(.system(size: 10)) }
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Theme.blood)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private var akademiKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AKADEMİ — ARAŞTIRMA (Sv.\(online.arge?.akademi ?? 0))").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            Text("İleri birlikler eğitmeden önce burada araştırılmalı.")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke)
            ForEach(online.arge?.birimler ?? []) { b in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.ad).font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                        if b.arastirildi { Text("Araştırıldı ✓").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold) }
                        else if !b.acik { Text("Akademi Sv.\(b.gerekenAkademi) gerekir").font(.system(size: 11)).foregroundStyle(Theme.blood) }
                        else { Text("₺\(b.cash) + \(b.cephane) cephane").font(.system(size: 11)).foregroundStyle(Theme.smoke) }
                    }
                    Spacer()
                    if b.arastirildi {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.gold)
                    } else {
                        Button { Task { await online.argeYap(b.tip) } } label: {
                            Text("Araştır").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(b.acik ? Theme.blood : Theme.smoke.opacity(0.4)).clipShape(Capsule())
                        }.buttonStyle(.plain).disabled(!b.acik)
                    }
                }.padding(8).background(Theme.panelHi.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }
}
