import SwiftUI
import CoreLocation
import MapboxMaps

/// FULL ONLINE karanlık (dark-noir) gerçek şehir haritası.
/// Sunucu-otoriter dünyadan gelen bölge/kaçak noktalarını Mapbox üzerinde pin'ler;
/// fetih aksiyonları /world/conquer uçlarına gider. Konum izni KULLANMAZ.
struct OnlineHaritaView: View {
    @EnvironmentObject var online: OnlineService
    @State private var seciliBolge: DBolge?
    @State private var seciliVaha: DVaha?

    /// Kurgu "Rajon şehri" merkezi (gerçek konum DEĞİL — sadece harita sahnesi).
    private static let sehirMerkezi = CLLocationCoordinate2D(latitude: 41.0411, longitude: 28.9784)

    // Sunucu idx → harita grid koordinatı (offline yerleşimle aynı düzen).
    private static let bolgeGrid: [(Int, Int)] = [(1, 1), (3, 0), (0, 3), (2, 3), (4, 2), (4, 4)]
    private static let vahaGrid:  [(Int, Int)] = [(2, 1), (0, 1), (3, 2), (1, 4), (4, 0), (3, 4)]
    static let bolgeGorsel = ["bolge_carsi", "bolge_liman", "bolge_yokus", "bolge_meydan", "bolge_sanayi", "bolge_kordon"]

    /// Grid koordinatını (hx,hy 0–4) kurgu enlem/boylama çevirir.
    static func koord(_ hx: Int, _ hy: Int) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: sehirMerkezi.latitude - Double(hy - 2) * 0.0105,
            longitude: sehirMerkezi.longitude + Double(hx - 2) * 0.0140)
    }

    var body: some View {
        VStack(spacing: 0) {
            ustBar
            Map(initialViewport: .camera(center: Self.sehirMerkezi, zoom: 12.4, bearing: 0, pitch: 38)) {
                if let d = online.dunya {
                    ForEvery(d.regions) { b in
                        MapViewAnnotation(coordinate: Self.koord(Self.gridB(b.idx).0, Self.gridB(b.idx).1)) {
                            OnlineBolgePin(bolge: b) { seciliBolge = b }
                        }
                        .allowOverlap(true)
                    }
                    ForEvery(d.oases) { v in
                        MapViewAnnotation(coordinate: Self.koord(Self.gridV(v.idx).0, Self.gridV(v.idx).1)) {
                            OnlineVahaPin(vaha: v) { seciliVaha = v }
                        }
                        .allowOverlap(true)
                    }
                }
            }
            .mapStyle(.dark)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(item: $seciliBolge) { b in OnlineBolgeDetay(bolge: b).environmentObject(online) }
        .sheet(item: $seciliVaha) { v in OnlineVahaDetay(vaha: v).environmentObject(online) }
    }

    private static func gridB(_ i: Int) -> (Int, Int) { i < bolgeGrid.count ? bolgeGrid[i] : (2, 2) }
    private static func gridV(_ i: Int) -> (Int, Int) { i < vahaGrid.count ? vahaGrid[i] : (2, 2) }

    private var ustBar: some View {
        let d = online.dunya
        let sahipB = d?.regions.filter { $0.owned }.count ?? 0
        let sahipV = d?.oases.filter { $0.owned }.count ?? 0
        return HStack(spacing: 14) {
            Label("\(sahipB) bölge · \(sahipV) nokta", systemImage: "map.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            Spacer()
            Label("Nüfuz \(d?.nufuzKullanim ?? 0)/\(d?.nufuzKapasite ?? 0)", systemImage: "crown.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle((d?.nufuzKullanim ?? 0) < (d?.nufuzKapasite ?? 0) ? Theme.gold : Theme.blood)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.coal)
    }
}

/// Bölge pini — gerçek semt görseli + durum halkası.
private struct OnlineBolgePin: View {
    let bolge: DBolge
    let tap: () -> Void
    private var gorsel: String { bolge.idx < OnlineHaritaView.bolgeGorsel.count ? OnlineHaritaView.bolgeGorsel[bolge.idx] : "bolge_carsi" }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                ZStack {
                    Image(gorsel).resizable().scaledToFill()
                        .frame(width: 46, height: 46).clipShape(Circle())
                        .overlay(Circle().stroke(halkaRenk, lineWidth: bolge.owned ? 3 : 1.5))
                        .saturation(bolge.owned ? 1 : 0.5)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    rozet
                }
                Text(LocalizedStringKey(bolge.ad)).font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
    }

    private var halkaRenk: Color {
        bolge.owned ? Theme.gold : (bolge.fetihte ? Theme.gold.opacity(0.6) : .white.opacity(0.2))
    }
    @ViewBuilder private var rozet: some View {
        if bolge.owned {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
                .background(Circle().fill(Theme.coal)).offset(x: 16, y: 16)
        } else if bolge.fetihte {
            Image(systemName: "flag.fill").font(.system(size: 14)).foregroundStyle(Theme.gold)
                .background(Circle().fill(Theme.coal)).offset(x: 16, y: 16)
        }
    }
}

/// Kaçak noktası (vaha) pini — görsel asset yok, tipine göre rozet.
private struct OnlineVahaPin: View {
    let vaha: DVaha
    let tap: () -> Void
    private var nakit: Bool { vaha.tip == "nakit" }
    private var ikon: String { nakit ? "dollarsign.circle.fill" : "shield.lefthalf.filled" }
    private var renk: Color { nakit ? Theme.gold : Theme.blood }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Theme.coal)
                        .frame(width: 38, height: 38)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(vaha.owned ? renk : .white.opacity(0.2), lineWidth: vaha.owned ? 3 : 1.5))
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                    Image(systemName: ikon).font(.system(size: 18, weight: .bold))
                        .foregroundStyle(vaha.owned ? renk : renk.opacity(0.6))
                    if vaha.owned {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.coal)).offset(x: 14, y: 14)
                    } else if vaha.fetihte {
                        Image(systemName: "flag.fill").font(.system(size: 12)).foregroundStyle(Theme.gold)
                            .background(Circle().fill(Theme.coal)).offset(x: 14, y: 14)
                    }
                }
                Text(LocalizedStringKey(vaha.ad)).font(.system(size: 9, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: Bölge detay sheet (online)
private struct OnlineBolgeDetay: View {
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) private var dismiss
    let bolge: DBolge
    /// Poll ile tazelenen güncel durumu yansıt.
    private var b: DBolge { online.dunya?.regions.first { $0.idx == bolge.idx } ?? bolge }
    private var gorsel: String { bolge.idx < OnlineHaritaView.bolgeGorsel.count ? OnlineHaritaView.bolgeGorsel[bolge.idx] : "bolge_carsi" }

    var body: some View {
        let g = b
        ScrollView {
            VStack(spacing: 14) {
                Image(gorsel).resizable().scaledToFill().frame(height: 200).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(LocalizedStringKey(g.ad)).font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                Text("Bölge · ele geçirince dk/₺\(fmt(g.gelirDk)) sürekli gelir")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                OnlineFetihButton(owned: g.owned, fetihte: g.fetihte, fiyat: g.fiyat,
                                  sure: g.sure, kalan: g.kalan) {
                    Task { await online.dunyaFethet("region", g.idx) }
                }
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium])
    }
}

// MARK: Vaha detay sheet (online)
private struct OnlineVahaDetay: View {
    @EnvironmentObject var online: OnlineService
    let vaha: DVaha
    private var v: DVaha { online.dunya?.oases.first { $0.idx == vaha.idx } ?? vaha }
    private var nakit: Bool { vaha.tip == "nakit" }

    var body: some View {
        let g = v
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.coal).frame(height: 200)
                    Image(systemName: nakit ? "dollarsign.circle.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(nakit ? Theme.gold : Theme.blood)
                }
                Text(LocalizedStringKey(g.ad)).font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                Text("Kaçak noktası · ele geçirince dk +\(fmt(g.bonusDk)) \(nakit ? "nakit" : "cephane") üretir")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
                OnlineFetihButton(owned: g.owned, fetihte: g.fetihte, fiyat: g.fiyat,
                                  sure: g.sure, kalan: g.kalan) {
                    Task { await online.dunyaFethet("oasis", g.idx) }
                }
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium])
    }
}

