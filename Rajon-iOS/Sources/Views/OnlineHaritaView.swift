import SwiftUI
import CoreLocation
import MapboxMaps

/// FULL ONLINE karanlık (dark-noir) gerçek şehir haritası — PAYLAŞILAN DÜNYA.
/// Sunucudan gelen GERÇEK oyuncuların üsleri tüm metropole yayılır (id'den deterministik
/// koordinat), kendi bölge/kaçak noktaların merkez "bölgende" durur. Düşmana basınca baskın.
/// fetih → /world/conquer, baskın → /world/attack. Konum izni KULLANMAZ.
struct OnlineHaritaView: View {
    @EnvironmentObject var online: OnlineService
    @State private var seciliBolge: DBolge?
    @State private var seciliVaha: DVaha?
    @State private var seciliDusman: LiderSatir?

    /// Oyuncu id'si gelene kadar düşülecek varsayılan merkez.
    static let sehirMerkezi = CLLocationCoordinate2D(latitude: 41.0411, longitude: 28.9784)

    /// TÜM DÜNYA — 239 gerçek metropol; üsler id-hash → şehir + sapma ile buralara dağılır.
    static let dunyaSehirleri: [CLLocationCoordinate2D] = [
        .init(latitude: 41.01, longitude: 28.98), .init(latitude: 39.93, longitude: 32.86), .init(latitude: 38.42, longitude: 27.14),
        .init(latitude: 40.19, longitude: 29.06), .init(latitude: 36.90, longitude: 30.69), .init(latitude: 37.00, longitude: 35.32),
        .init(latitude: 37.87, longitude: 32.49), .init(latitude: 37.07, longitude: 37.38), .init(latitude: 36.81, longitude: 34.63),
        .init(latitude: 38.73, longitude: 35.49), .init(latitude: 37.91, longitude: 40.24), .init(latitude: 41.00, longitude: 39.72),
        .init(latitude: 41.29, longitude: 36.33), .init(latitude: 39.78, longitude: 30.52), .init(latitude: 37.17, longitude: 38.79),
        .init(latitude: 39.90, longitude: 41.27), .init(latitude: 38.49, longitude: 43.41), .init(latitude: 38.35, longitude: 38.31),
        .init(latitude: 37.78, longitude: 29.09), .init(latitude: 36.20, longitude: 36.16), .init(latitude: 51.50, longitude: -0.13),
        .init(latitude: 48.85, longitude: 2.35), .init(latitude: 52.52, longitude: 13.40), .init(latitude: 40.42, longitude: -3.70),
        .init(latitude: 41.90, longitude: 12.50), .init(latitude: 52.37, longitude: 4.90), .init(latitude: 48.21, longitude: 16.37),
        .init(latitude: 37.98, longitude: 23.73), .init(latitude: 38.72, longitude: -9.14), .init(latitude: 59.33, longitude: 18.07),
        .init(latitude: 59.91, longitude: 10.75), .init(latitude: 60.17, longitude: 24.94), .init(latitude: 55.68, longitude: 12.57),
        .init(latitude: 53.35, longitude: -6.26), .init(latitude: 50.85, longitude: 4.35), .init(latitude: 47.37, longitude: 8.54),
        .init(latitude: 45.46, longitude: 9.19), .init(latitude: 41.39, longitude: 2.17), .init(latitude: 48.14, longitude: 11.58),
        .init(latitude: 50.08, longitude: 14.44), .init(latitude: 47.50, longitude: 19.04), .init(latitude: 52.23, longitude: 21.01),
        .init(latitude: 44.43, longitude: 26.10), .init(latitude: 50.45, longitude: 30.52), .init(latitude: 55.75, longitude: 37.62),
        .init(latitude: 59.93, longitude: 30.34), .init(latitude: 44.79, longitude: 20.45), .init(latitude: 42.70, longitude: 23.32),
        .init(latitude: 45.81, longitude: 15.98), .init(latitude: 43.86, longitude: 18.41), .init(latitude: 41.99, longitude: 21.43),
        .init(latitude: 41.33, longitude: 19.82), .init(latitude: 41.15, longitude: -8.61), .init(latitude: 40.85, longitude: 14.27),
        .init(latitude: 43.30, longitude: 5.37), .init(latitude: 45.76, longitude: 4.84), .init(latitude: 53.55, longitude: 9.99),
        .init(latitude: 50.11, longitude: 8.68), .init(latitude: 50.94, longitude: 6.96), .init(latitude: 51.92, longitude: 4.48),
        .init(latitude: 46.20, longitude: 6.14), .init(latitude: 55.86, longitude: -4.25), .init(latitude: 53.48, longitude: -2.24),
        .init(latitude: 52.49, longitude: -1.89), .init(latitude: 55.95, longitude: -3.19), .init(latitude: 39.47, longitude: -0.38),
        .init(latitude: 37.39, longitude: -5.99), .init(latitude: 50.06, longitude: 19.94), .init(latitude: 54.35, longitude: 18.65),
        .init(latitude: 53.90, longitude: 27.57), .init(latitude: 54.69, longitude: 25.28), .init(latitude: 56.95, longitude: 24.11),
        .init(latitude: 59.44, longitude: 24.75), .init(latitude: 64.15, longitude: -21.94), .init(latitude: 49.61, longitude: 6.13),
        .init(latitude: 40.64, longitude: 22.94), .init(latitude: 51.22, longitude: 4.40), .init(latitude: 48.78, longitude: 9.18),
        .init(latitude: 25.20, longitude: 55.27), .init(latitude: 24.45, longitude: 54.38), .init(latitude: 24.71, longitude: 46.68),
        .init(latitude: 21.49, longitude: 39.18), .init(latitude: 25.29, longitude: 51.53), .init(latitude: 29.38, longitude: 47.99),
        .init(latitude: 26.23, longitude: 50.59), .init(latitude: 23.59, longitude: 58.41), .init(latitude: 35.69, longitude: 51.39),
        .init(latitude: 33.31, longitude: 44.36), .init(latitude: 30.51, longitude: 47.78), .init(latitude: 36.19, longitude: 44.01),
        .init(latitude: 33.51, longitude: 36.29), .init(latitude: 36.20, longitude: 37.16), .init(latitude: 33.89, longitude: 35.50),
        .init(latitude: 31.95, longitude: 35.93), .init(latitude: 31.77, longitude: 35.21), .init(latitude: 32.08, longitude: 34.78),
        .init(latitude: 31.50, longitude: 34.47), .init(latitude: 15.37, longitude: 44.19), .init(latitude: 40.41, longitude: 49.87),
        .init(latitude: 41.72, longitude: 44.79), .init(latitude: 40.18, longitude: 44.51), .init(latitude: 41.30, longitude: 69.24),
        .init(latitude: 43.24, longitude: 76.89), .init(latitude: 51.16, longitude: 71.43), .init(latitude: 42.87, longitude: 74.59),
        .init(latitude: 38.56, longitude: 68.79), .init(latitude: 37.96, longitude: 58.33), .init(latitude: 34.53, longitude: 69.17),
        .init(latitude: 39.65, longitude: 66.96), .init(latitude: 19.08, longitude: 72.88), .init(latitude: 28.61, longitude: 77.21),
        .init(latitude: 12.97, longitude: 77.59), .init(latitude: 22.57, longitude: 88.36), .init(latitude: 13.08, longitude: 80.27),
        .init(latitude: 17.39, longitude: 78.49), .init(latitude: 24.86, longitude: 67.01), .init(latitude: 31.55, longitude: 74.34),
        .init(latitude: 33.69, longitude: 73.06), .init(latitude: 23.81, longitude: 90.41), .init(latitude: 6.93, longitude: 79.86),
        .init(latitude: 27.72, longitude: 85.32), .init(latitude: 23.03, longitude: 72.58), .init(latitude: 18.52, longitude: 73.86),
        .init(latitude: 26.91, longitude: 75.79), .init(latitude: 35.68, longitude: 139.69), .init(latitude: 34.69, longitude: 135.50),
        .init(latitude: 35.18, longitude: 136.91), .init(latitude: 37.57, longitude: 126.98), .init(latitude: 35.18, longitude: 129.08),
        .init(latitude: 39.90, longitude: 116.40), .init(latitude: 31.23, longitude: 121.47), .init(latitude: 23.13, longitude: 113.26),
        .init(latitude: 22.54, longitude: 114.06), .init(latitude: 30.57, longitude: 104.07), .init(latitude: 22.32, longitude: 114.17),
        .init(latitude: 25.03, longitude: 121.57), .init(latitude: 13.76, longitude: 100.50), .init(latitude: 1.35, longitude: 103.82),
        .init(latitude: -6.21, longitude: 106.85), .init(latitude: -7.25, longitude: 112.75), .init(latitude: 3.14, longitude: 101.69),
        .init(latitude: 14.60, longitude: 120.98), .init(latitude: 10.82, longitude: 106.63), .init(latitude: 21.03, longitude: 105.85),
        .init(latitude: 11.56, longitude: 104.92), .init(latitude: 16.87, longitude: 96.20), .init(latitude: 17.97, longitude: 102.60),
        .init(latitude: 47.89, longitude: 106.91), .init(latitude: 30.04, longitude: 31.24), .init(latitude: 31.20, longitude: 29.92),
        .init(latitude: 6.52, longitude: 3.37), .init(latitude: 9.07, longitude: 7.40), .init(latitude: 12.00, longitude: 8.52),
        .init(latitude: -1.29, longitude: 36.82), .init(latitude: -4.04, longitude: 39.67), .init(latitude: 9.03, longitude: 38.74),
        .init(latitude: -26.20, longitude: 28.05), .init(latitude: -33.92, longitude: 18.42), .init(latitude: -29.86, longitude: 31.02),
        .init(latitude: 33.57, longitude: -7.59), .init(latitude: 34.02, longitude: -6.83), .init(latitude: 31.63, longitude: -7.99),
        .init(latitude: 36.75, longitude: 3.06), .init(latitude: 36.81, longitude: 10.18), .init(latitude: 32.89, longitude: 13.19),
        .init(latitude: 5.60, longitude: -0.19), .init(latitude: 14.69, longitude: -17.44), .init(latitude: 5.36, longitude: -4.01),
        .init(latitude: -4.32, longitude: 15.31), .init(latitude: -8.84, longitude: 13.23), .init(latitude: 15.50, longitude: 32.56),
        .init(latitude: -6.79, longitude: 39.21), .init(latitude: 0.35, longitude: 32.58), .init(latitude: -25.97, longitude: 32.57),
        .init(latitude: -17.83, longitude: 31.05), .init(latitude: -15.42, longitude: 28.28), .init(latitude: 12.64, longitude: -8.00),
        .init(latitude: 12.37, longitude: -1.52), .init(latitude: 2.05, longitude: 45.32), .init(latitude: 40.71, longitude: -74.00),
        .init(latitude: 34.05, longitude: -118.24), .init(latitude: 41.88, longitude: -87.63), .init(latitude: 29.76, longitude: -95.37),
        .init(latitude: 33.45, longitude: -112.07), .init(latitude: 39.95, longitude: -75.17), .init(latitude: 29.42, longitude: -98.49),
        .init(latitude: 32.78, longitude: -96.80), .init(latitude: 25.76, longitude: -80.19), .init(latitude: 33.75, longitude: -84.39),
        .init(latitude: 42.36, longitude: -71.06), .init(latitude: 37.77, longitude: -122.42), .init(latitude: 47.61, longitude: -122.33),
        .init(latitude: 42.33, longitude: -83.05), .init(latitude: 38.91, longitude: -77.04), .init(latitude: 36.17, longitude: -115.14),
        .init(latitude: 39.74, longitude: -104.99), .init(latitude: 43.65, longitude: -79.38), .init(latitude: 45.50, longitude: -73.57),
        .init(latitude: 49.28, longitude: -123.12), .init(latitude: 19.43, longitude: -99.13), .init(latitude: 20.66, longitude: -103.35),
        .init(latitude: 25.69, longitude: -100.32), .init(latitude: 32.51, longitude: -117.04), .init(latitude: 23.11, longitude: -82.37),
        .init(latitude: 18.49, longitude: -69.93), .init(latitude: 14.63, longitude: -90.51), .init(latitude: 18.47, longitude: -66.10),
        .init(latitude: 17.97, longitude: -76.79), .init(latitude: 8.98, longitude: -79.52), .init(latitude: -23.55, longitude: -46.63),
        .init(latitude: -22.91, longitude: -43.17), .init(latitude: -15.79, longitude: -47.88), .init(latitude: -12.97, longitude: -38.50),
        .init(latitude: -3.73, longitude: -38.52), .init(latitude: -34.60, longitude: -58.38), .init(latitude: -31.42, longitude: -64.18),
        .init(latitude: -33.45, longitude: -70.67), .init(latitude: -12.05, longitude: -77.04), .init(latitude: 4.71, longitude: -74.07),
        .init(latitude: 6.24, longitude: -75.58), .init(latitude: 3.45, longitude: -76.53), .init(latitude: 10.48, longitude: -66.90),
        .init(latitude: -0.18, longitude: -78.47), .init(latitude: -2.19, longitude: -79.89), .init(latitude: -16.50, longitude: -68.15),
        .init(latitude: -34.90, longitude: -56.16), .init(latitude: -25.28, longitude: -57.63), .init(latitude: -8.05, longitude: -34.88),
        .init(latitude: -30.03, longitude: -51.23), .init(latitude: -33.87, longitude: 151.21), .init(latitude: -37.81, longitude: 144.96),
        .init(latitude: -27.47, longitude: 153.03), .init(latitude: -31.95, longitude: 115.86), .init(latitude: -36.85, longitude: 174.76),
        .init(latitude: -41.29, longitude: 174.78), .init(latitude: -34.93, longitude: 138.60), .init(latitude: -9.44, longitude: 147.18),
        .init(latitude: -18.14, longitude: 178.44), .init(latitude: 21.31, longitude: -157.86),
    ]

