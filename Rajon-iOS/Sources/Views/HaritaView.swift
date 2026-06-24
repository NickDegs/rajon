import SwiftUI

/// Kaydırılabilir şehir haritası — bölgeler + vahalar koordinatta düğüm. Travian dünya haritası karşılığı.
struct HaritaView: View {
    @EnvironmentObject var game: GameStore
    @State private var seciliBolge: Bolge?
    @State private var seciliVaha: Vaha?

    private let hucre: CGFloat = 168
    private let gridN = 5

    var body: some View {
        VStack(spacing: 0) {
            ustBar
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    izgara
                    ForEach(game.bolgeler) { b in
                        nodeBolge(b).position(x: merkez(b.hx), y: merkez(b.hy))
                    }
                    ForEach(game.vahalar) { v in
                        nodeVaha(v).position(x: merkez(v.hx), y: merkez(v.hy))
                    }
                }
                .frame(width: hucre * CGFloat(gridN), height: hucre * CGFloat(gridN))
                .padding(20)
            }
            .background(Theme.coal)
        }
        .sheet(item: $seciliBolge) { b in BolgeDetay(bolge: b).environmentObject(game) }
        .sheet(item: $seciliVaha) { v in VahaDetay(vaha: v).environmentObject(game) }
    }

    private func merkez(_ i: Int) -> CGFloat { CGFloat(i) * hucre + hucre / 2 }

    private var ustBar: some View {
        HStack(spacing: 14) {
            Label("\(game.eleGecirilen) bölge · \(game.eleGecirilenVaha) vaha", systemImage: "map.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            Spacer()
            Label("Nüfuz \(game.nufuzKullanim)/\(game.nufuzKapasite)", systemImage: "crown.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(game.nufuzVarMi ? Theme.gold : Theme.blood)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.coal)
    }

    private var izgara: some View {
        Path { p in
            let s = hucre * CGFloat(gridN)
            for i in 0...gridN {
                let o = CGFloat(i) * hucre
                p.move(to: .init(x: o, y: 0)); p.addLine(to: .init(x: o, y: s))
                p.move(to: .init(x: 0, y: o)); p.addLine(to: .init(x: s, y: o))
            }
        }
        .stroke(Color.white.opacity(0.05), lineWidth: 1)
        .frame(width: hucre * CGFloat(gridN), height: hucre * CGFloat(gridN))
    }

    private func nodeBolge(_ b: Bolge) -> some View {
        Button { seciliBolge = b } label: {
            VStack(spacing: 3) {
                ZStack {
                    Image(b.gorsel).resizable().scaledToFill()
                        .frame(width: 120, height: 96).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(b.eleGecirildi ? Theme.gold : (b.fetihte ? Theme.gold.opacity(0.6) : .white.opacity(0.12)), lineWidth: b.eleGecirildi ? 3 : 1.5))
                        .saturation(b.eleGecirildi ? 1 : 0.65)
                    durumIsareti(b.eleGecirildi, b.fetihte)
                }
                Text(b.ad).font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                Text(b.eleGecirildi ? "dk/₺\(fmt(b.gelirDk))" : "₺\(fmt(b.maliyet))")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(b.eleGecirildi ? Theme.gold : Theme.smoke)
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeVaha(_ v: Vaha) -> some View {
        Button { seciliVaha = v } label: {
            VStack(spacing: 3) {
                ZStack {
                    Image(v.gorsel).resizable().scaledToFill()
                        .frame(width: 96, height: 78).clipShape(Circle())
                        .overlay(Circle().stroke(v.eleGecirildi ? (v.tip == .nakit ? Theme.gold : Theme.blood) : .white.opacity(0.12), lineWidth: v.eleGecirildi ? 3 : 1.5))
                        .saturation(v.eleGecirildi ? 1 : 0.6)
                    durumIsareti(v.eleGecirildi, v.fetihte)
                }
                Text(v.ad).font(.system(size: 10, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Text(v.eleGecirildi ? "+\(fmt(v.bonusDk)) \(v.tip.ad)" : "₺\(fmt(v.maliyet))")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(v.eleGecirildi ? Theme.gold : Theme.smoke)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func durumIsareti(_ alindi: Bool, _ fetihte: Bool) -> some View {
        if alindi { Image(systemName: "checkmark.seal.fill").font(.system(size: 22)).foregroundStyle(Theme.gold).shadow(radius: 3) }
        else if fetihte { Image(systemName: "flag.fill").font(.system(size: 20)).foregroundStyle(Theme.gold) }
        else { Image(systemName: "flag.slash").font(.system(size: 18)).foregroundStyle(.white.opacity(0.7)) }
    }
}

// MARK: Bölge detay sheet
struct BolgeDetay: View {
    @EnvironmentObject var game: GameStore
    @Environment(\.dismiss) private var dismiss
    let bolge: Bolge
    private var g: Bolge { game.bolgeler.first { $0.id == bolge.id } ?? bolge }

    var body: some View {
        let b = g
        ScrollView {
            VStack(spacing: 14) {
                Image(b.gorsel).resizable().scaledToFill().frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(b.ad).font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                Text("Bölge · ele geçirince dk/₺\(fmt(b.gelirDk)) sürekli gelir")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                FetihButton(alindi: b.eleGecirildi, fetihte: b.fetihte, fiyat: b.maliyet,
                            sure: b.sure * game.insaatHizCarpani,
                            bitis: b.fetihBitis) { game.bolgeFethet(b.id) }
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium])
    }
}

// MARK: Vaha detay sheet
struct VahaDetay: View {
    @EnvironmentObject var game: GameStore
    let vaha: Vaha
    private var g: Vaha { game.vahalar.first { $0.id == vaha.id } ?? vaha }

    var body: some View {
        let v = g
        ScrollView {
            VStack(spacing: 14) {
                Image(v.gorsel).resizable().scaledToFill().frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(v.ad).font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                Text("Kaçak noktası · ele geçirince dk +\(fmt(v.bonusDk)) \(v.tip.ad) üretir")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
                FetihButton(alindi: v.eleGecirildi, fetihte: v.fetihte, fiyat: v.maliyet,
                            sure: v.sure * game.insaatHizCarpani, bitis: v.fetihBitis) { game.vahaFethet(v.id) }
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium])
    }
}

/// Ortak fetih butonu (bölge/vaha). View struct → @MainActor, game'e güvenle erişir.
struct FetihButton: View {
    @EnvironmentObject var game: GameStore
    let alindi: Bool
    let fetihte: Bool
    let fiyat: Int
    let sure: Double
    let bitis: Date?
    let eylem: () -> Void

    var body: some View {
        if alindi {
            Label("Ele geçirildi — senin", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.gold)
        } else if fetihte {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let kalan = max(0, Int(bitis?.timeIntervalSinceNow ?? 0))
                Label("Fethediliyor · \(sureMetni(kalan))", systemImage: "flag.fill")
                    .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.gold)
            }
        } else {
            let yeter = game.cash >= fiyat
            let engel = game.fetihMesgul || !game.nufuzVarMi
            Button { eylem() } label: {
                VStack(spacing: 2) {
                    Text("ELE GEÇİR · ₺\(fmt(fiyat))").font(.system(size: 16, weight: .black))
                    Text(game.nufuzVarMi ? "Süre \(sureMetni(Int(sure)))" : "Nüfuz yetersiz — Karargah yükselt")
                        .font(.system(size: 11, weight: .semibold)).opacity(0.85)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(yeter && !engel ? Theme.blood : Theme.panelHi)
                .foregroundStyle(yeter && !engel ? .white : Theme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!yeter || engel)
        }
    }
}
