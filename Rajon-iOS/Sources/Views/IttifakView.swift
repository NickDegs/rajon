import SwiftUI

/// İttifak (çete) bonusları — üyeler katkı yapar, tüm çete faydalanır (kalıcı saldırı/savunma/gelir).
struct IttifakView: View {
    @EnvironmentObject var online: OnlineService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let i = online.ittifak, !i.clan.isEmpty {
                    Text("Çeten: \(i.clan)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Katkın tüm çete üyelerini kalıcı güçlendirir. Birlikte yatırım yapın.")
                        .font(.system(size: 12)).foregroundStyle(Theme.smoke).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(i.bonuslar) { b in kart(b) }
                } else {
                    Text("İttifak bonusları için bir çeteye katılman gerekir.")
                        .font(.system(size: 14)).foregroundStyle(Theme.smoke).padding(.top, 30)
                }
            }.padding(14)
        }
        .task { await online.ittifakCek() }
    }

    private func kart(_ b: IttifakBonus) -> some View {
        HStack {
            Image(systemName: ikon(b.tip)).foregroundStyle(Theme.gold).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(b.ad) · Sv.\(b.seviye)").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                Text("Çete geneli +%\(b.bonus) · sonraki ₺\(b.cash)").font(.system(size: 11)).foregroundStyle(Theme.smoke)
            }
            Spacer()
            Button { Task { await online.ittifakYukselt(b.tip) } } label: {
                Label("Katkı", systemImage: "plus.circle.fill").font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.blood).clipShape(Capsule())
            }.buttonStyle(.plain)
        }.cardStyle(12)
    }

    private func ikon(_ t: String) -> String {
        switch t { case "atk": return "flame.fill"; case "def": return "shield.fill"; default: return "dollarsign.circle.fill" }
    }
}