    // Sunucu idx → kendi bölgen ev merkezinin etrafında grid.
    private static let bolgeGrid: [(Int, Int)] = [(1, 1), (3, 0), (0, 3), (2, 3), (4, 2), (4, 4)]
    private static let vahaGrid:  [(Int, Int)] = [(2, 1), (0, 1), (3, 2), (1, 4), (4, 0), (3, 4)]
    static let bolgeGorsel = ["bolge_carsi", "bolge_liman", "bolge_yokus", "bolge_meydan", "bolge_sanayi", "bolge_kordon"]

    /// Oyuncu id'sinden DETERMİNİSTİK dünya koordinatı (her oyuncu hep aynı şehirde).
    static func dusmanKoord(_ id: String) -> CLLocationCoordinate2D {
        var h: UInt64 = 0xcbf29ce484222325
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        let sehir = dunyaSehirleri[Int(h % UInt64(dunyaSehirleri.count))]
        // Avalanche (splitmix64) — sıralı id'lerde bile sapma çeşitlensin (üst üste binmesin).
        var z = h
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        let jLat = (Double((z >> 21) & 0x7ff) / 2047.0 - 0.5) * 1.1   // ±0.55°
        let jLon = (Double((z >> 42) & 0x7ff) / 2047.0 - 0.5) * 1.1
        return CLLocationCoordinate2D(latitude: sehir.latitude + jLat,
                                      longitude: sehir.longitude + jLon)
    }

