import SwiftUI

/// Online mod istemcisi — anonim hesap, ekip sync, PvP, lider tablosu.
@MainActor
final class OnlineService: ObservableObject {
    // NOT: duckdns.org bazı güvenlik/DNS filtreleri tarafından engellenip boş 200 döndürülüyordu
    // (isteğe hiç ulaşmıyor). Ana alan adına taşındı — Safari'de çalışan, engellenmeyen domain.
    static let base = URL(string: "https://rajon.nickdegs.com")!

    @Published var girisli = false
    @Published var ad = ""
    @Published var me: OnlinePlayer?
    @Published var lider: [LiderSatir] = []
    @Published var myRank: Int?
    @Published var clanim: Clan?
    @Published var clanListesi: [ClanOzet] = []
    @Published var clanSavas: ClanSavas?
    @Published var gelenBaskinlar: [GelenBaskin] = []
    @Published var smsGirisli = false      // telefon hesabıyla giriş yapıldı mı
    @Published var hata: String?
    @Published var mesgul = false

    /// Token önceliği: SMS (iCloud) → anonim (iCloud Keychain) → eski UserDefaults (migrasyon).
    /// Yazınca hem UserDefaults'a hem iCLOUD KEYCHAIN'e yazılır → app silinse de kalır.
    private var token: String? {
        get { AuthService.token ?? AuthService.anonToken ?? UserDefaults.standard.string(forKey: "rajon_online_token") }
        set {
            UserDefaults.standard.set(newValue, forKey: "rajon_online_token")
            if let v = newValue, !v.isEmpty { AuthService.anonTokenKaydet(v) }
        }
    }
    /// Daha önce (anonim veya SMS) hesap oluşturulmuş mu — ilk açılış rumuz ekranı için.
    var hesapVar: Bool {
        AuthService.token != nil || AuthService.anonToken != nil
            || UserDefaults.standard.string(forKey: "rajon_online_token") != nil
    }
    /// Cihaz kimliği: iCloud Keychain (kalıcı) → eski UserDefaults (migrasyon) → yeni üret.
    /// Keychain'de tutulduğu için app silinip yüklenince aynı hesap geri gelir (aynı Apple ID).
    private var deviceID: String {
        if let id = AuthService.anonDeviceId { return id }
        if let id = UserDefaults.standard.string(forKey: "rajon_device_id") {
            AuthService.anonCihazKaydet(id)               // eski kurulumu iCloud'a taşı
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "rajon_device_id")
        AuthService.anonCihazKaydet(id)
        return id
    }

    // MARK: Hesap

    func girisYap(ad: String) async {
        mesgul = true; defer { mesgul = false }
        do {
            let body = ["device_id": deviceID, "ad": ad]
            let r: RegisterResp = try await post("/rajon/register", body: body, auth: false)
            token = r.token
            me = r.player
            self.ad = r.player.ad
            girisli = true
            hata = nil
        } catch {
            hata = "Bağlanılamadı: \(error.localizedDescription)"
        }
    }

    func otomatikGiris() async {
        // iCloud Keychain'de SMS token'ı varsa onunla gir (telefon hesabı)
        if AuthService.girisli {
            if let r: MeResp = try? await get("/rajon/me") {
                me = r.player; ad = r.player.ad; girisli = true; smsGirisli = true; hata = nil
                return
            }
        }
        guard UserDefaults.standard.string(forKey: "rajon_online_token") != nil else { return }
        await girisYap(ad: ad.isEmpty ? "Patron" : ad)
    }

    // MARK: SMS giriş + telefona hesap yedeği

    func smsKodGonder(phone: String) async -> Bool {
        mesgul = true; defer { mesgul = false }
        do {
            let _: OkResp = try await post("/rajon/auth/sms/start", body: ["phone": phone], auth: false)
            return true
        } catch { hata = "SMS gönderilemedi"; return false }
    }

    /// Kodu doğrula. Başarılıysa telefon hesabına geçer; sunucuda kayıt varsa `onState` ile döner.
    func smsDogrula(phone: String, code: String, game: GameStore) async -> Bool {
        mesgul = true; defer { mesgul = false }
        do {
            let r: SmsVerifyResp = try await post("/rajon/auth/sms/verify",
                body: ["phone": phone, "code": code, "device_id": deviceID], auth: false)
            AuthService.kaydet(token: r.token, phone: phone)   // iCloud Keychain
            me = r.player; ad = r.player.ad; girisli = true; smsGirisli = true; hata = nil
            // Sunucuda kayıtlı durum varsa geri yükle, yoksa mevcut durumu yedekle
            if !r.state.isEmpty {
                game.durumYukle(r.state)
            } else {
                await durumYedekle(game.durumBlobu())
            }
            game.bulutaYedek = { [weak self] blob in
                guard let self else { return }
                Task { await self.durumYedekle(blob) }
            }
            return true
        } catch { hata = "Kod yanlış veya süresi doldu"; return false }
    }

    func smsCikis(game: GameStore) {
        AuthService.sil()
        smsGirisli = false
        game.bulutaYedek = nil
    }

    func durumYedekle(_ blob: String) async {
        guard !blob.isEmpty else { return }
        _ = try? await postRaw("/rajon/state/push", body: ["blob": blob])
    }

    // MARK: Sync

