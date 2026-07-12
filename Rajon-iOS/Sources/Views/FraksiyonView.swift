import SwiftUI

/// Fraksiyon seçimi — başta bir kez, kalıcı bonus. (Cosa Nostra / Bratva / Kartel / Yakuza)
struct FraksiyonView: View {
    @EnvironmentObject var online: OnlineService
    let onSec: (String) -> Void

    private static let ikon: [String: String] = [
        "cosa": "shield.lefthalf.filled", "bratva": "flame.fill", "kartel": "dollarsign.circle.fill", "yakuza": "bolt.fill",
    ]
    private static let renk: [String: Color] = [
        "cosa": Theme.gold, "bratva": Theme.blood, "kartel": Theme.gold, "yakuza": Theme.blood,
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Sokakta hangi ailedensin? Seçimin kalıcıdır ve sana özel bir güç verir.")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                    .multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 6)
                ForEach(online.dunya?.fraksiyonlar ?? []) { f in
                    Button { onSec(f.kod) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: Self.ikon[f.kod] ?? "shield.fill")
                                .font(.system(size: 34)).foregroundStyle(Self.renk[f.kod] ?? Theme.gold).frame(width: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.ad).font(.system(size: 18, weight: .black)).foregroundStyle(Theme.ink)
                                Text(f.bonus).font(.system(size: 13, weight: .bold)).foregroundStyle(Self.renk[f.kod] ?? Theme.gold)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.smoke)
                        }
                        .frame(maxWidth: .infinity).cardStyle(16)
                    }
                    .buttonStyle(.plain)
                }
                Text("Bonus tüm oyun boyunca geçerlidir. Sonradan değiştirilemez.")
                    .font(.system(size: 11)).foregroundStyle(Theme.smoke).padding(.top, 4)
            }.padding(16)
        }
    }
}
