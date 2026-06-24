import SwiftUI

/// Karanlık mafya teması — kan kırmızısı, kömür siyahı, altın.
enum Theme {
    static let blood = Color(red: 0.78, green: 0.09, blue: 0.06)
    static let bloodDim = Color(red: 0.45, green: 0.06, blue: 0.05)
    static let gold = Color(red: 0.85, green: 0.68, blue: 0.30)
    static let coal = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let panel = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let panelHi = Color(red: 0.16, green: 0.16, blue: 0.19)
    static let smoke = Color(red: 0.62, green: 0.62, blue: 0.66)

    static var bg: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.06, blue: 0.07), coal],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Standart panel kartı görünümü.
    func cardStyle(_ pad: CGFloat = 14) -> some View {
        self
            .padding(pad)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

/// Para/sayı biçimlendirme: 1.2K, 3.4M gibi.
func fmt(_ n: Int) -> String {
    let d = Double(n)
    switch abs(d) {
    case 1_000_000_000...: return String(format: "%.1fB", d / 1_000_000_000)
    case 1_000_000...:     return String(format: "%.1fM", d / 1_000_000)
    case 1_000...:         return String(format: "%.1fK", d / 1_000)
    default:               return "\(n)"
    }
}