    func sync(game: GameStore) async {
        guard girisli else { return }
        let crewSnap = game.squadEnforcers.map { e -> [String: Any] in
            ["ad": e.ad, "rarity": e.rarity.rawValue, "klas": e.klas.rawValue,
             "level": e.level, "maxHP": e.maxHP, "atk": e.atk, "spd": e.spd]
        }
        let body: [String: Any] = [
            "ad": ad.isEmpty ? "Patron" : ad,
            "power": game.squadPower, "respect": game.respect,
            "cash": game.cash, "crew": crewSnap,
            "savunma": game.korunakSavunma,
        ]
        _ = try? await postRaw("/rajon/sync", body: body)
    }

    func gelenBaskinlariGetir() async {
        if let r: GelenBaskinResp = try? await get("/rajon/raids/incoming") {
            gelenBaskinlar = r.raids
        }
    }

    // MARK: PvP

    func hedefBul() async -> PvpTarget? {
        mesgul = true; defer { mesgul = false }
        do { return try await get("/rajon/pvp/target") }
        catch { hata = "Rakip yok, sonra dene"; return nil }
    }

    func sonucBildir(defenderID: String, won: Bool, loot: Int) async {
        let body: [String: Any] = ["defender_id": defenderID, "won": won, "loot": loot]
        if let r: AttackResp = try? await post("/rajon/pvp/result", body: body) {
            me = r.player
        }
    }

    // MARK: Lider tablosu

    func liderTablosu() async {
        do {
            let r: LeaderResp = try await get("/rajon/leaderboard")
            lider = r.top
            myRank = r.my_rank
        } catch { hata = "Lider tablosu alınamadı" }
    }

    // MARK: Çete / sendika

    func clanGetir() async {
        if let r: MineResp = try? await get("/rajon/clan/mine") { clanim = r.clan }
    }

    func clanListele() async {
        if let r: ClanListResp = try? await get("/rajon/clan/list") { clanListesi = r.clans }
    }

    func clanKur(ad: String, aciklama: String) async {
        mesgul = true; defer { mesgul = false }
        do {
            let r: MineResp = try await post("/rajon/clan/create", body: ["ad": ad, "aciklama": aciklama])
            clanim = r.clan; hata = nil
        } catch { hata = "Çete kurulamadı (isim alınmış olabilir)" }
    }

    func clanKatil(id: String) async {
        mesgul = true; defer { mesgul = false }
        if let r: MineResp = try? await post("/rajon/clan/join", body: ["clan_id": id]) {
            clanim = r.clan
        }
    }

    func clanCik() async {
        _ = try? await postRaw("/rajon/clan/leave", body: [:])
        clanim = nil
        clanSavas = nil
    }

    func clanBagis(_ miktar: Int) async {
        if let r: MineResp = try? await post("/rajon/clan/donate", body: ["amount": miktar]) {
            clanim = r.clan
        }
    }

    func clanSavasGetir() async {
        if let r: ClanSavasResp = try? await get("/rajon/clan/war") { clanSavas = r.war }
    }

    func clanSavasIlan(_ hedefId: String) async {
        if let r: ClanSavasResp = try? await post("/rajon/clan/war/declare", body: ["target_clan_id": hedefId]) {
            clanSavas = r.war
        }
    }

    // MARK: HTTP yardımcıları

