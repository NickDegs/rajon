import SwiftUI

struct CombatView: View {
    @EnvironmentObject var game: GameStore
    @Environment(\.dismiss) private var dismiss
    let node: RivalNode
    /// PvP modunda sonuç bu closure'a gider (kazandı mı). nil ise kampanya ödülü uygulanır.
    var onResult: ((Bool) -> Void)? = nil

    @StateObject private var engine: CombatEngine

    init(node: RivalNode, onResult: ((Bool) -> Void)? = nil) {
        self.node = node
        self.onResult = onResult
        _engine = StateObject(wrappedValue: CombatEngine(node: node, squad: []))
    }

    var body: some View {
        ZStack {
            Theme.bg
            VStack(spacing: 10) {
                ust
                dusmanSafi
                logKutusu
                oyuncuSafi
                aksiyonBar
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            if engine.result != .devam {
                sonucEkrani
            }
        }
        .onAppear { engine.kur(squad: game.squadEnforcers) }
    }

    // MARK: Üst başlık
    private var ust: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26)).foregroundStyle(Theme.smoke)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(node.ad).font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                Text("ÇATIŞMA").font(.system(size: 9, weight: .black)).foregroundStyle(Theme.blood)
            }
            Spacer()
            Image(systemName: "xmark.circle.fill").font(.system(size: 26)).foregroundStyle(.clear)
        }
    }

    // MARK: Düşman safı
    private var dusmanSafi: some View {
        HStack(spacing: 8) {
            ForEach(engine.enemy) { c in
                FighterCell(c: c, sallan: engine.sallananID == c.id,
                            hedeflenebilir: engine.hedefSecimi && c.alive) {
                    engine.ozelHedefSec(c.id)
                }
            }
        }
    }

    // MARK: Oyuncu safı
    private var oyuncuSafi: some View {
        HStack(spacing: 8) {
            ForEach(engine.player) { c in
                FighterCell(c: c, sallan: engine.sallananID == c.id,
                            vurgula: engine.siradaki == c.id && engine.oyuncununSirasi,
                            hedeflenebilir: false) {}
            }
        }
    }

    // MARK: Log
    private var logKutusu: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(engine.log) { line in
                        Text(line.text)
                            .font(.system(size: 12, weight: line.kind == .taunt ? .semibold : .medium))
                            .italic(line.kind == .taunt)
                            .foregroundStyle(renk(line.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(10)
            }
            .frame(height: 130)
            .background(Theme.coal.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: engine.log.count) {
                if let last = engine.log.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func renk(_ k: LogLine.Kind) -> Color {
        switch k {
        case .info:    return Theme.smoke
        case .hasar:   return .white
        case .ozel:    return Theme.gold
        case .taunt:   return Theme.blood
        case .zafer:   return Color.green
        case .yenilgi: return Theme.blood
        }
    }

    // MARK: Aksiyon bar
    private var aksiyonBar: some View {
        Group {
            if engine.hedefSecimi {
                HStack {
                    Text("ÖZEL HAMLE — yukarıdan hedef seç")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.gold)
                    Spacer()
                    Button("Vazgeç") { engine.ozelIptal() }
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke)
                }
                .padding(.vertical, 14).padding(.horizontal, 12)
                .background(Theme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(spacing: 10) {
                    Button { engine.saldir() } label: {
                        Label("SALDIR", systemImage: "burst.fill")
                            .font(.system(size: 15, weight: .black))
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(engine.oyuncununSirasi ? Theme.blood : Theme.panelHi)
                            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!engine.oyuncununSirasi)

                    Button { engine.ozelBaslat() } label: {
                        Label("ÖZEL", systemImage: "flame.fill")
                            .font(.system(size: 15, weight: .black))
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(engine.bekleyenOzel && engine.oyuncununSirasi ? Theme.gold : Theme.panelHi)
                            .foregroundStyle(engine.bekleyenOzel && engine.oyuncununSirasi ? .black : Theme.smoke)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!(engine.bekleyenOzel && engine.oyuncununSirasi))
                }
            }
        }
    }

    // MARK: Sonuç ekranı
    private var sonucEkrani: some View {
        let kazandi = engine.result == .kazandi
        return ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: kazandi ? "crown.fill" : "xmark.octagon.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(kazandi ? Theme.gold : Theme.blood)
                Text(kazandi ? "SOKAK SENİN!" : "DAĞILDIK...")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
                if kazandi {
                    VStack(spacing: 6) {
                        odulSatir("₺\(fmt(node.oduuncash))", "dollarsign.circle.fill", Theme.gold)
                        odulSatir("\(node.odulRespect) itibar", "flame.fill", Theme.blood)
                    }
                } else {
                    Text(Argo.yenilgiLaf.randomElement()!)
                        .font(.system(size: 14)).italic()
                        .foregroundStyle(Theme.smoke)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                }
                Button {
                    if let onResult {
                        onResult(kazandi)
                    } else if kazandi {
                        game.dovusKazanildi(node: node, hayatta: engine.hayattaOyuncuIDleri)
                    }
                    dismiss()
                } label: {
                    Text(kazandi ? "TOPLA VE ÇIK" : "GERİ ÇEKİL")
                        .font(.system(size: 16, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(kazandi ? Theme.blood : Theme.panelHi)
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding(28)
        }
        .transition(.opacity)
    }

    private func odulSatir(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(c)
            Text(t).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
    }
}

/// Tek bir savaşçı hücresi (avatar + can + enerji).
struct FighterCell: View {
    let c: Combatant
    var sallan: Bool = false
    var vurgula: Bool = false
    var hedeflenebilir: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: { if hedeflenebilir { onTap() } }) {
            VStack(spacing: 5) {
                ZStack {
                    Circle().fill(Theme.panelHi)
                    Image(systemName: c.klas.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(c.alive ? c.rarity.color : Theme.smoke.opacity(0.4))
                    if !c.alive {
                        Image(systemName: "xmark")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(Theme.blood)
                    }
                }
                .frame(width: 54, height: 54)
                .overlay(Circle().stroke(vurgula ? Theme.gold : c.rarity.color.opacity(c.alive ? 0.8 : 0.2),
                                         lineWidth: vurgula ? 3 : 2))
                .overlay(
                    hedeflenebilir ?
                    Circle().stroke(Theme.blood, lineWidth: 3).scaleEffect(1.15) : nil
                )

                Text(c.ad.split(separator: " ").last.map(String.init) ?? c.ad)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(c.alive ? .white : Theme.smoke)
                    .lineLimit(1)
                HealthBar(hp: c.hp, maxHP: c.maxHP, color: c.isPlayer ? .green : Theme.blood)
                // enerji
                HealthBar(hp: c.energy, maxHP: 100, color: Theme.gold)
                    .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(vurgula ? Theme.blood.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .offset(x: sallan ? 6 : 0)
            .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: sallan)
        }
        .buttonStyle(.plain)
        .disabled(!hedeflenebilir)
    }
}
