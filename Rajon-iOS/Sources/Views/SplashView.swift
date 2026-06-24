import SwiftUI

/// Açılış intro'su — fedora + RAJON yazısı, ekranı kesen mercek yanması.
struct SplashView: View {
    var onDone: () -> Void

    @State private var hatScale: CGFloat = 0.6
    @State private var hatOp: Double = 0
    @State private var titleOp: Double = 0
    @State private var titleY: CGFloat = 24
    @State private var flare = 0
    @State private var ring: CGFloat = 0.7

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.10, green: 0.05, blue: 0.06), Theme.coal],
                           center: .center, startRadius: 10, endRadius: 600)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                FedoraView()
                    .frame(width: 220, height: 150)
                    .scaleEffect(hatScale)
                    .opacity(hatOp)
                    .shadow(color: Theme.gold.opacity(0.4), radius: 30)

                Text("RAJON")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(LinearGradient(colors: [Theme.gold, Color(red: 0.6, green: 0.42, blue: 0.16)],
                                                    startPoint: .top, endPoint: .bottom))
                    .opacity(titleOp)
                    .offset(y: titleY)

                Text("SOKAĞIN KRALI SEN OL")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(Theme.smoke)
                    .opacity(titleOp * 0.9)
            }
        }
        .lensFlareSweep(trigger: flare, tint: Theme.gold)
        .onAppear { animate() }
        .onTapGesture { onDone() }
    }

    private func animate() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
            hatScale = 1; hatOp = 1
        }
        withAnimation(.easeOut(duration: 0.7).delay(0.25)) {
            titleOp = 1; titleY = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { flare += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.4)) { } // çıkış
            onDone()
        }
    }
}

/// SwiftUI ile çizilmiş fedora — splash için.
struct FedoraView: View {
    private var gold: LinearGradient {
        LinearGradient(colors: [Color(red: 0.99, green: 0.91, blue: 0.62),
                                Color(red: 0.55, green: 0.38, blue: 0.14)],
                       startPoint: .top, endPoint: .bottom)
    }
    var body: some View {
        ZStack {
            // kenar (brim)
            Ellipse().fill(gold)
                .frame(width: 220, height: 64)
                .offset(y: 46)
            // taç
            UnevenRoundedRectangle(topLeadingRadius: 46, bottomLeadingRadius: 6,
                                   bottomTrailingRadius: 6, topTrailingRadius: 46, style: .continuous)
                .fill(gold)
                .frame(width: 120, height: 96)
                .offset(y: 6)
            // bant
            Rectangle().fill(Theme.blood)
                .frame(width: 120, height: 16)
                .offset(y: 34)
            // tepe parlama
            Ellipse().fill(Color.white.opacity(0.5)).blur(radius: 6)
                .frame(width: 70, height: 18)
                .offset(y: -32)
        }
    }
}