    private func req(_ path: String, method: String, body: Data?, auth: Bool) throws -> URLRequest {
        var r = URLRequest(url: OnlineService.base.appendingPathComponent(path))
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        // ÖNEMLİ: Accept-Encoding'i ELLE AYARLAMA. Elle ayarlanırsa URLSession otomatik
        // gzip açmayı bırakır; yolda gzip varsa açılmamış bayt gelir ve HER yanıt decode
        // hatası verir. Boş bırakınca URLSession gzip'i şeffaf ve güvenilir yönetir.
        r.cachePolicy = .reloadIgnoringLocalCacheData      // bayat/kısmi önbellek yanıtı gelmesin
        if auth, let t = token { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let at = attestToken, !at.isEmpty { r.setValue(at, forHTTPHeaderField: "X-Attest-Token") }
        r.httpBody = body
        return r
    }

    /// Ortak: durum kodunu kontrol et, gövdeyi temizleyip çöz; olmazsa ham gövdeyi mesaja koy (teşhis).
    private func cozumle<T: Decodable>(_ d: Data, _ resp: URLResponse) throws -> T {
        let kod = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(kod) {
            let g = String(data: d.prefix(140), encoding: .utf8) ?? "?"
            throw APIError("HTTP \(kod): \(g)")
        }
        // 1) doğrudan dene
        if let v = try? JSONDecoder().decode(T.self, from: d) { return v }
        // 2) baştaki BOM / boşluk / çöp baytları temizleyip JSON'un başından dene
        //    (bazı ağ proxy'leri yanıta BOM veya önek ekliyor → decode patlıyor)
        if let acilis = d.firstIndex(where: { $0 == 0x7B || $0 == 0x5B }) {   // '{' veya '['
            let kirp = d.suffix(from: acilis)
            if let v = try? JSONDecoder().decode(T.self, from: kirp) { return v }
        }
        let g = String(data: d.prefix(140), encoding: .utf8) ?? "ikili/sıkıştırılmış yanıt (\(d.count)B)"
        throw APIError("Cevap çözülemedi [\(kod), \(d.count)B]: \(g)")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (d, r) = try await URLSession.shared.data(for: req(path, method: "GET", body: nil, auth: true))
        return try cozumle(d, r)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], auth: Bool = true) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        let (d, r) = try await URLSession.shared.data(for: req(path, method: "POST", body: data, auth: auth))
        return try cozumle(d, r)
    }

    @discardableResult
    private func postRaw(_ path: String, body: [String: Any]) async throws -> Data {
        let data = try JSONSerialization.data(withJSONObject: body)
        let (d, _) = try await URLSession.shared.data(for: req(path, method: "POST", body: data, auth: true))
        return d
    }

    // MARK: - SUNUCU-OTORİTER DÜNYA (tek paylaşılan dünya)

    @Published var dunya: DunyaView?
    @Published var dunyaAktif = false
    @Published var dunyaOyuncular: [LiderSatir] = []
    @Published var dunyaBilgi: String?
    @Published var sonSaldiri: (won: Bool, loot: Int)?

    /// Canlı dünyaya gir: bağlı değilse anonim giriş yap, durumu çek.
    /// Register (girisYap) başarısız olsa bile KAYITLI TOKEN varsa dünyayı çekmeyi dener —
    /// böylece geçici bir register hatası dünyaya girişi engellemez.
    func dunyayaGir() async {
        if !girisli { await girisYap(ad: ad.isEmpty ? "Patron" : ad) }
        guard girisli || token != nil else { return }
        dunyaAktif = true
        await dunyaCek()
        await dunyaHaritasi()
    }

    func dunyadanCik() { dunyaAktif = false }

    func dunyaCek() async {
        do {
            let v: DunyaView = try await get("/rajon/world/state")
            dunya = v; hata = nil
        } catch {
            hata = "Dünya yüklenemedi: \(error.localizedDescription)"
        }
    }

    /// Yükleme kilitlenirse: kimlik/token'ı temizle, sıfırdan (yeni anonim hesap) başla.
    func tamSifirla() {
        UserDefaults.standard.removeObject(forKey: "rajon_online_token")
        UserDefaults.standard.removeObject(forKey: "rajon_device_id")
        AuthService.sil()        // SMS token (iCloud)
        AuthService.anonSil()    // anonim cihaz+token (iCloud)
        UserDefaults.standard.removeObject(forKey: "rajon_attest_token")
        girisli = false; me = nil; dunya = nil; dunyaAktif = false; hata = nil
    }

    /// Attest token yoksa sağla (hassas aksiyon öncesi) — kullanıcı hata görmesin.
    private func attestGerekli() async {
        if (attestToken ?? "").isEmpty { await attestSaglat() }
    }

    /// Mutasyon aksiyonu: başarılıysa yeni dünya, hatadaysa mesaj.
    /// Attest garantili: token yoksa önce sağlar; 403 (attest) gelirse SESSİZCE yeniden attest edip 1 kez tekrar dener.
    private func dunyaAksiyon(_ path: String, _ body: [String: Any]) async {
        await attestGerekli()
        for deneme in 0..<2 {
            do {
                let r = try req(path, method: "POST", body: try JSONSerialization.data(withJSONObject: body), auth: true)
                let (data, resp) = try await URLSession.shared.data(for: r)
                if (resp as? HTTPURLResponse)?.statusCode == 403 && deneme == 0 {
                    await attestSaglat()      // token bayat/eksik → yenile, sessizce tekrar dene
                    continue
                }
                if let v = try? JSONDecoder().decode(DunyaView.self, from: data) {
                    dunya = v; dunyaBilgi = nil
                } else if let e = try? JSONDecoder().decode(DetailErr.self, from: data) {
                    dunyaBilgi = e.detail
                }
                return
            } catch { dunyaBilgi = "Bağlantı hatası"; return }
        }
    }

    func fraksiyonSec(_ kod: String) async { await dunyaAksiyon("/rajon/world/faction", ["kod": kod]) }

    func dunyaTopla() async { await dunyaAksiyon("/rajon/world/collect", [:]) }
    func dunyaIsletme(_ idx: Int) async { await dunyaAksiyon("/rajon/world/racket", ["idx": idx]) }
    func dunyaBina(_ tip: String) async { await dunyaAksiyon("/rajon/world/building", ["tip": tip]) }
    func dunyaFethet(_ kind: String, _ idx: Int) async { await dunyaAksiyon("/rajon/world/conquer", ["kind": kind, "idx": idx]) }
    func dunyaAsker(_ tip: String, _ count: Int) async { await dunyaAksiyon("/rajon/world/train", ["tip": tip, "count": count]) }

    func dunyaSaldir(_ targetId: String) async {
        await attestGerekli()
        for deneme in 0..<2 {
            do {
                let r = try req("/rajon/world/attack", method: "POST",
                                body: try JSONSerialization.data(withJSONObject: ["target_id": targetId]), auth: true)
                let (data, resp) = try await URLSession.shared.data(for: r)
                if (resp as? HTTPURLResponse)?.statusCode == 403 && deneme == 0 {
                    await attestSaglat(); continue
                }
                if let resp2 = try? JSONDecoder().decode(BaskinGonderResp.self, from: data) {
                    dunya = resp2.world
                    let dk = resp2.varis / 60, sn = resp2.varis % 60
                    let sure = dk > 0 ? "\(dk) dk \(sn) sn" : "\(sn) sn"
                    dunyaBilgi = "Ordu yola çıktı — \(sure) sonra varacak. Sonucu Ordu › Raporlar'da gör."
                    await baskinlariCek()
                } else if let e = try? JSONDecoder().decode(DetailErr.self, from: data) {
                    dunyaBilgi = e.detail
                }
                return
            } catch { dunyaBilgi = "Bağlantı hatası"; return }
        }
    }

    func dunyaHaritasi() async {
        if let m: DunyaMap = try? await get("/rajon/world/map") { dunyaOyuncular = m.players }
    }

    // MARK: - Zamanlı baskın + sezon + çete savaş odası
    @Published var gelenBaskin: [GelenAkin] = []
    @Published var gidenBaskin: [GidenBaskin] = []
    @Published var baskinRapor: [BaskinRapor] = []
    @Published var sezon: SezonBilgi?
    @Published var clanMesajlar: [ClanMesaj] = []
    @Published var clanHedefler: [ClanHedef] = []

    func baskinlariCek() async {
        if let r: GelenResp = try? await get("/rajon/world/raids/incoming") { gelenBaskin = r.gelen }
        if let r: GidenResp = try? await get("/rajon/world/raids/outgoing") { gidenBaskin = r.giden }
        if let r: RaporResp = try? await get("/rajon/world/raids/reports") { baskinRapor = r.raporlar }
    }
    func sezonCek() async { if let s: SezonBilgi = try? await get("/rajon/world/season") { sezon = s } }
    func clanChatCek() async { if let r: ChatResp = try? await get("/rajon/clan/chat") { clanMesajlar = r.mesajlar } }
    func clanChatGonder(_ mesaj: String) async {
        if let r: ChatResp = try? await post("/rajon/clan/chat", body: ["mesaj": mesaj]) { clanMesajlar = r.mesajlar }
    }
    func clanHedeflerCek() async { if let r: HedefResp = try? await get("/rajon/clan/targets") { clanHedefler = r.hedefler } }
    func clanHedefIsaretle(_ id: String) async {
        if let r: HedefResp = try? await post("/rajon/clan/target", body: ["target_id": id]) { clanHedefler = r.hedefler }
    }
    func clanHedefKaldir(_ id: String) async {
        if let r: HedefResp = try? await post("/rajon/clan/target/remove", body: ["target_id": id]) { clanHedefler = r.hedefler }
    }

    // MARK: - Derin özellikler: takviye, casus, kaynak, farm, sıralama, görev
    @Published var takviyeGelen: [TakviyeGelen] = []
    @Published var takviyeGiden: [TakviyeGiden] = []
    @Published var casusSonuc: CasusSonuc?
    @Published var farmHedefler: [FarmHedef] = []
    @Published var siralama: Siralamalar?
    @Published var gorevler: [GunlukGorev] = []
    @Published var uslerim: [Us] = []
    @Published var usLimit: Int = 0
    @Published var dusmanUsler: [DusmanUs] = []
    @Published var hero: HeroBilgi?
    @Published var pazarIlanlar: [PazarIlan] = []
    @Published var pazarBenim: [PazarIlan] = []
    @Published var diplomasi: DiplomasiDurum?
    @Published var demirci: Demirci?
    @Published var harika: HarikaDurum?
    @Published var birimKatalog: [BirimBilgi] = []

    func takviyeGonder(_ target: String, t: Int, k: Int, s: Int) async {
        await dunyaAksiyon("/rajon/world/reinforce", ["target_id": target, "tetikci": t, "kabadayi": k, "sofor": s])
        await takviyeBilgiCek()
    }
    func takviyeGeriCek() async { await dunyaAksiyon("/rajon/world/reinforce/recall", [:]); await takviyeBilgiCek() }
    func takviyeBilgiCek() async {
        if let r: TakviyeResp = try? await get("/rajon/world/reinforce/info") { takviyeGelen = r.gelen; takviyeGiden = r.giden }
    }
    func casusGonder(_ target: String) async {
        do {
            let r = try req("/rajon/world/scout", method: "POST",
                            body: try JSONSerialization.data(withJSONObject: ["target_id": target]), auth: true)
            let (data, _) = try await URLSession.shared.data(for: r)
            if let s = try? JSONDecoder().decode(CasusSonuc.self, from: data) { casusSonuc = s; if let w = s.world { dunya = w }; dunyaBilgi = nil }
            else if let e = try? JSONDecoder().decode(DetailErr.self, from: data) { dunyaBilgi = e.detail }
        } catch { dunyaBilgi = "Bağlantı hatası" }
    }
    func kaynakGonder(_ target: String, cash: Int, cephane: Int) async {
        await dunyaAksiyon("/rajon/world/send", ["target_id": target, "cash": cash, "cephane": cephane])
    }
    func farmCek() async { if let r: FarmResp = try? await get("/rajon/world/farm") { farmHedefler = r.liste } }
    func farmEkle(_ id: String) async { if let r: FarmResp = try? await post("/rajon/world/farm/add", body: ["target_id": id]) { farmHedefler = r.liste } }
    func farmKaldir(_ id: String) async { if let r: FarmResp = try? await post("/rajon/world/farm/remove", body: ["target_id": id]) { farmHedefler = r.liste } }
    func farmAkin() async { await dunyaAksiyon("/rajon/world/farm/raid", [:]); await baskinlariCek() }
    func siralamaCek() async { if let s: Siralamalar = try? await get("/rajon/world/rankings") { siralama = s } }
    func gorevlerCek() async { if let r: GorevResp = try? await get("/rajon/world/quests") { gorevler = r.gorevler } }
    func gorevOdulAl(_ tip: String) async { await dunyaAksiyon("/rajon/world/quest/claim", ["tip": tip]); await gorevlerCek() }

    // MARK: - Çoklu üs + fetih (outpost / conquest)
    func uslerimCek() async {
        if let r: UslerimResp = try? await get("/rajon/world/bases") { uslerim = r.usler; usLimit = r.limit }
    }
    func dusmanUsleriCek() async {
        if let r: DusmanUslerResp = try? await get("/rajon/world/bases/enemy") { dusmanUsler = r.usler }
    }
    func usKur() async { await dunyaAksiyon("/rajon/world/base/found", [:]); await uslerimCek() }
    func usHasat() async { await dunyaAksiyon("/rajon/world/base/harvest", [:]); await uslerimCek() }
    func usGarnizonGonder(_ id: Int, _ ordu: [String: Int]) async {
        var body: [String: Any] = ["us_id": id]
        for (k, v) in ordu { body[k] = v }
        await dunyaAksiyon("/rajon/world/base/garrison", body); await uslerimCek()
    }
    func usGarnizonCek(_ id: Int) async { await dunyaAksiyon("/rajon/world/base/garrison/recall", ["us_id": id]); await uslerimCek() }
    func usSaldir(_ id: Int) async {
        await dunyaAksiyon("/rajon/world/base/attack", ["us_id": id]); await dusmanUsleriCek(); await baskinlariCek()
    }

    // MARK: - Kahraman + macera + eşya
    func heroCek() async { if let h: HeroBilgi = try? await get("/rajon/world/hero") { hero = h } }
    func heroYetenek(_ alan: String) async {
        if let r: HeroResp = try? await post("/rajon/world/hero/skill", body: ["alan": alan]) {
            hero = r.hero; if let w = r.world { dunya = w }
        }
    }
    func maceraBaslat(_ zorluk: String) async {
        if let r: HeroResp = try? await post("/rajon/world/hero/adventure", body: ["zorluk": zorluk]) { hero = r.hero }
    }
    func maceraTopla() async {
        if let r: HeroResp = try? await post("/rajon/world/hero/adventure/collect", body: [:]) {
            hero = r.hero; if let w = r.world { dunya = w }
            if let e = r.esya { dunyaBilgi = "Maceradan eşya düştü: \(e.ad)!" }
        }
    }
    func esyaTak(_ id: Int) async {
        if let r: HeroResp = try? await post("/rajon/world/hero/item/equip", body: ["item_id": id]) { hero = r.hero; if let w = r.world { dunya = w } }
    }
    func esyaCikar(_ id: Int) async {
        if let r: HeroResp = try? await post("/rajon/world/hero/item/unequip", body: ["item_id": id]) { hero = r.hero; if let w = r.world { dunya = w } }
    }

    // MARK: - Pazar (marketplace)
    func pazarCek() async { if let r: PazarListe = try? await get("/rajon/world/market") { pazarIlanlar = r.ilanlar; pazarBenim = r.benim } }
    func pazarEkle(ver: String, verMik: Int, iste: String, isteMik: Int) async {
        await dunyaAksiyon("/rajon/world/market/post",
            ["ver_tip": ver, "ver_miktar": verMik, "iste_tip": iste, "iste_miktar": isteMik]); await pazarCek()
    }
    func pazarKabul(_ id: Int) async { await dunyaAksiyon("/rajon/world/market/accept", ["id": id]); await pazarCek() }
    func pazarIptal(_ id: Int) async { await dunyaAksiyon("/rajon/world/market/cancel", ["id": id]); await pazarCek() }

    // MARK: - Diplomasi (çete-çete)
    func diplomasiCek() async { if let d: DiplomasiDurum = try? await get("/rajon/world/diplomacy") { diplomasi = d } }
    func diplomasiTeklif(_ hedef: String, durum: String) async {
        if let r: DiplomasiResp = try? await post("/rajon/world/diplomacy/offer", body: ["hedef_clan": hedef, "durum": durum]) { diplomasi = r.diplomasi }
    }
    func diplomasiBoz(_ hedef: String) async {
        if let r: DiplomasiResp = try? await post("/rajon/world/diplomacy/break", body: ["hedef_clan": hedef]) { diplomasi = r.diplomasi }
    }

    // MARK: - Demirci (birlik yükseltme)
    func demirciCek() async { if let d: Demirci = try? await get("/rajon/world/smithy") { demirci = d } }
    func demirciYukselt(_ tip: String) async {
        if let r: DemirciResp = try? await post("/rajon/world/smithy/upgrade", body: ["tip": tip]) {
            demirci = r.demirci; if let w = r.world { dunya = w }
        }
    }

    // MARK: - Tam köy yönetimi (bağımsız köyler)
    @Published var aktifKoy: KoyView?
    func koyGor(_ bid: Int) async { if let v: KoyView = try? await get("/rajon/world/village/\(bid)") { aktifKoy = v } }
    func koyTopla(_ bid: Int) async { if let v: KoyView = try? await post("/rajon/world/village/collect", body: ["us_id": bid]) { aktifKoy = v } }
    func koyBina(_ bid: Int, _ tip: String) async { if let v: KoyView = try? await post("/rajon/world/village/building", body: ["us_id": bid, "tip": tip]) { aktifKoy = v } }
    func koyAsker(_ bid: Int, _ tip: String, _ count: Int) async { if let v: KoyView = try? await post("/rajon/world/village/train", body: ["us_id": bid, "tip": tip, "count": count]) { aktifKoy = v } }

    // MARK: - Birlik kataloğu (savaş derinliği)
    func birimKatalogCek() async {
        if birimKatalog.isEmpty, let r: BirimKatalogResp = try? await get("/rajon/world/units") { birimKatalog = r.birimler }
    }

    // MARK: - Dünya Harikası (endgame)
    func harikaCek() async { if let h: HarikaDurum = try? await get("/rajon/world/wonder") { harika = h } }
    func harikaKatki(_ amount: Int) async {
        if let r: HarikaResp = try? await post("/rajon/world/wonder/contribute", body: ["amount": amount]) {
            harika = r.harika; if let w = r.world { dunya = w }
            if r.zafer == true { dunyaBilgi = "👑 ÇETEN DÜNYA HARİKASINI TAMAMLADI — SEZON ZAFERİ!" }
            else if let e = r.yeniEser, !e.isEmpty { dunyaBilgi = "Eser kazanıldı: \(e.joined(separator: ", "))" }
        }
    }

    // MARK: - App Attest (yalnızca gerçek cihaz+uygulama erişebilsin)

    private var attestToken: String? {
        get { UserDefaults.standard.string(forKey: "rajon_attest_token") }
        set { UserDefaults.standard.setValue(newValue, forKey: "rajon_attest_token") }
    }

    /// Cihaz gerçekliğini App Attest ile kanıtla ve GEÇERLİ attest token'ı al.
    /// Tek çağrıda garanti eder: assert başarısızsa aynı turda verify'a düşer (bayat token bırakmaz).
    /// Okuma uçları açık olduğu için akışı bloklamaz; token yazma-aksiyonlarına yetişir.
    private var attestDevam = false
    func attestSaglat() async {
        guard AppAttest.destekli, !attestDevam else { return }
        attestDevam = true
        defer { attestDevam = false }
        for _ in 0..<3 {
            do {
                let ch: AttestChallengeResp = try await post("/rajon/attest/challenge", body: [:], auth: false)
                guard let chData = Data(base64Encoded: ch.challenge) else { return }
                if AppAttest.attestEdildi {
                    let (kid, assertion) = try await AppAttest.assert(challenge: chData)
                    let r: AttestTokenResp = try await post("/rajon/attest/assert",
                        body: ["key_id": kid, "assertion": assertion.base64EncodedString(), "challenge": ch.challenge], auth: false)
                    attestToken = r.attest_token
                } else {
                    let (kid, att) = try await AppAttest.attest(challenge: chData)
                    let r: AttestTokenResp = try await post("/rajon/attest/verify",
                        body: ["key_id": kid, "attestation": att.base64EncodedString(), "challenge": ch.challenge], auth: false)
                    attestToken = r.attest_token
                    AppAttest.attestEdildi = true
                }
                return   // geçerli token alındı
            } catch {
                // assert başarısız / anahtar geçersiz (reinstall) → sıfırla, sonraki tur verify (taze anahtar)
                AppAttest.sifirla()
            }
        }
    }

    /// Çete hazinesine bağış — dünya nakdinden otoriter düşülür, sonra çete tazelenir.
    func dunyaClanBagis(_ miktar: Int) async {
        await dunyaAksiyon("/rajon/world/clan_donate", ["amount": miktar])
        await clanGetir()
    }
}