    /// Oyuncunun harita koordinatı: önce sunucudan gelen gerçek şehir, yoksa yerel hash.
    static func koordFor(_ p: LiderSatir) -> CLLocationCoordinate2D {
        if let la = p.lat, let lo = p.lon, !(la == 0 && lo == 0) {
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }
        return dusmanKoord(p.id)
    }

    /// Kendi üssünün dünya merkezi (sunucu koordinatı; yoksa id-hash; yoksa varsayılan).
    private var evMerkezi: CLLocationCoordinate2D {
        if let la = online.me?.lat, let lo = online.me?.lon, !(la == 0 && lo == 0) {
            return CLLocationCoordinate2D(latitude: la, longitude: lo)
        }
        if let id = online.me?.id { return Self.dusmanKoord(id) }
        return Self.sehirMerkezi
    }

    /// Kendi bölge/vahanı ev merkezinin etrafına kümele (yakınlaşınca görünür).
    private func koord(_ hx: Int, _ hy: Int) -> CLLocationCoordinate2D {
        let c = evMerkezi
        return CLLocationCoordinate2D(
            latitude: c.latitude - Double(hy - 2) * 0.0140,
            longitude: c.longitude + Double(hx - 2) * 0.0185)
    }

    var body: some View {
        VStack(spacing: 0) {
            ustBar
            Map(initialViewport: .camera(center: evMerkezi, zoom: 1.7, bearing: 0, pitch: 0)) {
                // Kendi merkez üssün (dünyadaki gerçek şehrin)
                MapViewAnnotation(coordinate: evMerkezi) { EvimPin() }.allowOverlap(true)

                if let d = online.dunya {
                    ForEvery(d.regions) { b in
                        MapViewAnnotation(coordinate: koord(Self.gridB(b.idx).0, Self.gridB(b.idx).1)) {
                            OnlineBolgePin(bolge: b) { seciliBolge = b }
                        }
                        .allowOverlap(true)
                    }
                    ForEvery(d.oases) { v in
                        MapViewAnnotation(coordinate: koord(Self.gridV(v.idx).0, Self.gridV(v.idx).1)) {
                            OnlineVahaPin(vaha: v) { seciliVaha = v }
                        }
                        .allowOverlap(true)
                    }
                }
                // Diğer GERÇEK oyuncular — tüm dünyaya yayılı
                ForEvery(online.dunyaOyuncular) { p in
                    MapViewAnnotation(coordinate: Self.koordFor(p)) {
                        OnlineDusmanPin(oyuncu: p) { seciliDusman = p }
                    }
                    .allowOverlap(true)
                }
            }
            .mapStyle(.dark)
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            // Dünya haritasını (oyuncuları) çek ve görünür kaldıkça tazele.
            await online.dunyaHaritasi()
            while true {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                await online.dunyaHaritasi()
            }
        }
        .sheet(item: $seciliBolge) { b in OnlineBolgeDetay(bolge: b).environmentObject(online) }
        .sheet(item: $seciliVaha) { v in OnlineVahaDetay(vaha: v).environmentObject(online) }
        .sheet(item: $seciliDusman) { p in OnlineDusmanDetay(oyuncu: p).environmentObject(online) }
    }

