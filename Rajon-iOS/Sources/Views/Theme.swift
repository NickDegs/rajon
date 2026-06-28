import SwiftUI
import UIKit

/// Kullanıcı tema tercihi (kalıcı). Varsayılan: koyu (mevcut görünüm korunur).
enum ThemeMode: String, CaseIterable {
    case koyu, acik, sistem
    var colorScheme: ColorScheme? { self == .koyu ? .dark : (self == .acik ? .light : nil) }
    var ad: String { self == .koyu ? "Koyu" : (self == .acik ? "Açık" : "Sistem") }
    var ikon: String { self == .koyu ? "moon.stars.fill" : (self == .acik ? "sun.max.fill" : "circle.lefthalf.filled") }
}

/// Tema yöneticisi — seçimi UserDefaults'ta saklar, app geneline uygulanır.
final class ThemeManager: ObservableObject {
    @Published var mode: ThemeMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "rajon_theme") }
    }
    init() {
        let raw = UserDefaults.standard.string(forKey: "rajon_theme") ?? ThemeMode.koyu.rawValue
        mode = ThemeMode(rawValue: raw) ?? .koyu
    }
    var colorScheme: ColorScheme? { mode.colorScheme }
}

/// İki temaya da uyan dinamik renk (koyu / açık).
private func dyn(_ d: (Double, Double, Double), _ l: (Double, Double, Double)) -> Color {
    Color(UIColor { tc in
        let c = tc.userInterfaceStyle == .light ? l : d
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

/// Mafya teması — koyu (kan/kömür/altın) ve açık varyantlarıyla adaptif.
enum Theme {
    static let blood    = dyn((0.78, 0.09, 0.06), (0.82, 0.13, 0.10))
    static let bloodDim = dyn((0.45, 0.06, 0.05), (0.80, 0.20, 0.16))
    static let gold     = dyn((0.85, 0.68, 0.30), (0.70, 0.52, 0.10))
    static let coal     = dyn((0.05, 0.05, 0.06), (0.96, 0.96, 0.97))
    static let panel    = dyn((0.11, 0.11, 0.13), (1.00, 1.00, 1.00))
    static let panelHi  = dyn((0.16, 0.16, 0.19), (0.90, 0.90, 0.93))
    static let smoke    = dyn((0.62, 0.62, 0.66), (0.42, 0.42, 0.47))
    /// Birincil metin (panel/kart üstü) — koyuda beyaz, açıkta siyah.
    static let ink      = dyn((0.96, 0.96, 0.97), (0.08, 0.08, 0.10))

    static var bg: some View {
        LinearGradient(
            colors: [dyn((0.07, 0.06, 0.07), (0.97, 0.97, 0.98)), coal],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// Standart panel kartı — iOS 26'da Liquid Glass, öncesinde panel fallback.
    @ViewBuilder
    func cardStyle(_ pad: CGFloat = 14) -> some View {
        if #available(iOS 26.0, *) {
            self
                .padding(pad)
                .glassEffect(.regular.tint(Theme.panel.opacity(0.55)),
                             in: .rect(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                )
        } else {
            self
                .padding(pad)
                .background(Theme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    /// Birincil cam buton (CTA). iOS 26 glass, öncesinde renkli dolgu.
    @ViewBuilder
    func glassCTA(tint: Color = Theme.blood) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: 14))
        } else {
            self.background(tint).clipShape(RoundedRectangle(cornerRadius: 14))
        }
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
