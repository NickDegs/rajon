import SwiftUI

/// Kervan (taşıma süreli kaynak sevki) + Ticaret Rotaları (periyodik otomatik sevk) — köyler arası ekonomi.
struct KervanView: View {
    @EnvironmentObject var online: OnlineService
    @State private var hedef: Int = 0
    @State private var miktar = 5000
    @State private var periyotDk = 5

    private var koyler: [Us] { online.uslerim.filter { !$0.ana } }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if koyler.isEmpty {
                    Text("Önce bir köy kur. Kervanlar ana üsten köylerine kaynak taşır.")
                        .font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 20)
                } else {
                    gonderKart
                    if let k = online.kervan, !k.yolda.isEmpty { yoldaKart(k) }
                    if let k = online.kervan, !k.rotalar.isEmpty { rotaKart(k) }
                }
            }.padding(14)
        }
        .task { await online.uslerimCek(); await online.kervanlarCek(); if hedef == 0 { hedef = koyler.first?.id ?? 0 } }
    }

    private var gonderKart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KAYNAK SEVK ET").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            Picker("Hedef köy", selection: $hedef) {
                ForEach(koyler) { Text($0.ad).tag($0.id) }
            }.pickerStyle(.menu)
            Stepper("Miktar: ₺\(miktar)", value: $miktar, in: 1000...1_000_000, step: 1000)
            Button { Task { await online.kervanGonder(hedef, miktar) } } label: {
                Label("Kervan Yolla (tek sefer)", systemImage: "shippingbox.fill").font(.system(size: 14, weight: .black)).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Theme.gold).disabled(hedef == 0)
            Divider()
            Stepper("Rota periyodu: \(periyotDk) dk", value: $periyotDk, in: 1...120)
            Button { Task { await online.rotaEkle(hedef, miktar, periyotDk * 60) } } label: {
                Label("Ticaret Rotası Kur (otomatik)", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .black)).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Theme.blood).disabled(hedef == 0)
            Text("Kervan ana üs kasandan (topladığın nakit) taşır. Rota her periyotta otomatik yollar.")
                .font(.system(size: 10)).foregroundStyle(Theme.smoke)
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func yoldaKart(_ k: KervanDurum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOLDAKİ KERVANLAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(k.yolda) { y in
                HStack {
                    Image(systemName: "shippingbox.fill").foregroundStyle(Theme.gold)
                    Text("\(y.hedef) → ₺\(y.miktar)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(sure(y.kalan)).font(.system(size: 12)).foregroundStyle(Theme.smoke)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func rotaKart(_ k: KervanDurum) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TİCARET ROTALARI").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            ForEach(k.rotalar) { r in
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.blood)
                    Text("\(r.hedef) → ₺\(r.miktar) / \(r.periyot / 60)dk").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button { Task { await online.rotaSil(r.id) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.smoke)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    private func sure(_ sn: Int) -> String { sn >= 60 ? "\(sn / 60)dk \(sn % 60)sn" : "\(sn)sn" }
}
