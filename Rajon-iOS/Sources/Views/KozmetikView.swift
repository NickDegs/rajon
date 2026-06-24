import SwiftUI

/// Kozmetik özelleştirme — avatar, isim rengi, unvan. Hiçbiri oyunu güçlendirmez.
struct KozmetikView: View {
    @EnvironmentObject var kozmetik: CosmeticStore
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var online: OnlineService
    @State private var premiumUyari = false

    private let grid = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                onizleme

                bolum("AVATAR") {
                    LazyVGrid(columns: grid, spacing: 12) {
                        ForEach(CosmeticStore.avatarlar, id: \.self) { a in
                            avatarHucre(a)
                        }
                    }
                }

                bolum("İSİM RENGİ") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                        ForEach(CosmeticStore.renkler, id: \.id) { r in
                            renkHucre(r.id, r.renk, r.premium)
                        }
                    }
                }

                bolum("UNVAN") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(CosmeticStore.unvanlar, id: \.self) { u in
                            unvanHucre(u)
                        }
                    }
                }

                bolum("VIP HAYVAN 👑") {
                    if !store.vipAktif {
                        Text("VIP'e özel: bir hayvan sahiplen, profilinde sergile. Mağaza'dan VIP edin.")
                            .font(.system(size: 11)).foregroundStyle(Theme.gold)
                    }
                    LazyVGrid(columns: grid, spacing: 12) {
                        petHucre("")   // "yok"
                        ForEach(CosmeticStore.petler, id: \.self) { p in petHucre(p) }
                    }
                }

                if !store.premiumAcik {
                    Text("⭐️ işaretli kozmetikler Destekçi paketiyle açılır. Hepsi sadece görünümdür, oyunu güçlendirmez.")
                        .font(.system(size: 11)).foregroundStyle(Theme.smoke)
                        .multilineTextAlignment(.center).padding(.top, 4)
                }
            }
            .padding(16)
        }
        .alert("Kilitli kozmetik", isPresented: $premiumUyari) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu kozmetik VIP (veya Destekçi) ile açılır. Hayvanlar VIP'e özeldir. Mağaza'dan edinebilirsin — hepsi sadece görünümdür, oyunu güçlendirmez.")
        }
    }

    // MARK: Önizleme
    private var onizleme: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Image(kozmetik.avatar).resizable().scaledToFill()
                    .frame(width: 110, height: 110).clipShape(Circle())
                    .overlay(Circle().stroke(kozmetik.seciliRenk, lineWidth: 4))
                if !kozmetik.pet.isEmpty {
                    Image(kozmetik.pet).resizable().scaledToFill()
                        .frame(width: 44, height: 44).clipShape(Circle())
                        .overlay(Circle().stroke(Theme.gold, lineWidth: 2))
                        .offset(x: 6, y: 6)
                }
            }
            HStack(spacing: 6) {
                if !kozmetik.unvan.isEmpty {
                    Text(kozmetik.unvan).font(.system(size: 12, weight: .black))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.panelHi).foregroundStyle(Theme.gold).clipShape(Capsule())
                }
                Text(online.me?.ad ?? "Patron").font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(kozmetik.seciliRenk)
                if let r = store.aktifRozet { Text(r).font(.system(size: 18)) }
            }
        }
        .frame(maxWidth: .infinity).cardStyle(18)
    }

    private func bolum<C: View>(_ ad: String, @ViewBuilder _ icerik: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ad).font(.system(size: 13, weight: .black)).foregroundStyle(Theme.smoke)
            icerik()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hücreler
    private func avatarHucre(_ a: String) -> some View {
        let premium = kozmetik.avatarPremiumMi(a)
        let kilit = premium && !store.premiumAcik
        let secili = kozmetik.avatar == a
        return Button {
            if kilit { premiumUyari = true } else { kozmetik.avatar = a }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(a).resizable().scaledToFill()
                    .frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? Theme.gold : .white.opacity(0.1), lineWidth: secili ? 3 : 1))
                    .saturation(kilit ? 0.3 : 1).opacity(kilit ? 0.7 : 1)
                if premium { Text("⭐️").font(.system(size: 14)).padding(4) }
                if kilit { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(.white).padding(6) }
            }
        }
        .buttonStyle(.plain)
    }

    private func renkHucre(_ id: String, _ renk: Color, _ premium: Bool) -> some View {
        let kilit = premium && !store.premiumAcik
        let secili = kozmetik.renk == id
        return Button {
            if kilit { premiumUyari = true } else { kozmetik.renk = id }
        } label: {
            ZStack {
                Circle().fill(renk).frame(width: 58, height: 58)
                    .overlay(Circle().stroke(secili ? .white : .clear, lineWidth: 3))
                    .opacity(kilit ? 0.5 : 1)
                if premium { Text("⭐️").font(.system(size: 12)).offset(x: 20, y: -20) }
                if kilit { Image(systemName: "lock.fill").font(.system(size: 14)).foregroundStyle(.white) }
            }
        }
        .buttonStyle(.plain)
    }

    private func petHucre(_ p: String) -> some View {
        let kilit = !p.isEmpty && !store.vipAktif
        let secili = kozmetik.pet == p
        return Button {
            if kilit { premiumUyari = true } else { kozmetik.pet = p }
        } label: {
            ZStack(alignment: .topTrailing) {
                if p.isEmpty {
                    RoundedRectangle(cornerRadius: 14).fill(Theme.panelHi)
                        .frame(width: 84, height: 84)
                        .overlay(Text("Yok").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? Theme.gold : .clear, lineWidth: 3))
                } else {
                    Image(p).resizable().scaledToFill()
                        .frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(secili ? Theme.gold : .white.opacity(0.1), lineWidth: secili ? 3 : 1))
                        .saturation(kilit ? 0.3 : 1).opacity(kilit ? 0.7 : 1)
                    Text("👑").font(.system(size: 14)).padding(4)
                    if kilit { Image(systemName: "lock.fill").font(.system(size: 12)).foregroundStyle(.white).padding(6) }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func unvanHucre(_ u: String) -> some View {
        let premium = kozmetik.unvanPremiumMi(u)
        let kilit = premium && !store.premiumAcik
        let secili = kozmetik.unvan == u
        return Button {
            if kilit { premiumUyari = true } else { kozmetik.unvan = u }
        } label: {
            HStack(spacing: 4) {
                Text(u.isEmpty ? "Yok" : u).font(.system(size: 13, weight: .bold))
                if premium { Text("⭐️").font(.system(size: 11)) }
            }
            .foregroundStyle(secili ? .black : (kilit ? Theme.smoke : .white))
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(secili ? Theme.gold : Theme.panelHi)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
