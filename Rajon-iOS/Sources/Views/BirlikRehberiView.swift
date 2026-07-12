import SwiftUI

/// Birlik Rehberi — her birimin saldırı türü (piyade/süvari) ve AYRI savunma değerleri.
/// Travian tarzı taş-kağıt-makas: savunmada doğru birimi seçmek kritik.
struct BirlikRehberiView: View {
    @EnvironmentObject var online: OnlineService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Savunma, saldıranın piyade/süvari oranına göre ağırlıklanır. Piyadeye karşı Muhafız, süvariye karşı Kabadayı güçlüdür — düşmanın neyle geldiğine göre savun.")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke).padding(.horizontal, 4)
                ForEach(online.birimKatalog) { b in kart(b) }
            }.padding(14)
        }
        .task { await online.birimKatalogCek() }
    }

    private func kart(_ b: BirimBilgi) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(b.ad).font(.system(size: 16, weight: .black)).foregroundStyle(Theme.ink)
                Text(b.tur == "piyade" ? "PİYADE" : "SÜVARİ")
                    .font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(b.tur == "piyade" ? Theme.blood : Theme.gold).clipShape(Capsule())
                Spacer()
                Text(b.rol).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.smoke)
            }
            HStack(spacing: 16) {
                deger("Saldırı", "\(b.saldiri)", Theme.blood)
                deger("Sav. (Piyadeye)", "\(b.defPiyade)", Theme.gold)
                deger("Sav. (Süvariye)", "\(b.defSuvari)", Theme.gold)
                if b.yagma > 0 { deger("Yağma", "\(b.yagma)", Theme.smoke) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(12)
    }

    private func deger(_ ad: String, _ v: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.system(size: 14, weight: .black)).foregroundStyle(c)
            Text(ad).font(.system(size: 9)).foregroundStyle(Theme.smoke)
        }
    }
}
