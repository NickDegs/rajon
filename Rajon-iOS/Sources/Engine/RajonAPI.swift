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
    @Published var hata: String?
    @Published var mesgul = false

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "rajon_online_token") }
        set { UserDefaults.standard.set(newValue, forKey: "rajon_online_token") }
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
        guard token != nil else { return }
        // token varsa profili tazele (register idempotent, aynı token döner)
        await girisYap(ad: ad.isEmpty ? "Patron" : ad)
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
        ]
        _ = try? await postRaw("/rajon/sync", body: body)
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
}

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
