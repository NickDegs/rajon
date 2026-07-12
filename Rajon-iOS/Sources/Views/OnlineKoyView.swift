import SwiftUI

/// Travian tarzı KÖY/ÜS görünümü (full online).
/// Dağınık kart listesi yerine: binalar zeminde tıklanabilir parseller olarak durur;
/// üstteki sabit kaynak barı (OnlineWorldView.kaynakBar) korunur, altta haraç + işletme.
struct OnlineKoyView: View {
    @EnvironmentObject var online: OnlineService
    @EnvironmentObject var tema: ThemeManager
    @State private var seciliBina: DBina?
    @State private var isletmelerAcik = false

    static let binaAd: [String: String] = [
        "karargah": "Karargah", "kasa": "Kasa Dairesi", "depo": "Depo",
        "cephanelik": "Cephanelik", "kisla": "Kışla", "korunak": "Korunak", "zula": "Zula",
    ]
    static let binaAciklama: [String: String] = [
        "karargah": "İnşaatları hızlandırır", "kasa": "Dakikalık nakit üretir",
        "depo": "Kasa birikim sınırını artırır", "cephanelik": "Saldırı gücünü artırır",
        "kisla": "Sahaya daha çok adam çıkarır", "korunak": "Baskınlarda savunmanı artırır",
        "zula": "Baskında kaynağının bir kısmını yağmadan gizler",
    ]
    // tip -> (x oranı, y oranı, parsel boyutu)
    private static let yerlesim: [String: (CGFloat, CGFloat, CGFloat)] = [
        "karargah":   (0.50, 0.16, 104),
        "kasa":       (0.25, 0.38, 84),
        "depo":       (0.75, 0.38, 84),
        "cephanelik": (0.25, 0.63, 84),
        "korunak":    (0.75, 0.63, 84),
        "kisla":      (0.50, 0.83, 84),
        "zula":       (0.50, 0.50, 72),
    ]

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                zemin(W, H)
                if let d = online.dunya {
                    yollar(W, H, d)
                    ForEach(d.buildings) { b in
                        let p = Self.yerlesim[b.tip] ?? (0.5, 0.5, 84)
                        KoyBinaTile(bina: b, boyut: p.2) { seciliBina = b }
                            .position(x: W * p.0, y: H * p.1)
                    }
                }
                // Alt aksiyon hapları
                VStack {
                    Spacer()
                    altBar
                }
            }
        }
        .sheet(item: $seciliBina) { b in OnlineBinaDetay(bina: b).environmentObject(online) }
        .sheet(isPresented: $isletmelerAcik) { OnlineIsletmelerSheet().environmentObject(online).environmentObject(tema) }
    }

    // Zemin: koyu radyal "meydan" + kenar karartma
    private func zemin(_ W: CGFloat, _ H: CGFloat) -> some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.panelHi.opacity(0.55), Theme.coal],
                           center: .init(x: 0.5, y: 0.46), startRadius: 8, endRadius: max(W, H) * 0.62)
            RadialGradient(colors: [.clear, .black.opacity(0.55)],
                           center: .center, startRadius: min(W, H) * 0.30, endRadius: max(W, H) * 0.72)
        }
        .ignoresSafeArea()
    }

    // Karargahtan diğer binalara giden soluk yollar (köy meydanı hissi)
    private func yollar(_ W: CGFloat, _ H: CGFloat, _ d: DunyaView) -> some View {
        let hq = Self.yerlesim["karargah"] ?? (0.5, 0.16, 104)
        return Path { p in
            for b in d.buildings where b.tip != "karargah" {
                let t = Self.yerlesim[b.tip] ?? (0.5, 0.5, 84)
                p.move(to: CGPoint(x: W * hq.0, y: H * hq.1))
                p.addLine(to: CGPoint(x: W * t.0, y: H * t.1))
            }
        }
        .stroke(Theme.gold.opacity(0.10), style: StrokeStyle(lineWidth: 8, lineCap: .round))
    }

    private var altBar: some View {
        let d = online.dunya
        let idle = d?.idle ?? 0
        return HStack(spacing: 10) {
            // Haraç topla
            Button { Task { await online.dunyaTopla() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill").font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(idle > 0 ? "HARACI TOPLA" : "KASA BOŞ").font(.system(size: 13, weight: .black))
                        Text("₺\(fmt(idle))").font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 11)
                .background(idle > 0 ? Theme.blood : Theme.panelHi)
                .foregroundStyle(idle > 0 ? .white : Theme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(idle <= 0)
            // İşletmeler
            Button { isletmelerAcik = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "storefront.fill").font(.system(size: 18))
                    Text("İşletme").font(.system(size: 11, weight: .black))
                }
                .frame(width: 78).padding(.vertical, 10)
                .background(Theme.coal).foregroundStyle(Theme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
    }
}

/// Köy zemininde tek bina parseli — Flux görseli + seviye + inşaat durumu.
private struct KoyBinaTile: View {
    let bina: DBina
    let boyut: CGFloat
    let tap: () -> Void
    private var kuruldu: Bool { bina.seviye > 0 }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 3) {
                ZStack {
                    Image("bina_\(bina.tip)")
                        .resizable().scaledToFill()
                        .frame(width: boyut, height: boyut)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(halkaRenk, lineWidth: kuruldu ? 2 : 1))
                        .saturation(kuruldu ? 1 : 0.35)
                        .brightness(kuruldu ? 0 : -0.12)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
                    if !kuruldu {
                        Image(systemName: "plus.circle.fill").font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.92)).shadow(radius: 3)
                    }
                    // Seviye rozeti
                    if kuruldu {
                        Text("Sv.\(bina.seviye)")
                            .font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.7)))
                            .frame(maxWidth: boyut, maxHeight: boyut, alignment: .bottomLeading)
                            .padding(5)
                    }
                    // İnşaat geri sayım
                    if bina.insaatta {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.5))
                            VStack(spacing: 2) {
                                Image(systemName: "hammer.fill").font(.system(size: 18)).foregroundStyle(Theme.gold)
                                Text(sureMetni(bina.kalan)).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: boyut, height: boyut)
                    }
                }
                Text(LocalizedStringKey(OnlineKoyView.binaAd[bina.tip] ?? bina.tip))
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.coal.opacity(0.92)))
            }
        }
        .buttonStyle(.plain)
    }

    private var halkaRenk: Color {
        bina.insaatta ? Theme.gold : (kuruldu ? .white.opacity(0.15) : Theme.gold.opacity(0.5))
    }
}