/// Ağ/decode hatalarını okunur mesajla taşıyan hata tipi (yükleme ekranında gösterilir).
struct APIError: LocalizedError {
    let mesaj: String
    init(_ mesaj: String) { self.mesaj = mesaj }
    var errorDescription: String? { mesaj }
}

// MARK: - Dünya modelleri (world.view JSON ile birebir)
struct DetailErr: Codable { let detail: String }

struct DunyaView: Codable {
    let cash, idle, cephane, respect, bossLevel, incomePerMin: Int
    let depoKapasite, cephaneMax, cephaneUretimDk, maxKadro, nufuzKapasite, nufuzKullanim: Int
    let rackets: [DRacket]
    let buildings: [DBina]
    let insaatMesgul: Bool
    let regions: [DBolge]
    let oases: [DVaha]
    let army: [String: Int]
    let train: DTrain?
    var gelenBaskin: Int? = nil     // bana gelen (yolda) baskın sayısı → savunma uyarısı
    var fraksiyon: String? = nil
    var fraksiyonlar: [FraksiyonSecim]? = nil
    var usSayisi: Int? = nil        // ek üs (outpost) sayısı
    var usLimit: Int? = nil         // kurulabilir ek üs hakkı (karargah nüfuzu)
    var idameDk: Int? = nil         // ordunun dakikalık besleme gideri
    var konakSadakat: Int? = nil    // başkent sadakati (düşman şefi düşürür → 0'da fetih)
}
struct FraksiyonSecim: Codable, Identifiable { let kod: String; let ad: String; let bonus: String; var id: String { kod } }
struct Us: Codable, Identifiable {
    let id: Int; let ad: String; let ana: Bool; let sadakat: Int; let gelir: Int; let kasa: Int
    let garrison: [String: Int]
    var lat: Double? = nil; var lon: Double? = nil
}
struct DusmanUs: Codable, Identifiable {
    let id: Int; let sahip: String; let ad: String; let lat: Double; let lon: Double
    let sadakat: Int; let uzaklik: Int
}
struct UslerimResp: Codable { let usler: [Us]; let limit: Int; let kurulu: Int }
struct KoyView: Codable {
    let id: Int; let ad: String; let cash: Int; let idle: Int; let cephane: Int
    let incomePerMin: Int; let depoKapasite: Int; let cephaneMax: Int; let maxKadro: Int
    let buildings: [DBina]; let insaatMesgul: Bool
    let army: [String: Int]; var train: DTrain? = nil; let savunma: Int
}
struct DusmanUslerResp: Codable { let usler: [DusmanUs] }

