import SwiftUI

/// Demirci — birlik türü başına kalıcı yükseltme (her seviye +%2 saldırı & savunma, maks 20).
struct DemirciView: View {
    @EnvironmentObject var online: OnlineService

    private static let ad: [String: String] = [
        "tetikci": "Tetikçi", "kabadayi": "Kabadayı", "sofor": "Şoför", "yikici": "Yıkıcı",
        "sef": "Şef", "suvari": "Süvari", "muhafiz": "Muhafız", "izci": "İzci",
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Her yükseltme o birimin saldırı ve savunmasını kalıcı %2 artırır. Ordunu kalabalıklaştırmadan güçlendir.")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke).padding(.horizontal, 4)
                ForEach(online.demirci?.birimler ?? []) { b in kart(b) }
            }.padding(14)
        }
        .task { await online.demirciCek() }
    }

    private func kart(_ b: DemirciBirim) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(Self.ad[b.tip] ?? b.tip).font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                    Text("Sv.\(b.seviye)/\(b.maks)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
                }
                Text("Mevcut bonus: +%\(b.bonus) saldırı & savunma").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                if b.acik {
                    Text("Sonraki: ₺\(b.cash) + \(b.cephane) cephane").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                }
            }
            Spacer()
            if b.acik {
                Button { Task { await online.demirciYukselt(b.tip) } } label: {
                    Label("Yükselt", systemImage: "hammer.fill").font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.blood).clipShape(Capsule())
                }.buttonStyle(.plain)
            } else {
                Text("MAKS").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
            }
        }.cardStyle(12)
    }
}
