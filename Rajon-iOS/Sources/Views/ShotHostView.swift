import SwiftUI

/// App Store ekran görüntüleri için "görsel modu" host'u.
/// Zengin demo hesabına (SHOT_DEMO) girer ve istenen yeni-özellik ekranını GERÇEK arayüzle tam ekran gösterir.
/// CI'da simülatörde `-shot <ekran>` argümanıyla çalıştırılır; xcrun simctl ile görüntülenir.
struct ShotHostView: View {
    @EnvironmentObject var online: OnlineService
    let ekran: String
    @State private var hazir = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if hazir {
                if ekran == "oyun" {
                    OnlineWorldView().environmentObject(online).tint(Theme.blood)
                } else {
                    NavigationStack { icerik }.tint(Theme.blood)
                }
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(Theme.gold)
                    Text("Yükleniyor…").font(.system(size: 14)).foregroundStyle(Theme.smoke)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await online.shotLogin()
            try? await Task.sleep(nanoseconds: 400_000_000)
            hazir = true
        }
    }

    @ViewBuilder private var icerik: some View {
        switch ekran {
        case "oyun":
            OnlineWorldView()
        case "usler":
            UslerView().navigationTitle("Üsler & Fetih").navigationBarTitleDisplayMode(.inline)
        case "kahraman":
            KahramanView().navigationTitle("Kahraman").navigationBarTitleDisplayMode(.inline)
        case "natar":
            NatarView().navigationTitle("Natar Eyaleti").navigationBarTitleDisplayMode(.inline)
        case "rehber":
            BirlikRehberiView().navigationTitle("Birlik Rehberi").navigationBarTitleDisplayMode(.inline)
        case "akademi":
            AkademiView().navigationTitle("Akademi & Kültür").navigationBarTitleDisplayMode(.inline)
        case "magaza":
            MagazaView(shotMode: true).navigationTitle("Mağaza").navigationBarTitleDisplayMode(.inline)
        case "pazar":
            PazarView().navigationTitle("Pazar & Diplomasi").navigationBarTitleDisplayMode(.inline)
        case "ittifak":
            IttifakView().navigationTitle("İttifak Bonusları").navigationBarTitleDisplayMode(.inline)
        case "harika":
            HarikaView().navigationTitle("Dünya Harikası").navigationBarTitleDisplayMode(.inline)
        case "koy":
            if let bid = online.uslerim.first(where: { !$0.ana })?.id {
                KoyYonetimView(bid: bid).navigationTitle("Köy Yönetimi").navigationBarTitleDisplayMode(.inline)
            } else {
                Text("Köy yükleniyor…").foregroundStyle(Theme.smoke)
            }
        default:
            Text("Bilinmeyen ekran: \(ekran)").foregroundStyle(Theme.smoke)
        }
    }
}