struct HeroBilgi: Codable {
    let ad: String; let level: Int; let xp: Int; let xpGerek: Int
    let sp: Int; let savas: Int; let liderlik: Int; let servet: Int
    let evde: Bool; let atkBonus: Int; let defBonus: Int; let gelirBonus: Int
    var macera: HeroMacera? = nil
    let zorluklar: [HeroZorluk]
    let esyalar: [HeroEsya]
}
struct HeroMacera: Codable { let tip: String; let zorluk: String; let kalan: Int; let biterMi: Bool }
struct HeroZorluk: Codable, Identifiable { let kod: String; let sure: Int; let cash: Int; let xp: Int; let itemSans: Int; var id: String { kod } }
struct HeroEsya: Codable, Identifiable { let id: Int; let slot: String; let ad: String; let bonusTip: String; let bonus: Int; let nadir: String; let takili: Bool }
struct HeroResp: Codable { var hero: HeroBilgi? = nil; var world: DunyaView? = nil; var esya: HeroEsya? = nil }

struct PazarIlan: Codable, Identifiable {
    let id: Int; let satici: String; let verTip: String; let verMiktar: Int; let isteTip: String; let isteMiktar: Int
}
struct PazarListe: Codable { let ilanlar: [PazarIlan]; let benim: [PazarIlan] }
struct DiplomasiIliski: Codable, Identifiable {
    let clan: String; let durum: String; let onayli: Bool; let bekleyen: Bool
    var id: String { clan }
}
struct DiplomasiDurum: Codable { let clan: String; let iliskiler: [DiplomasiIliski] }
struct DiplomasiResp: Codable { var diplomasi: DiplomasiDurum? = nil }

