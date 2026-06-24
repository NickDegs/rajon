import SwiftUI

/// Patron maceraları — reisi zamanlı bir işe gönder, ödül getir.
struct MaceraView: View {
    @EnvironmentObject var game: GameStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                baslik
                if let m = game.aktifMacera { aktifKart(m) }
                ForEach(game.maceralar) { m in
                    if !m.devamEdiyor { MaceraKart(macera: m) }
                }
            }
            .padding(16)
        }
    }

    private var baslik: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PATRON MACERALARI").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
            Text("Reisi bir işe gönder. İş zaman alır; dönünce nakit, itibar ve bazen teçhizat getirir. Aynı anda tek iş.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aktifKart(_ m: Macera) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let kalan = max(0, Int(m.bitis?.timeIntervalSinceNow ?? 0))
            HStack(spacing: 12) {
                Image(systemName: "figure.walk.motion").font(.system(size: 26)).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("İŞTE: \(m.ad)").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    Text("Dönüş: \(sureMetni(kalan)) · ₺\(fmt(m.oduuncash)) + \(m.odulRespect) itibar")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                }
                Spacer()
            }
            .cardStyle(14)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
        }
    }
}

struct MaceraKart: View {
    @EnvironmentObject var game: GameStore
    let macera: Macera

    var body: some View {
        let m = macera
        let mesgul = game.maceradaMi
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Theme.panelHi)
                Image(systemName: "briefcase.fill").font(.system(size: 24)).foregroundStyle(Theme.blood)
            }.frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.ad).font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                Text(m.aciklama).font(.system(size: 11)).foregroundStyle(Theme.smoke).lineLimit(2)
                HStack(spacing: 10) {
                    Label("₺\(fmt(m.oduuncash))", systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
                    Label("\(m.odulRespect)", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.blood)
                    if m.gearDusur {
                        Label("teçhizat", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.smoke)
                    }
                }
            }
            Spacer(minLength: 4)
            Button { game.maceraBaslat(m.id) } label: {
                VStack(spacing: 0) {
                    Text("GÖNDER").font(.system(size: 12, weight: .black))
                    Text(sureMetni(Int(m.sure))).font(.system(size: 10, weight: .semibold)).opacity(0.85)
                }
                .foregroundStyle(mesgul ? Theme.smoke : .white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(mesgul ? Theme.panelHi : Theme.blood)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain).disabled(mesgul)
        }
        .cardStyle(12)
    }
}
