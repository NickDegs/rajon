import SwiftUI

/// Online mod istemcisi — anonim hesap, ekip sync, PvP, lider tablosu.
@MainActor
final class OnlineService: ObservableObject {
    static let base = URL(string: "https://nickdegs.duckdns.org/rajon-api")!

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

    /// Önce iCloud Keychain'deki SMS token'ı (varsa), yoksa anonim cihaz token'ı.
    private var token: String? {
        get { AuthService.token ?? UserDefaults.standard.string(forKey: "rajon_online_token") }
        set { UserDefaults.standard.set(newValue, forKey: "rajon_online_token") }
    }
    /// Daha önce (anonim veya SMS) hesap oluşturulmuş mu — ilk açılış rumuz ekranı için.
    var hesapVar: Bool {
        AuthService.token != nil || UserDefaults.standard.string(forKey: "rajon_online_token") != nil
    }
    private var deviceID: String {
        if let id = UserDefaults.standard.string(forKey: "rajon_device_id") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "rajon_device_id")
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
        if auth, let t = token { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        r.httpBody = body
        return r
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (d, _) = try await URLSession.shared.data(for: req(path, method: "GET", body: nil, auth: true))
        return try JSONDecoder().decode(T.self, from: d)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], auth: Bool = true) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        let (d, _) = try await URLSession.shared.data(for: req(path, method: "POST", body: data, auth: auth))
        return try JSONDecoder().decode(T.self, from: d)
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
    func dunyayaGir() async {
        if !girisli { await girisYap(ad: ad.isEmpty ? "Patron" : ad) }
        guard girisli else { return }
        dunyaAktif = true
        await dunyaCek()
        await dunyaHaritasi()
    }

    func dunyadanCik() { dunyaAktif = false }

    func dunyaCek() async {
        if let v: DunyaView = try? await get("/rajon/world/state") { dunya = v }
    }

    /// Mutasyon aksiyonu: başarılıysa yeni dünya, hatadaysa mesaj.
    private func dunyaAksiyon(_ path: String, _ body: [String: Any]) async {
        do {
            let r = try req(path, method: "POST", body: try JSONSerialization.data(withJSONObject: body), auth: true)
            let (data, _) = try await URLSession.shared.data(for: r)
            if let v = try? JSONDecoder().decode(DunyaView.self, from: data) {
                dunya = v; dunyaBilgi = nil
            } else if let e = try? JSONDecoder().decode(DetailErr.self, from: data) {
                dunyaBilgi = e.detail
            }
        } catch { dunyaBilgi = "Bağlantı hatası" }
    }

    func dunyaTopla() async { await dunyaAksiyon("/rajon/world/collect", [:]) }
    func dunyaIsletme(_ idx: Int) async { await dunyaAksiyon("/rajon/world/racket", ["idx": idx]) }
    func dunyaBina(_ tip: String) async { await dunyaAksiyon("/rajon/world/building", ["tip": tip]) }
    func dunyaFethet(_ kind: String, _ idx: Int) async { await dunyaAksiyon("/rajon/world/conquer", ["kind": kind, "idx": idx]) }
    func dunyaAsker(_ tip: String, _ count: Int) async { await dunyaAksiyon("/rajon/world/train", ["tip": tip, "count": count]) }

    func dunyaSaldir(_ targetId: String) async {
        do {
            let r = try req("/rajon/world/attack", method: "POST",
                            body: try JSONSerialization.data(withJSONObject: ["target_id": targetId]), auth: true)
            let (data, _) = try await URLSession.shared.data(for: r)
            if let resp = try? JSONDecoder().decode(DunyaAttackResp.self, from: data) {
                dunya = resp.world; sonSaldiri = (resp.won, resp.loot); dunyaBilgi = nil
            } else if let e = try? JSONDecoder().decode(DetailErr.self, from: data) {
                dunyaBilgi = e.detail
            }
        } catch { dunyaBilgi = "Bağlantı hatası" }
    }

    func dunyaHaritasi() async {
        if let m: DunyaMap = try? await get("/rajon/world/map") { dunyaOyuncular = m.players }
    }
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
}
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
}

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