    private static func gridB(_ i: Int) -> (Int, Int) { i < bolgeGrid.count ? bolgeGrid[i] : (2, 2) }
    private static func gridV(_ i: Int) -> (Int, Int) { i < vahaGrid.count ? vahaGrid[i] : (2, 2) }

    private var ustBar: some View {
        let d = online.dunya
        let sahipB = d?.regions.filter { $0.owned }.count ?? 0
        let sahipV = d?.oases.filter { $0.owned }.count ?? 0
        let rakip = online.dunyaOyuncular.count
        return HStack(spacing: 12) {
            Label("\(sahipB) bölge · \(sahipV) nokta", systemImage: "map.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
            Label("\(rakip) patron", systemImage: "person.2.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke)
            Spacer()
            Label("Nüfuz \(d?.nufuzKullanim ?? 0)/\(d?.nufuzKapasite ?? 0)", systemImage: "crown.fill")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle((d?.nufuzKullanim ?? 0) < (d?.nufuzKapasite ?? 0) ? Theme.gold : Theme.blood)
        }
        .padding(.horizontal, 16).padding(.vertical, 10).background(Theme.coal)
    }
}

/// Kendi merkez üssün — "burası senin bölgen" işareti.
private struct EvimPin: View {
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(Theme.blood).frame(width: 30, height: 30)
                    .overlay(Circle().stroke(Theme.gold, lineWidth: 2.5))
                    .shadow(color: Theme.blood.opacity(0.7), radius: 8)
                Image(systemName: "crown.fill").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
            }
            Text("ÜSSÜN").font(.system(size: 9, weight: .black)).foregroundStyle(Theme.gold)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Theme.coal.opacity(0.9)))
        }
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
                Text(LocalizedStringKey(bolge.ad)).font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.ink)
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
                Text(LocalizedStringKey(vaha.ad)).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.9)))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Diğer gerçek oyuncunun üssü — güce göre renk, basınca baskın detayı.
