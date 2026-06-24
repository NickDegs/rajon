import SwiftUI

/// Sinematik mercek yanması (lens flare). `progress` 0→1 ekranı kesen ışık huzmesini taşır.
struct LensFlare: View {
    var progress: CGFloat          // -0.2 ... 1.2 (ekran dışından girip çıkar)
    var intensity: CGFloat = 1
    var tint: Color = Theme.gold

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let p = CGPoint(x: w * progress, y: h * (0.18 + 0.55 * progress))
            ZStack {
                // ana parlak çekirdek
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.95 * intensity),
                                                  tint.opacity(0.5 * intensity), .clear],
                                         center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 320, height: 320)
                    .position(p)

                // yatay parlama çizgisi (anamorphic streak)
                Capsule()
                    .fill(LinearGradient(colors: [.clear, tint.opacity(0.55 * intensity),
                                                  .white.opacity(0.9 * intensity),
                                                  tint.opacity(0.55 * intensity), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: w * 1.4, height: 6)
                    .blur(radius: 2)
                    .position(x: p.x, y: p.y)

                // dikey ince parlama
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.6 * intensity), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: h * 0.6)
                    .blur(radius: 3)
                    .position(p)

                // kromatik hayalet halkalar (flare → merkez ekseni boyunca)
                ForEach(Array(ghosts.enumerated()), id: \.offset) { _, g in
                    let gx = p.x + (center.x - p.x) * g.t
                    let gy = p.y + (center.y - p.y) * g.t
                    Circle()
                        .stroke(g.color.opacity(g.op * intensity), lineWidth: g.line)
                        .frame(width: g.size, height: g.size)
                        .position(x: gx, y: gy)
                        .blur(radius: 0.5)
                }
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }

    private struct Ghost { let t: CGFloat; let size: CGFloat; let line: CGFloat; let color: Color; let op: CGFloat }
    private var ghosts: [Ghost] {
        [ Ghost(t: 0.35, size: 70,  line: 8, color: Theme.gold,  op: 0.45),
          Ghost(t: 0.6,  size: 130, line: 4, color: Theme.blood, op: 0.40),
          Ghost(t: 0.9,  size: 50,  line: 6, color: .white,      op: 0.35),
          Ghost(t: 1.3,  size: 180, line: 3, color: Theme.gold,  op: 0.30),
          Ghost(t: 1.7,  size: 90,  line: 5, color: .cyan,       op: 0.22) ]
    }
}

extension View {
    /// `trigger` her değiştiğinde ekranı bir kez kesen mercek yanması süpürmesi.
    func lensFlareSweep(trigger: Int, tint: Color = Theme.gold, autoStart: Bool = false) -> some View {
        modifier(FlareSweep(trigger: trigger, tint: tint, autoStart: autoStart))
    }
}

struct FlareSweep: ViewModifier {
    let trigger: Int
    var tint: Color = Theme.gold
    var autoStart: Bool = false
    @State private var p: CGFloat = -0.3
    @State private var gorunur = false

    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if gorunur {
                    LensFlare(progress: p,
                              intensity: max(0, 1 - abs(p - 0.5) * 1.5),
                              tint: tint)
                }
            }
        )
        .onChange(of: trigger) { _, _ in sup() }
        .onAppear { if autoStart { sup() } }
    }

    private func sup() {
        gorunur = true
        p = -0.3
        withAnimation(.easeInOut(duration: 1.5)) { p = 1.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { gorunur = false }
    }
}