struct DemirciBirim: Codable, Identifiable {
    let tip: String; let seviye: Int; let maks: Int; let cash: Int; let cephane: Int; let bonus: Int; let acik: Bool
    var id: String { tip }
}
struct Demirci: Codable { let birimler: [DemirciBirim] }
struct DemirciResp: Codable { var demirci: Demirci? = nil; var world: DunyaView? = nil }

struct HarikaEser: Codable, Identifiable { let kod: String; let ad: String; var id: String { kod } }
struct HarikaSira: Codable, Identifiable { let clan: String; let seviye: Int; var id: String { clan } }
struct HarikaDurum: Codable {
    let clan: String; let seviye: Int; let maks: Int; let biriken: Int
    let sonrakiMaliyet: Int; let toplam: Int
    let eserler: [HarikaEser]; let siralama: [HarikaSira]
}
struct HarikaResp: Codable {
    var harika: HarikaDurum? = nil; var world: DunyaView? = nil
    var zafer: Bool? = nil; var yeniEser: [String]? = nil
}

struct BirimBilgi: Codable, Identifiable {
    let tip: String; let ad: String; let saldiri: Int; let tur: String
    let defPiyade: Int; let defSuvari: Int; let yagma: Int; let rol: String
    var id: String { tip }
}
struct BirimKatalogResp: Codable { let birimler: [BirimBilgi] }
struct DRacket: Codable, Identifiable { let idx: Int; let ad: String; let owned: Bool; let tier: Int; let perMin: Int; let fiyat: Int; var id: Int { idx } }
struct DBina: Codable, Identifiable { let tip: String; let seviye: Int; let fiyat: Int; let sure: Int; let insaatta: Bool; let kalan: Int; var id: String { tip } }
struct DBolge: Codable, Identifiable { let idx: Int; let ad: String; let gelirDk: Int; let owned: Bool; let fiyat: Int; let sure: Int; let fetihte: Bool; let kalan: Int; var id: Int { idx } }
struct DVaha: Codable, Identifiable { let idx: Int; let ad: String; let tip: String; let bonusDk: Int; let owned: Bool; let fiyat: Int; let sure: Int; let fetihte: Bool; let kalan: Int; var id: Int { idx } }
struct DTrain: Codable { let tip: String; let count: Int; let kalan: Int }
struct DunyaAttackResp: Codable { let won: Bool; let loot: Int; let world: DunyaView }
struct DunyaMap: Codable { let me: String; let players: [LiderSatir] }