/// Online fetih butonu — sunucu durumuna göre (sahip / fetihte+geri sayım / ele geçir).
private struct OnlineFetihButton: View {
    @EnvironmentObject var online: OnlineService
    let owned: Bool
    let fetihte: Bool
    let fiyat: Int
    let sure: Int
    let kalan: Int
    let eylem: () -> Void

    var body: some View {
        if owned {
            Label("Ele geçirildi — senin", systemImage: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.gold)
        } else if fetihte {
            Label("Fethediliyor · \(sureMetni(kalan))", systemImage: "flag.fill")
                .font(.system(size: 16, weight: .black)).foregroundStyle(Theme.gold)
        } else {
            let cash = online.dunya?.cash ?? 0
            let nufuzVar = (online.dunya?.nufuzKullanim ?? 0) < (online.dunya?.nufuzKapasite ?? 0)
            let yeter = cash >= fiyat
            Button { eylem() } label: {
                VStack(spacing: 2) {
                    Text("ELE GEÇİR · ₺\(fmt(fiyat))").font(.system(size: 16, weight: .black))
                    Text(nufuzVar ? "Süre \(sureMetni(sure))" : "Nüfuz yetersiz — Karargah yükselt")
                        .font(.system(size: 11, weight: .semibold)).opacity(0.85)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(yeter && nufuzVar ? Theme.blood : Theme.panelHi)
                .foregroundStyle(yeter && nufuzVar ? .white : Theme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!yeter || !nufuzVar)
        }
    }
}
