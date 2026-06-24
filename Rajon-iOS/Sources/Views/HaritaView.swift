import SwiftUI
import CoreLocation
import MapboxMaps

/// Gerçek şehir haritası (Mapbox · dark-noir) — bölge ve kaçak noktaları gerçek koordinatta pin.
/// Konum izni KULLANMAZ; sabit bir kurgu şehir merkezine kameralanır.
struct HaritaView: View {
    @EnvironmentObject var game: GameStore
    @State private var seciliBolge: Bolge?
    @State private var seciliVaha: Vaha?

    /// Kurgu "Rajon şehri" merkezi (gerçek konum DEĞİL — sadece harita sahnesi).
    private static let sehirMerkezi = CLLocationCoordinate2D(latitude: 41.0411, longitude: 28.9784)

    /// Grid koordinatını (hx,hy 0–4) gerçek enlem/boylama çevirir; ızgarayı şehir merkezine yayar.
    static func koord(_ hx: Int, _ hy: Int) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: sehirMerkezi.latitude - Double(hy - 2) * 0.0105,
            longitude: sehirMerkezi.longitude + Double(hx - 2) * 0.0140)
    }

    var body: some View {
        VStack(spacing: 0) {
            ustBar
            Map(initialViewport: .camera(center: Self.sehirMerkezi, zoom: 12.4, bearing: 0, pitch: 38)) {
                ForEach(game.bolgeler) { b in
                    MapViewAnnotation(coordinate: Self.koord(b.hx, b.hy)) {
                        BolgePin(bolge: b) { seciliBolge = b }
                    }
                    .allowOverlap(true)
                }
                ForEach(game.vahalar) { v in
                    MapViewAnnotation(coordinate: Self.koord(v.hx, v.hy)) {
                        VahaPin(vaha: v) { seciliVaha = v }
                    }
                    .allowOverlap(true)
                }
            }
            .mapStyle(.dark)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(item: $seciliBolge) { b in BolgeDetay(bolge: b).environmentObject(game) }
        .sheet(item: $seciliVaha) { v in VahaDetay(vaha: v).environmentObject(game) }
    }

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
}

/// Harita üzerinde bölge pini — gerçek görsel + durum halkası.
private struct BolgePin: View {
    let bolge: Bolge
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                ZStack {
                    Image(bolge.gorsel).resizable().scaledToFill()
                        .frame(width: 46, height: 46).clipShape(Circle())
                        .overlay(Circle().stroke(halkaRenk, lineWidth: bolge.eleGecirildi ? 3 : 1.5))
                        .saturation(bolge.eleGecirildi ? 1 : 0.5)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    rozet
                }
                Text(bolge.ad).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
    }

    private var halkaRenk: Color {
        bolge.eleGecirildi ? Theme.gold : (bolge.fetihte ? Theme.gold.opacity(0.6) : .white.opacity(0.2))
    }
    @ViewBuilder private var rozet: some View {
        if bolge.eleGecirildi {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
                .background(Circle().fill(Theme.coal)).offset(x: 16, y: 16)
        } else if bolge.fetihte {
            Image(systemName: "flag.fill").font(.system(size: 14)).foregroundStyle(Theme.gold)
                .background(Circle().fill(Theme.coal)).offset(x: 16, y: 16)
        }
    }
}

/// Harita üzerinde kaçak noktası (vaha) pini.
private struct VahaPin: View {
    let vaha: Vaha
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                ZStack {
                    Image(vaha.gorsel).resizable().scaledToFill()
                        .frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(halkaRenk, lineWidth: vaha.eleGecirildi ? 3 : 1.5))
                        .saturation(vaha.eleGecirildi ? 1 : 0.5)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    if vaha.eleGecirildi {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.coal)).offset(x: 14, y: 14)
                    } else if vaha.fetihte {
                        Image(systemName: "flag.fill").font(.system(size: 12)).foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.coal)).offset(x: 14, y: 14)
                    }
                }
                Text(vaha.ad).font(.system(size: 9, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
    }

    private var halkaRenk: Color {
        vaha.eleGecirildi ? (vaha.tip == .nakit ? Theme.gold : Theme.blood) : .white.opacity(0.2)
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
