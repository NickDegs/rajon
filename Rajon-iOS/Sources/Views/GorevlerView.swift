import SwiftUI

/// Günlük görevler — topla / eğit / baskın hedefleri + ödül al.
struct GorevlerView: View {
    @EnvironmentObject var online: OnlineService

    private static let ikon: [String: String] = ["topla": "dollarsign.circle.fill", "egit": "figure.walk", "baskin": "flame.fill"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Her gün yenilenir. Tamamla, ödülü al.")
                    .font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(online.gorevler) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: Self.ikon[g.tip] ?? "target").font(.system(size: 24)).foregroundStyle(Theme.gold).frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.ad).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.ink)
                                Text("\(g.ilerleme)/\(g.hedef) · ödül ₺\(fmt(g.odul))").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                            }
                            Spacer()
                            if g.alindi {
                                Label("Alındı", systemImage: "checkmark.seal.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke)
                            } else if g.tamam {
                                Button { Task { await online.gorevOdulAl(g.tip) } } label: {
                                    Text("ÖDÜL AL").font(.system(size: 12, weight: .black))
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Theme.gold).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                            }
                        }
                        // ilerleme çubuğu
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.panelHi).frame(height: 8)
                                Capsule().fill(g.tamam ? Theme.gold : Theme.blood)
                                    .frame(width: geo.size.width * CGFloat(min(1, Double(g.ilerleme) / Double(max(1, g.hedef)))), height: 8)
                            }
                        }.frame(height: 8)
                    }.cardStyle(14)
                }
                if online.gorevler.isEmpty {
                    Text("Görevler yükleniyor…").font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 20)
                }
            }.padding(16)
        }
        .task { await online.gorevlerCek() }
    }
}