/// Bina inşa/yükseltme sheet'i (online).
private struct OnlineBinaDetay: View {
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) private var dismiss
    let bina: DBina
    private var b: DBina { online.dunya?.buildings.first { $0.tip == bina.tip } ?? bina }

    var body: some View {
        let g = b
        let d = online.dunya
        let mesgul = d?.insaatMesgul ?? false
        let yeter = (d?.cash ?? 0) >= g.fiyat
        ScrollView {
            VStack(spacing: 14) {
                Image("bina_\(g.tip)").resizable().scaledToFill().frame(height: 190).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(LocalizedStringKey(OnlineKoyView.binaAd[g.tip] ?? g.tip))
                    .font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
                Text("Seviye \(g.seviye)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                Text(LocalizedStringKey(OnlineKoyView.binaAciklama[g.tip] ?? ""))
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)

                if g.insaatta {
                    Label("İnşaatta · \(sureMetni(g.kalan))", systemImage: "hammer.fill")
                        .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.gold)
                } else {
                    Button { Task { await online.dunyaBina(g.tip); dismiss() } } label: {
                        VStack(spacing: 2) {
                            Text(g.seviye == 0 ? "İNŞA ET · ₺\(fmt(g.fiyat))" : "YÜKSELT · ₺\(fmt(g.fiyat))")
                                .font(.system(size: 16, weight: .black))
                            Text(mesgul ? "Başka inşaat sürüyor" : "Süre \(sureMetni(g.sure))")
                                .font(.system(size: 11, weight: .semibold)).opacity(0.85)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(yeter && !mesgul ? Theme.blood : Theme.panelHi)
                        .foregroundStyle(yeter && !mesgul ? .white : Theme.smoke)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!yeter || mesgul)
                }
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium, .large])
    }
}

/// İşletmeler (haraç kaynakları) sheet'i.
private struct OnlineIsletmelerSheet: View {
    @EnvironmentObject var online: OnlineService
    @EnvironmentObject var tema: ThemeManager
    var body: some View {
        let d = online.dunya
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(d?.rackets ?? []) { r in
                        HStack(spacing: 12) {
                            Image(systemName: r.owned ? "storefront.fill" : "lock.fill").font(.system(size: 18))
                                .foregroundStyle(r.owned ? Theme.gold : Theme.smoke).frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(r.ad)).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                                Text(r.owned ? "Sv.\(r.tier) · dk/₺\(fmt(r.perMin))" : "dk/₺\(fmt(r.perMin)) üretir")
                                    .font(.system(size: 12)).foregroundStyle(r.owned ? Theme.gold : Theme.smoke)
                            }
                            Spacer()
                            Button { Task { await online.dunyaIsletme(r.idx) } } label: {
                                VStack(spacing: 1) {
                                    Text(r.owned ? "YÜKSELT" : "AL").font(.system(size: 11, weight: .black))
                                    Text("₺\(fmt(r.fiyat))").font(.system(size: 12, weight: .heavy, design: .rounded))
                                }
                                .foregroundStyle((d?.cash ?? 0) >= r.fiyat ? .white : Theme.smoke)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background((d?.cash ?? 0) >= r.fiyat ? Theme.bloodDim : Theme.panelHi)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }.disabled((d?.cash ?? 0) < r.fiyat)
                        }.cardStyle(12)
                    }
                }.padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("İşletmeler").navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(tema.colorScheme)
    }
}
