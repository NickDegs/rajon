import SwiftUI

/// Pazar (oyuncular arası takas) + Diplomasi (çete-çete savaş/nap/ittifak).
struct PazarView: View {
    @EnvironmentObject var online: OnlineService
    @State private var sekme = 0
    @State private var yeniAcik = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sekme) {
                Text("Pazar").tag(0)
                Text("Diplomasi").tag(1)
            }.pickerStyle(.segmented).padding(12)
            ScrollView { if sekme == 0 { pazarBolum } else { diplomasiBolum } }
        }
        .task { await online.pazarCek(); await online.diplomasiCek() }
        .sheet(isPresented: $yeniAcik) { IlanEkleView().environmentObject(online) }
    }

    // MARK: Pazar
    private var pazarBolum: some View {
        VStack(spacing: 12) {
            Button { yeniAcik = true } label: {
                Label("İlan Ver (Takas)", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .black)).frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(Theme.blood)

            if !online.pazarBenim.isEmpty {
                Text("AÇIK İLANLARIM").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(online.pazarBenim) { i in ilanKart(i, benim: true) }
            }
            Text("PAZARDAKİ İLANLAR").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
                .frame(maxWidth: .infinity, alignment: .leading)
            if online.pazarIlanlar.isEmpty {
                Text("Şu an açık ilan yok. İlk teklifi sen ver!").font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 20)
            }
            ForEach(online.pazarIlanlar) { i in ilanKart(i, benim: false) }
        }.padding(14)
    }

    private func ilanKart(_ i: PazarIlan, benim: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                if !benim { Text(i.satici).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke) }
                HStack(spacing: 6) {
                    Text("\(i.verMiktar) \(ad(i.verTip))").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.gold)
                    Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Theme.smoke)
                    Text("\(i.isteMiktar) \(ad(i.isteTip))").font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                }
            }
            Spacer()
            if benim {
                Button { Task { await online.pazarIptal(i.id) } } label: { Text("İptal").font(.system(size: 12, weight: .bold)) }.tint(Theme.smoke)
            } else {
                Button { Task { await online.pazarKabul(i.id) } } label: {
                    Text("Kabul").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6).background(Theme.blood).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }.cardStyle(12)
    }

    // MARK: Diplomasi
    private var diplomasiBolum: some View {
        VStack(spacing: 12) {
            if let d = online.diplomasi, !d.clan.isEmpty {
                Text("Çeten: \(d.clan)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.smoke)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if d.iliskiler.isEmpty {
                    Text("Henüz diplomatik ilişki yok. Bir düşman çeteye savaş ilan et veya müttefiklik teklif et.")
                        .font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 16)
                }
                ForEach(d.iliskiler) { r in iliskiKart(r) }
                DiplomasiTeklifView().environmentObject(online).padding(.top, 8)
            } else {
                Text("Diplomasi için bir çeteye katılman gerekir.").font(.system(size: 14)).foregroundStyle(Theme.smoke).padding(.top, 30)
            }
        }.padding(14)
    }

    private func iliskiKart(_ r: DiplomasiIliski) -> some View {
        HStack {
            Image(systemName: durumIkon(r.durum)).foregroundStyle(durumRenk(r.durum)).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.clan).font(.system(size: 14, weight: .black)).foregroundStyle(Theme.ink)
                Text(durumMetin(r)).font(.system(size: 11, weight: .bold)).foregroundStyle(durumRenk(r.durum))
            }
            Spacer()
            if r.bekleyen {
                Button { Task { await online.diplomasiTeklif(r.clan, durum: r.durum) } } label: {
                    Text("Onayla").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Theme.gold).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
            Button { Task { await online.diplomasiBoz(r.clan) } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.smoke)
            }
        }.cardStyle(12)
    }

    private func ad(_ t: String) -> String { t == "cash" ? "₺" : "cephane" }
    private func durumIkon(_ d: String) -> String {
        switch d { case "ittifak": return "hands.clap.fill"; case "nap": return "hand.raised.fill"; default: return "flame.fill" }
    }
    private func durumRenk(_ d: String) -> Color {
        switch d { case "ittifak": return Theme.gold; case "nap": return Theme.smoke; default: return Theme.blood }
    }
    private func durumMetin(_ r: DiplomasiIliski) -> String {
        let ad = ["ittifak": "İTTİFAK", "nap": "SALDIRMAZLIK", "savas": "SAVAŞ"][r.durum] ?? r.durum
        if r.durum == "savas" { return ad }
        return r.onayli ? ad : (r.bekleyen ? "\(ad) teklifi geldi" : "\(ad) — onay bekliyor")
    }
}

/// Yeni takas ilanı formu.
private struct IlanEkleView: View {
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) var dismiss
    @State private var verNakit = true
    @State private var verMik = 1000
    @State private var isteMik = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("Veriyorum") {
                    Picker("Kaynak", selection: $verNakit) { Text("Kuruş ₺").tag(true); Text("Cephane").tag(false) }
                    Stepper("Miktar: \(verMik)", value: $verMik, in: 100...1_000_000, step: 100)
                }
                Section("İstiyorum (\(verNakit ? "Cephane" : "Kuruş ₺"))") {
                    Stepper("Miktar: \(isteMik)", value: $isteMik, in: 10...1_000_000, step: 50)
                }
                Section {
                    Button {
                        let ver = verNakit ? "cash" : "cephane"
                        let iste = verNakit ? "cephane" : "cash"
                        Task { await online.pazarEkle(ver: ver, verMik: verMik, iste: iste, isteMik: isteMik); dismiss() }
                    } label: { Text("İlanı Yayınla").frame(maxWidth: .infinity).font(.system(size: 15, weight: .black)) }
                }
            }
            .navigationTitle("Yeni İlan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("İptal") { dismiss() } } }
        }
    }
}

/// Bir çeteye diplomatik teklif (savaş/nap/ittifak).
private struct DiplomasiTeklifView: View {
    @EnvironmentObject var online: OnlineService
    @State private var hedef = ""
    @State private var durum = "savas"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YENİ TEKLİF").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.smoke)
            TextField("Hedef çete kodu", text: $hedef).textFieldStyle(.roundedBorder).autocorrectionDisabled()
            Picker("Durum", selection: $durum) {
                Text("Savaş").tag("savas"); Text("Saldırmazlık").tag("nap"); Text("İttifak").tag("ittifak")
            }.pickerStyle(.segmented)
            Button {
                Task { await online.diplomasiTeklif(hedef.trimmingCharacters(in: .whitespaces), durum: durum); hedef = "" }
            } label: { Text("Teklif Gönder").frame(maxWidth: .infinity).font(.system(size: 14, weight: .black)) }
            .buttonStyle(.borderedProminent).tint(Theme.blood).disabled(hedef.trimmingCharacters(in: .whitespaces).isEmpty)
        }.cardStyle(12)
    }
}