// MARK: - Modeller

struct OnlinePlayer: Codable {
    let id: String
    let ad: String
    let power: Int
    let respect: Int
    let cash: Int
    let wins: Int
    let losses: Int
    let def_wins: Int
    let def_losses: Int
    var lat: Double? = nil      // gerçek dünya şehir koordinatı (sunucudan)
    var lon: Double? = nil
}

// Zamanlı baskın + sezon + çete savaş odası modelleri (GelenAkin — eski GelenBaskin ile çakışmasın)
struct GelenAkin: Codable, Identifiable { let saldiran: String; let buyukluk: String; let kalan: Int; var id: String { saldiran + "\(kalan)" } }
struct GidenBaskin: Codable, Identifiable { let hedef: String; let durum: String; let kalan: Int; var id: String { hedef + durum + "\(kalan)" } }
struct BaskinRapor: Codable, Identifiable { let tur: String; let rakip: String; let kazandim: Bool; let yagma: Int; let ts: Double; var id: Double { ts } }
struct GelenResp: Codable { let gelen: [GelenAkin] }
struct GidenResp: Codable { let giden: [GidenBaskin] }
struct RaporResp: Codable { let raporlar: [BaskinRapor] }
struct SezonSatir: Codable, Identifiable { let ad: String; let skor: Int; var id: String { ad } }
struct OnurSatir: Codable, Identifiable { let sezon: Int; let ad: String; let skor: Int; var id: Int { sezon } }
struct SezonBilgi: Codable { let no: Int; let kalan: Int; let benimSkor: Int; let top: [SezonSatir]; let onur: [OnurSatir] }
struct ClanMesaj: Codable, Identifiable { let ad: String; let mesaj: String; let ts: Double; var id: Double { ts } }
struct ClanHedef: Codable, Identifiable { let id: String; let ad: String; let guc: Int; let isaretleyen: String }
struct ChatResp: Codable { let mesajlar: [ClanMesaj] }
struct HedefResp: Codable { let hedefler: [ClanHedef] }

