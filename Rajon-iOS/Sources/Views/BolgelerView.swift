import SwiftUI

/// Şehir — çoklu bölge ele geçirme (Travian çoklu köy karşılığı).
struct BolgelerView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                baslik
                if let b = game.fetihtekiBolge { fetihKuyrugu(b) }
                ForEach(game.bolgeler) { bolge in
                    BolgeKart(bolge: bolge)
                }
            }
            .padding(16)
        }
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ŞEHİR").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                Spacer()
                Text("\(game.eleGecirilen)/\(game.bolgeler.count) bölge · dk/₺\(fmt(game.bolgeGeliriDk))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            }
            Text("Mahalleleri tek tek ele geçir. Her bölge sürekli gelir getirir. Karargah fethi hızlandırır.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fetihKuyrugu(_ b: Bolge) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let kalan = max(0, Int(b.fetihBitis?.timeIntervalSinceNow ?? 0))
            HStack(spacing: 12) {
                Image(systemName: "flag.fill").foregroundStyle(Theme.gold)
                Text("FETHEDİLİYOR: \(b.ad)").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                Spacer()
                Text(sureMetni(kalan)).font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.gold)
            }
            .cardStyle(14)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
        }
    }
}

struct BolgeKart: View {
    @EnvironmentObject var game: GameStore
    let bolge: Bolge

    private var guncel: Bolge { game.bolgeler.first { $0.id == bolge.id } ?? bolge }

    var body: some View {
        let b = guncel
        let yeter = game.cash >= b.maliyet
        return ZStack(alignment: .bottomLeading) {
            Image(b.gorsel).resizable().scaledToFill()
                .frame(height: 150).frame(maxWidth: .infinity)
                .clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom))
                .saturation(b.eleGecirildi ? 1 : 0.7)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(b.ad).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                    if b.eleGecirildi {
                        Label("dk / ₺\(fmt(b.gelirDk))", systemImage: "dollarsign.circle.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.gold)
                    } else {
                        Text("Gelir: dk/₺\(fmt(b.gelirDk)) · Süre \(sureMetni(Int(b.sure)))")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.smoke)
                    }
                }
                Spacer()
                if b.eleGecirildi {
                    Label("SENİN", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .black)).foregroundStyle(Theme.gold)
                } else if b.fetihte {
                    Text("FETHEDİLİYOR").font(.system(size: 11, weight: .black)).foregroundStyle(Theme.gold)
                } else {
                    Button { game.bolgeFethet(b.id) } label: {
                        VStack(spacing: 0) {
                            Text("ELE GEÇİR").font(.system(size: 12, weight: .black))
                            Text("₺\(fmt(b.maliyet))").font(.system(size: 12, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(yeter && !game.fetihMesgul ? .white : Theme.smoke)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(yeter && !game.fetihMesgul ? Theme.blood : Theme.panelHi)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!yeter || game.fetihMesgul)
                }
            }
            .padding(14)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(b.eleGecirildi ? Theme.gold.opacity(0.5) : .white.opacity(0.08), lineWidth: 1))
    }
}
