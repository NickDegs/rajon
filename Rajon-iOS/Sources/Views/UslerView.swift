import SwiftUI

/// Çoklu üs + fetih — kendi ek üslerin (garnizon/hasat) + fethedilecek düşman üsleri.
struct UslerView: View {
    @EnvironmentObject var online: OnlineService
    @State private var sekme = 0
    @State private var garnizonUs: Us? = nil

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sekme) {
                Text("Üslerim").tag(0)
                Text("Fetih").tag(1)
                Text("Kervan").tag(2)
            }.pickerStyle(.segmented).padding(12)

            if sekme == 2 {
                KervanView().environmentObject(online)
            } else {
                ScrollView {
                    if sekme == 0 { uslerimBolum } else { fetihBolum }
                }
            }
        }
        .task { await online.uslerimCek(); await online.dusmanUsleriCek() }
        .sheet(item: $garnizonUs) { us in
            NavigationStack {
                GarnizonAyarView(us: us)
                    .navigationTitle(us.ad)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: Üslerim
    private var uslerimBolum: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Ek üs hakkı: \(online.uslerim.filter { !$0.ana }.count) / \(online.usLimit)")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.smoke)
                Spacer()
                Button { Task { await online.usHasat() } } label: {
                    Label("Kasa Hasat", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                }.tint(Theme.gold)
            }.padding(.horizontal, 4)

            ForEach(online.uslerim) { us in usKart(us) }

            Button { Task { await online.usKur() } } label: {
                Label("Yeni Ek Üs Kur", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .black)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(Theme.blood)
            .disabled(online.uslerim.filter { !$0.ana }.count >= online.usLimit)

            Text("Karargahını yükselttikçe daha çok ek üs kurabilirsin (her 5 seviye +1 hak). Ek üsler gelir üretir, garnizonla savunulur ve düşman şef gönderirse fethedilebilir.")
                .font(.system(size: 11)).foregroundStyle(Theme.smoke).padding(.top, 2)
        }.padding(14)
    }

    private func usKart(_ us: Us) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: us.ana ? "building.columns.fill" : "house.fill")
                    .foregroundStyle(us.ana ? Theme.gold : Theme.blood)
                Text(us.ad).font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                Spacer()
                Text("+\(us.gelir)/sn").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
            }
            HStack(spacing: 14) {
                Label("\(us.kasa)", systemImage: "banknote").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                if !us.ana {
                    Label("Sadakat \(us.sadakat)", systemImage: "shield.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(us.sadakat > 50 ? Theme.gold : Theme.blood)
                }
            }
            let toplam = us.garrison.values.reduce(0, +)
            Text(toplam > 0 ? "Garnizon: \(toplam) birlik" : "Garnizon boş — savunmasız!")
                .font(.system(size: 12)).foregroundStyle(toplam > 0 ? Theme.smoke : Theme.blood)
            if !us.ana {
                NavigationLink {
                    KoyYonetimView(bid: us.id).environmentObject(online)
                        .navigationTitle(us.ad).navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Köyü Yönet (bina · ekonomi · eğit)", systemImage: "building.2.crop.circle.fill")
                        .font(.system(size: 13, weight: .black)).foregroundStyle(Theme.blood)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.top, 2)
                HStack {
                    Button { garnizonUs = us } label: {
                        Label("Garnizon Yerleştir", systemImage: "person.3.fill").font(.system(size: 12, weight: .bold))
                    }.tint(Theme.gold)
                    Spacer()
                    Button { Task { await online.usGarnizonCek(us.id) } } label: {
                        Text("Geri Çek").font(.system(size: 12, weight: .bold))
                    }.tint(Theme.smoke)
                }.padding(.top, 2)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
    }

    // MARK: Fetih (düşman üsleri)
    private var fetihBolum: some View {
        VStack(spacing: 12) {
            Text("Şef birliği (Sef) gönder → kazanılan baskında düşman üssünün sadakatini düşür. Sadakat 0 olunca üs SENİN olur.")
                .font(.system(size: 12)).foregroundStyle(Theme.smoke).padding(.horizontal, 4)
            if online.dusmanUsler.isEmpty {
                Text("Yakında fethedilecek düşman üssü yok. Rakipler büyüdükçe burada belirir.")
                    .font(.system(size: 13)).foregroundStyle(Theme.smoke).padding(.top, 30)
            }
            ForEach(online.dusmanUsler) { d in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(d.ad).font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(d.uzaklik) km").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    }
                    Text("Sahip: \(d.sahip)").font(.system(size: 12)).foregroundStyle(Theme.smoke)
                    HStack {
                        Label("Sadakat \(d.sadakat)", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(d.sadakat > 50 ? Theme.blood : Theme.gold)
                        Spacer()
                        Button { Task { await online.usSaldir(d.id) } } label: {
                            Label("Fetih Baskını", systemImage: "flame.fill").font(.system(size: 12, weight: .black))
                        }.buttonStyle(.borderedProminent).tint(Theme.blood)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).cardStyle(14)
            }
        }.padding(14)
    }
}

/// Ek üsse garnizon (savunma birliği) yerleştirme — tüm birim türleri.
private struct GarnizonAyarView: View {
    @EnvironmentObject var online: OnlineService
    @Environment(\.dismiss) var dismiss
    let us: Us
    @State private var sec: [String: Int] = [:]

    private static let birimler: [(String, String)] = [
        ("tetikci", "Tetikçi"), ("kabadayi", "Kabadayı"), ("sofor", "Şoför"),
        ("suvari", "Süvari"), ("muhafiz", "Muhafız"), ("yikici", "Yıkıcı"),
        ("sef", "Şef"), ("izci", "İzci"),
    ]
    private var ordu: [String: Int] { online.dunya?.army ?? [:] }
    private var toplam: Int { sec.values.reduce(0, +) }

    var body: some View {
        Form {
            Section("Ana üsten gönderilecek birlik") {
                ForEach(Self.birimler, id: \.0) { kod, ad in
                    let maks = ordu[kod] ?? 0
                    Stepper(value: Binding(get: { sec[kod] ?? 0 }, set: { sec[kod] = $0 }), in: 0...max(0, maks)) {
                        HStack { Text(ad); Spacer(); Text("\(sec[kod] ?? 0) / \(maks)").foregroundStyle(Theme.smoke) }
                    }.disabled(maks == 0)
                }
            }
            Section {
                Button {
                    Task { await online.usGarnizonGonder(us.id, sec); dismiss() }
                } label: {
                    Text("Garnizona Yerleştir").frame(maxWidth: .infinity).font(.system(size: 15, weight: .black))
                }.disabled(toplam == 0)
            }
        }
    }
}