// Derin özellik modelleri
struct TakviyeGelen: Codable, Identifiable { let kim: String; let savunma: Int; var id: String { kim + "\(savunma)" } }
struct TakviyeGiden: Codable, Identifiable { let nerede: String; let asker: Int; var id: String { nerede + "\(asker)" } }
struct TakviyeResp: Codable { let gelen: [TakviyeGelen]; let giden: [TakviyeGiden] }
struct CasusSonuc: Codable { let ad: String; let army: [String: Int]; let savunma: Int; let korunak: Int; let nakit: Int; var world: DunyaView? = nil }
struct FarmHedef: Codable, Identifiable { let id: String; let ad: String; let guc: Int; let kalkanli: Bool }
struct FarmResp: Codable { let liste: [FarmHedef] }
struct SiraSatir: Codable, Identifiable { let ad: String; let deger: Int; var id: String { ad } }
struct Siralamalar: Codable { let saldirgan: [SiraSatir]; let savunmaci: [SiraSatir]; let cete: [SiraSatir] }
struct GunlukGorev: Codable, Identifiable { let tip: String; let ad: String; let hedef: Int; let ilerleme: Int; let tamam: Bool; let alindi: Bool; let odul: Int; var id: String { tip } }
struct GorevResp: Codable { let gorevler: [GunlukGorev] }
struct BaskinGonderResp: Codable { let gonderildi: Bool; let varis: Int; let world: DunyaView }

struct AttestChallengeResp: Codable { let challenge: String }
struct AttestTokenResp: Codable { let attest_token: String; var env: String? = nil; var ttl: Int? = nil }

struct RegisterResp: Codable { let token: String; let player: OnlinePlayer }
struct MeResp: Codable { let player: OnlinePlayer }
struct OkResp: Codable { let ok: Bool }
struct SmsVerifyResp: Codable { let token: String; let player: OnlinePlayer; let state: String }
struct AttackResp: Codable { let ok: Bool; let won: Bool; let loot: Int; let player: OnlinePlayer }

struct PvpTarget: Codable, Identifiable {
    let id: String
    let ad: String
    let power: Int
    let respect: Int
    let loot: Int
    let crew: [CrewSnap]
}

struct CrewSnap: Codable {
    let ad: String
    let rarity: Int
    let klas: String
    let level: Int
    let maxHP: Int
    let atk: Int
    let spd: Int

    /// Snapshot'ı dövüş için Enforcer'a çevir (statlar rarity+klas+level'den yeniden hesaplanır).
    func toEnforcer() -> Enforcer {
        let r = Rarity(rawValue: rarity) ?? .sokak
        return Enforcer(
            ad: ad,
            rarity: r,
            klas: Klas(rawValue: klas) ?? .yumruk,
            level: level,
            taunt: Argo.taunt(for: r)
        )
    }
}

struct LiderSatir: Codable, Identifiable {
    let id: String
    let ad: String
    let power: Int
    let respect: Int
    let wins: Int
    let def_wins: Int
    var lat: Double? = nil      // gerçek dünya şehir koordinatı (sunucudan)
    var lon: Double? = nil
}

struct LeaderResp: Codable { let top: [LiderSatir]; let me: String; let my_rank: Int? }

// MARK: Çete

struct ClanMember: Codable, Identifiable {
    let id: String
    let ad: String
    let power: Int
    let respect: Int
    let wins: Int
}

struct Clan: Codable {
    let id: String
    let ad: String
    let aciklama: String
    let lider: String
    let lider_mi: Bool
    let uye: Int
    let toplam_respect: Int
    let toplam_guc: Int
    var hazine: Int? = nil
    var savas_galibi: Int? = nil
    let members: [ClanMember]
}

struct ClanSavas: Codable {
    let benim_skor: Int
    let rakip_skor: Int
    let rakip_ad: String
    let bitis: Double
}
struct ClanSavasResp: Codable { let war: ClanSavas? }

struct ClanOzet: Codable, Identifiable {
    let id: String
    let ad: String
    let aciklama: String
    let lider: String
    let uye: Int
    let toplam_respect: Int
    let toplam_guc: Int
}

struct MineResp: Codable { let clan: Clan? }
struct ClanListResp: Codable { let clans: [ClanOzet] }

// Sana gelen baskınlar
struct GelenBaskin: Codable, Identifiable {
    var id: Double { ts }      // ts benzersiz-ish
    let attacker_ad: String
    let won: Int
    let loot: Int
    let ts: Double
}
struct GelenBaskinResp: Codable { let raids: [GelenBaskin] }
