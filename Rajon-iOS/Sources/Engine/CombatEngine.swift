import SwiftUI
import Combine

/// Dövüşteki tek bir savaşçının canlı durumu.
struct Combatant: Identifiable {
    let id: UUID
    let ad: String
    let rarity: Rarity
    let klas: Klas
    let maxHP: Int
    var hp: Int
    let atk: Int
    let spd: Int
    let taunt: String
    let isPlayer: Bool
    var energy: Int = 0          // 0..100, 100'de özel hamle
    var alive: Bool { hp > 0 }

    init(from e: Enforcer, isPlayer: Bool) {
        id = e.id; ad = e.ad; rarity = e.rarity; klas = e.klas
        maxHP = e.maxHP; hp = e.maxHP; atk = e.atk; spd = e.spd
        taunt = e.taunt; self.isPlayer = isPlayer
    }
}

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let kind: Kind
    enum Kind { case info, hasar, ozel, taunt, zafer, yenilgi }
}

enum CombatResult { case devam, kazandi, kaybetti }

/// Tur tabanlı dövüş motoru.
@MainActor
final class CombatEngine: ObservableObject {
    @Published var player: [Combatant] = []
    @Published var enemy: [Combatant] = []
    @Published var log: [LogLine] = []
    @Published var result: CombatResult = .devam
    @Published var siradaki: UUID?            // sırası gelen savaşçı
    @Published var oyuncununSirasi = false
    @Published var hedefSecimi = false        // oyuncu özel hamle için hedef mi seçiyor
    @Published var bekleyenOzel = false
    @Published var sallananID: UUID?          // hasar alan animasyonu

    let node: RivalNode
    private var order: [UUID] = []            // tur sırası (hıza göre)
    private var orderIdx = 0
    private var aktifOyuncuID: UUID?
    private var kuruldu = false

    init(node: RivalNode, squad: [Enforcer]) {
        self.node = node
        if !squad.isEmpty { kur(squad: squad) }
    }

    /// Ekibi yerleştirip dövüşü başlatır. environmentObject init'te erişilemediği
    /// için CombatView bunu onAppear'da çağırır.
    func kur(squad: [Enforcer]) {
        guard !kuruldu, !squad.isEmpty else { return }
        kuruldu = true
        player = squad.map { Combatant(from: $0, isPlayer: true) }
        enemy = node.crew.map { Combatant(from: $0, isPlayer: false) }
        rebuildOrder()
        ekle("Çatışma başladı: \(node.ad)", .info)
        nextTurn()
    }

    var hayattaOyuncuIDleri: [UUID] { player.filter { $0.alive }.map { $0.id } }

    private func rebuildOrder() {
        let hepsi = (player + enemy).filter { $0.alive }
        order = hepsi.sorted { $0.spd > $1.spd }.map { $0.id }
        orderIdx = 0
    }

    private func combatant(_ id: UUID) -> Combatant? {
        player.first { $0.id == id } ?? enemy.first { $0.id == id }
    }

    private func indexOf(_ id: UUID) -> (Bool, Int)? {
        if let i = player.firstIndex(where: { $0.id == id }) { return (true, i) }
        if let i = enemy.firstIndex(where: { $0.id == id }) { return (false, i) }
        return nil
    }

    // MARK: Tur akışı

