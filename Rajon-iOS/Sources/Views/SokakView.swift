import SwiftUI

/// Sokak — rakip çete kademeleri, dövüşe giriş.
struct SokakView: View {
    @EnvironmentObject var game: GameStore
    @State private var secilen: RivalNode?
    @State private var seferAcik = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                baslik
                seferButon
                if game.squadEnforcers.isEmpty {
                    Text("⚠️ Sahada adamın yok. Önce 'Ekip'ten sahaya adam koy.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.blood)
                        .frame(maxWidth: .infinity)
                        .cardStyle(12)
                }
                ForEach(Array(game.rivals.enumerated()), id: \.element.id) { idx, node in
                    RivalCard(node: node, index: idx, kilit: kilitli(idx)) {
                        if !game.squadEnforcers.isEmpty { secilen = node }
                    }
                }
            }
            .padding(16)
        }
        .fullScreenCover(item: $secilen) { node in
            CombatView(node: node)
                .environmentObject(game)
        }
        .fullScreenCover(isPresented: $seferAcik) {
            NavigationStack {
                SeferView()
                    .navigationTitle("Ordu & Sefer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { seferAcik = false } } }
                    .background(Theme.bg)
            }
            .preferredColorScheme(.dark)
            .environmentObject(game)
        }
    }

    private var seferButon: some View {
        Button { seferAcik = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "car.2.fill").font(.system(size: 24)).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ORDU & SEFER").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                    if game.seferdeMi {
                        Text("\(game.seferler.count) sefer yolda").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                    } else {
                        Text("Asker eğit, akına çık, yağma getir").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.smoke)
            }
            .cardStyle(14)
        }
        .buttonStyle(.plain)
    }

    /// Önceki düğüm temizlenmeden sonraki açılmaz.
    private func kilitli(_ idx: Int) -> Bool {
        idx > 0 && !game.rivals[idx - 1].cleared
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ŞEHRİ ELE GEÇİR")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
            Text("Çeteleri tek tek dağıt, sokakları al. Ekibini güçlendirmeden ağırlara bulaşma.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RivalCard: View {
    @EnvironmentObject var game: GameStore
    let node: RivalNode
    let index: Int
    let kilit: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !kilit { onTap() } }) {
            HStack(spacing: 12) {
                ZStack {
                    if let g = node.gorsel {
                        Image(g).resizable().scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .saturation(kilit ? 0 : 1)
                            .opacity(kilit ? 0.45 : 1)
                    } else {
                        RoundedRectangle(cornerRadius: 12).fill(Theme.panelHi)
                    }
                    if kilit {
                        Image(systemName: "lock.fill").font(.system(size: 20)).foregroundStyle(.white)
                    } else if node.cleared {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(Theme.gold)
                            .shadow(radius: 3)
                    }
                }
                .frame(width: 54, height: 54)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.08), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.ad)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(node.aciklama)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.smoke)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        etiket("Güç \(fmt(node.power))", "shield.lefthalf.filled", guceGore)
                        etiket("₺\(fmt(node.oduuncash))", "dollarsign.circle.fill", Theme.gold)
                    }
                }
                Spacer()
                if !kilit && !node.cleared {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.blood)
                }
            }
            .cardStyle(12)
            .opacity(kilit ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(kilit)
    }

    /// Ekip gücü düşmandan zayıfsa kırmızı uyarı.
    private var guceGore: Color {
        game.squadPower >= node.power ? Theme.smoke : Theme.blood
    }

    private func etiket(_ t: String, _ icon: String, _ c: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9))
            Text(t).font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(c)
    }
}
