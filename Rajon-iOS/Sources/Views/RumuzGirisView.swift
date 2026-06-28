import SwiftUI

/// İlk açılış onboarding — oyuncu KENDİ rumuzunu oluşturur (tam online).
/// Boş bırakırsa temiz (argo olmayan) rastgele bir ad atanır.
struct RumuzGirisView: View {
    /// Seçilen rumuzla dünyaya giriş tetiklenir.
    let onSubmit: (String) -> Void

    @State private var rumuz = ""
    @FocusState private var odak: Bool

    private static let temizOnek = ["Reis", "Patron", "Baba", "Kaptan", "Usta", "Aga", "Sokak", "Kobra"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(colors: [Theme.blood.opacity(0.18), .clear],
                           center: .top, startRadius: 10, endRadius: 420).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "crown.fill").font(.system(size: 52)).foregroundStyle(Theme.gold)
                Text("RAJON")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink).tracking(4)
                VStack(spacing: 6) {
                    Text("Rumuzunu seç")
                        .font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("Sokakta seni bu isimle tanıyacaklar.")
                        .font(.system(size: 13)).foregroundStyle(Theme.smoke)
                }
                TextField("Rumuz", text: $rumuz)
                    .focused($odak)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(Theme.panelHi)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.35), lineWidth: 1))
                    .submitLabel(.go)
                    .onSubmit { gir() }

                Button { gir() } label: {
                    Text("DÜNYAYA GİR")
                        .font(.system(size: 16, weight: .black))
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(Theme.blood).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Text("Boş bırakırsan sana rastgele bir reis adı verilir.")
                    .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { odak = true } }
    }

    private func gir() {
        let t = rumuz.trimmingCharacters(in: .whitespacesAndNewlines)
        let ad = t.isEmpty
            ? "\(Self.temizOnek.randomElement()!)_\(Int.random(in: 1000...9999))"
            : String(t.prefix(20))
        odak = false
        onSubmit(ad)
    }
}