private struct OnlineDusmanPin: View {
    let oyuncu: LiderSatir
    let tap: () -> Void
    private var renk: Color { oyuncu.respect >= 500 ? Theme.blood : Theme.smoke }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.coal.opacity(0.95))
                        .frame(width: 34, height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(renk.opacity(0.8), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                    Image(systemName: "building.2.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(renk)
                }
                Text(oyuncu.ad).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Theme.coal.opacity(0.85)))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: Düşman baskın sheet (online)
private struct OnlineDusmanDetay: View {
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) private var dismiss
    let oyuncu: LiderSatir
    @State private var saldirdi = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Theme.coal).frame(height: 160)
                    Image(systemName: "building.2.crop.circle.fill").font(.system(size: 76))
                        .foregroundStyle(Theme.blood)
                }
                Text(oyuncu.ad).font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
                HStack(spacing: 18) {
                    rozet("Güç", fmt(oyuncu.power), Theme.gold)
                    rozet("İtibar", fmt(oyuncu.respect), Theme.blood)
                    rozet("Galibiyet", "\(oyuncu.wins)", Theme.smoke)
                }
                if saldirdi, let s = online.sonSaldiri {
                    Text(s.won ? "Baskın tuttu! +₺\(fmt(s.loot)) yağma" : "Baskın patladı — savunması sağlammış")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(s.won ? Theme.gold : Theme.blood)
                        .frame(maxWidth: .infinity).padding(10).background(Theme.panelHi)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let b = online.dunyaBilgi {
                    Text(b).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.blood)
                }
                Button {
                    Task { await online.dunyaSaldir(oyuncu.id); saldirdi = true }
                } label: {
                    Text("BASKIN YAP").font(.system(size: 16, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.blood).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Text("Ordunla saldırırsın; kazanırsan nakdinden yağma alırsın. Kaybedersen asker kaybedersin.")
                    .font(.system(size: 11)).foregroundStyle(Theme.smoke).multilineTextAlignment(.center)
            }.padding(16)
        }
        .background(Theme.bg).presentationDetents([.medium, .large])
    }

    private func rozet(_ b: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(c)
            Text(b).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.smoke)
        }
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
                Text(LocalizedStringKey(g.ad)).font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
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
                Text(LocalizedStringKey(g.ad)).font(.system(size: 24, weight: .black)).foregroundStyle(Theme.ink)
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