    private func nextTurn() {
        guard result == .devam else { return }
        if biterMi() { return }

        // sırada canlı savaşçı bul
        var guard0 = 0
        while guard0 < order.count {
            if orderIdx >= order.count { rebuildOrder() }
            let id = order[orderIdx]
            orderIdx += 1
            guard0 += 1
            guard let c = combatant(id), c.alive else { continue }

            siradaki = id
            if c.isPlayer {
                oyuncununSirasi = true
                aktifOyuncuID = id
                bekleyenOzel = c.energy >= 100
                return
            } else {
                oyuncununSirasi = false
                // düşman hamlesi gecikmeli
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                    self?.dusmanHamlesi(id)
                }
                return
            }
        }
        rebuildOrder()
        nextTurn()
    }

    private func ilerle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.nextTurn()
        }
    }

    // MARK: Oyuncu aksiyonları

    /// Normal saldırı — otomatik en zayıf düşmanı hedefler.
    func saldir() {
        guard oyuncununSirasi, let aid = aktifOyuncuID else { return }
        guard let hedef = enZayif(enemy) else { return }
        vur(from: aid, to: hedef, ozel: false)
        oyuncununSirasi = false
        ilerle()
    }

    /// Özel hamle başlat (hedef seçimine geçer).
    func ozelBaslat() {
        guard oyuncununSirasi, let aid = aktifOyuncuID,
              let c = combatant(aid), c.energy >= 100 else { return }
        hedefSecimi = true
    }

    func ozelHedefSec(_ hedefID: UUID) {
        guard hedefSecimi, let aid = aktifOyuncuID else { return }
        hedefSecimi = false
        vur(from: aid, to: hedefID, ozel: true)
        // enerji sıfırla
        if let (_, i) = indexOf(aid) { player[i].energy = 0 }
        oyuncununSirasi = false
        ilerle()
    }

    func ozelIptal() { hedefSecimi = false }

    // MARK: Düşman AI

    private func dusmanHamlesi(_ id: UUID) {
        guard result == .devam, let c = combatant(id), c.alive else { ilerle(); return }
        guard let hedef = enZayif(player) else { ilerle(); return }
        let ozel = c.energy >= 100
        if Bool.random() || ozel {
            ekle("\(c.ad): \"\(c.taunt)\"", .taunt)
        }
        vur(from: id, to: hedef, ozel: ozel)
        if ozel, let (_, i) = indexOf(id) { enemy[i].energy = 0 }
        ilerle()
    }

    // MARK: Vuruş çözümü

    private func vur(from: UUID, to: UUID, ozel: Bool) {
        guard let attacker = combatant(from), let _ = combatant(to) else { return }
        let varyans = Double.random(in: 0.85...1.15)
        let kritik = Double.random(in: 0...1) < 0.18
        var hasar = Double(attacker.atk) * varyans
        if ozel { hasar *= 2.2 }
        if kritik { hasar *= 1.6 }
        let h = max(1, Int(hasar))

        guard let (hedefOyuncu, hi) = indexOf(to) else { return }
        if hedefOyuncu {
            player[hi].hp = max(0, player[hi].hp - h)
        } else {
            enemy[hi].hp = max(0, enemy[hi].hp - h)
        }
        let hedefAd = combatant(to)?.ad ?? "?"

        // enerji kazan (vuran + biraz da vurulan)
        if let (ap, ai) = indexOf(from) {
            if ap { player[ai].energy = min(100, player[ai].energy + (ozel ? 0 : 35)) }
            else  { enemy[ai].energy = min(100, enemy[ai].energy + (ozel ? 0 : 30)) }
        }
        if hedefOyuncu { player[hi].energy = min(100, player[hi].energy + 12) }
        else { enemy[hi].energy = min(100, enemy[hi].energy + 12) }

        let etiket = ozel ? "ÖZEL" : (kritik ? "KRİTİK" : "")
        let mesaj = "\(attacker.ad) → \(hedefAd) \(etiket.isEmpty ? "" : "[\(etiket)] ")-\(h)"
        ekle(mesaj, ozel ? .ozel : .hasar)

        sallananID = to
        Haptics.vurus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            if self?.sallananID == to { self?.sallananID = nil }
        }

        // ölüm kontrolü
        if let c = combatant(to), !c.alive {
            ekle("\(c.ad) yere serildi.", .info)
        }
        _ = biterMi()
    }

    // MARK: Yardımcılar

    private func enZayif(_ taraf: [Combatant]) -> UUID? {
        taraf.filter { $0.alive }.min { $0.hp < $1.hp }?.id
    }

    @discardableResult
    private func biterMi() -> Bool {
        if result != .devam { return true }
        if enemy.allSatisfy({ !$0.alive }) {
            result = .kazandi
            ekle(Argo.zaferLaf.randomElement()!, .zafer)
            return true
        }
        if player.allSatisfy({ !$0.alive }) {
            result = .kaybetti
            ekle(Argo.yenilgiLaf.randomElement()!, .yenilgi)
            return true
        }
        return false
    }

    private func ekle(_ t: String, _ k: LogLine.Kind) {
        log.append(LogLine(text: t, kind: k))
        if log.count > 60 { log.removeFirst(log.count - 60) }
    }
}
