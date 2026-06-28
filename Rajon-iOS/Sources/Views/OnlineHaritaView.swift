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

    /// Kurgu "Rajon şehri" merkezi (gerçek konum DEĞİL — sadece harita sahnesi).
    static let sehirMerkezi = CLLocationCoordinate2D(latitude: 41.0411, longitude: 28.9784)
    /// Düşman üslerinin yayıldığı dünya kutusu (geniş metropol — "koca dünya" hissi).
    private static let spanLat = 0.52
    private static let spanLon = 0.92

    // Sunucu idx → harita grid koordinatı (kendi bölgen merkezde, daha geniş aralık).
    private static let bolgeGrid: [(Int, Int)] = [(1, 1), (3, 0), (0, 3), (2, 3), (4, 2), (4, 4)]
    private static let vahaGrid:  [(Int, Int)] = [(2, 1), (0, 1), (3, 2), (1, 4), (4, 0), (3, 4)]
    static let bolgeGorsel = ["bolge_carsi", "bolge_liman", "bolge_yokus", "bolge_meydan", "bolge_sanayi", "bolge_kordon"]

    /// Grid koordinatını (hx,hy 0–4) kurgu enlem/boylama çevirir (kendi bölgen).
    static func koord(_ hx: Int, _ hy: Int) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: sehirMerkezi.latitude - Double(hy - 2) * 0.0140,
            longitude: sehirMerkezi.longitude + Double(hx - 2) * 0.0185)
    }

    /// Oyuncu id'sinden DETERMİNİSTİK koordinat — her oyuncu dünyada hep aynı yerde.
    static func dusmanKoord(_ id: String) -> CLLocationCoordinate2D {
        var h: UInt64 = 0xcbf29ce484222325
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        let u = Double(h & 0xffffffff) / Double(UInt32.max)
        let v = Double((h >> 32) & 0xffffffff) / Double(UInt32.max)
        return CLLocationCoordinate2D(
            latitude: sehirMerkezi.latitude + (v - 0.5) * spanLat,
            longitude: sehirMerkezi.longitude + (u - 0.5) * spanLon)
    }

    var body: some View {
        VStack(spacing: 0) {
            ustBar
            Map(initialViewport: .camera(center: Self.sehirMerkezi, zoom: 9.7, bearing: 0, pitch: 0)) {
                // Kendi merkez üssün
                MapViewAnnotation(coordinate: Self.sehirMerkezi) { EvimPin() }.allowOverlap(true)

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
                // Diğer GERÇEK oyuncular — tüm dünyaya yayılı
                ForEvery(online.dunyaOyuncular) { p in
                    MapViewAnnotation(coordinate: Self.dusmanKoord(p.id)) {
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
