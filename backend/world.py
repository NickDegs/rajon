"""Rajon — SUNUCU-OTORİTER dünya motoru (tek paylaşılan dünya, Travian tarzı).

Her oyuncunun TÜM ekonomisi sunucuda tutulur ve zaman-damgalı tick ile otoriter
işletilir: gelir/mühimmat birikimi, inşaat/eğitim/fetih zamanlayıcıları, fetih,
oyuncular-arası (server-resolved) saldırı. İstemci ince bir görüntü+aksiyon
göndericisidir. Sabitler iOS GameStore/Models/Factory ile BİREBİR aynıdır.
"""
import json, time, math
import db

def NOW() -> int: return int(time.time())

# ── İçerik (iOS ile birebir) ───────────────────────────────────────
RACKETS = [  # (ad, basePerMin, baseUpgradeCost)
    ("Köşedeki Kıraathane", 40, 250),
    ("Tefeci Masası", 90, 600),
    ("Oto Sanayi 'Parçacı'", 160, 1_400),
    ("Gece Kulübü Inferno", 320, 3_200),
    ("Liman Ambarı", 600, 7_500),
    ("Kumarhane Baht", 1_100, 16_000),
]
def racket_permin(base, tier): return int(base * (1.6 ** (tier - 1)))
def racket_upcost(base, tier): return int(base * (1.9 ** (tier - 1)))

BUILDINGS = ["karargah", "kasa", "depo", "cephanelik", "kisla", "korunak"]
BUILD_START = {"karargah": 1, "kasa": 1, "depo": 0, "cephanelik": 0, "kisla": 0, "korunak": 0}
def build_cost(level): return int(220.0 * (1.7 ** level))
def build_time(level, karargah): return (30.0 * (1.45 ** level)) / (1.0 + 0.07 * karargah)

REGIONS = [  # (ad, gelirDk)
    ("Çarşı", 120), ("Liman", 280), ("Yokuş", 520),
    ("Meydan", 900), ("Sanayi", 1_500), ("Kordon", 2_400),
]
def region_cost(idx): return int(2_500.0 * (2.4 ** idx))
def region_time(idx, karargah): return (60.0 * (1.8 ** idx)) / (1.0 + 0.07 * karargah)

OASES = [  # (ad, tip, bonusDk)
    ("Mazot Kuyusu", "nakit", 200), ("Cephane Deposu", "cephane", 18),
    ("Kumar Çadırı", "nakit", 380), ("Tefeci Köşesi", "nakit", 600),
    ("Kaçak İskele", "nakit", 950), ("Silah Atölyesi", "cephane", 40),
]
def oasis_cost(idx): return int(4_000.0 * (2.2 ** idx))
def oasis_time(idx, karargah): return (90.0 * (1.7 ** idx)) / (1.0 + 0.07 * karargah)

SOLDIERS = {  # tip: (maliyet, cephaneMaliyet, saldiri, savunma, yagma)
    "tetikci": (600, 8, 14, 5, 40),
    "kabadayi": (700, 3, 5, 16, 40),
    "sofor":   (900, 2, 6, 6, 220),
}
TRAIN_SEC_PER = 8.0


# ── Tablo ──────────────────────────────────────────────────────────
def init():
    with db.conn() as c:
        c.execute("""
            CREATE TABLE IF NOT EXISTS world (
                pid         TEXT PRIMARY KEY,
                cash        INTEGER, idle INTEGER, cephane INTEGER, respect INTEGER,
                last_tick   INTEGER,
                rackets     TEXT, buildings TEXT, regions TEXT, oases TEXT, army TEXT,
                build_tip   TEXT, build_finish INTEGER,
                train_tip   TEXT, train_count INTEGER, train_finish INTEGER,
                created     INTEGER
            )""")


def _new_state(pid: str) -> dict:
    return {
        "pid": pid, "cash": 1_500, "idle": 0, "cephane": 200, "respect": 0,
        "last_tick": NOW(),
        "rackets": [{"owned": i == 0, "tier": 1} for i in range(len(RACKETS))],
        "buildings": dict(BUILD_START),
        "regions": [{"owned": i == 0, "finish": 0} for i in range(len(REGIONS))],
        "oases": [{"owned": False, "finish": 0} for _ in range(len(OASES))],
        "army": {"tetikci": 0, "kabadayi": 0, "sofor": 0},
        "build_tip": "", "build_finish": 0,
        "train_tip": "", "train_count": 0, "train_finish": 0,
        "created": NOW(),
    }


def _load(pid: str) -> dict:
    with db.conn() as c:
        r = c.execute("SELECT * FROM world WHERE pid=?", (pid,)).fetchone()
    if not r:
        s = _new_state(pid)
        _save(s)
        return s
    return {
        "pid": r["pid"], "cash": r["cash"], "idle": r["idle"], "cephane": r["cephane"],
        "respect": r["respect"], "last_tick": r["last_tick"],
        "rackets": json.loads(r["rackets"]), "buildings": json.loads(r["buildings"]),
        "regions": json.loads(r["regions"]), "oases": json.loads(r["oases"]),
        "army": json.loads(r["army"]),
        "build_tip": r["build_tip"] or "", "build_finish": r["build_finish"] or 0,
        "train_tip": r["train_tip"] or "", "train_count": r["train_count"] or 0,
        "train_finish": r["train_finish"] or 0, "created": r["created"],
    }


def _save(s: dict):
    with db.conn() as c:
        c.execute("""
            INSERT INTO world (pid,cash,idle,cephane,respect,last_tick,rackets,buildings,
                regions,oases,army,build_tip,build_finish,train_tip,train_count,train_finish,created)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            ON CONFLICT(pid) DO UPDATE SET
                cash=excluded.cash, idle=excluded.idle, cephane=excluded.cephane,
                respect=excluded.respect, last_tick=excluded.last_tick, rackets=excluded.rackets,
                buildings=excluded.buildings, regions=excluded.regions, oases=excluded.oases,
                army=excluded.army, build_tip=excluded.build_tip, build_finish=excluded.build_finish,
                train_tip=excluded.train_tip, train_count=excluded.train_count, train_finish=excluded.train_finish
        """, (s["pid"], s["cash"], s["idle"], s["cephane"], s["respect"], s["last_tick"],
              json.dumps(s["rackets"]), json.dumps(s["buildings"]), json.dumps(s["regions"]),
              json.dumps(s["oases"]), json.dumps(s["army"]), s["build_tip"], s["build_finish"],
              s["train_tip"], s["train_count"], s["train_finish"], s["created"]))


# ── Türetilmiş değerler ────────────────────────────────────────────
def blevel(s, tip): return s["buildings"].get(tip, 0)
def boss_level(s): return 1 + int(math.sqrt(s["respect"] / 100.0))

def region_income_dk(s):
    return sum(REGIONS[i][1] for i, r in enumerate(s["regions"]) if r["owned"])
def oasis_cash_dk(s):
    return sum(OASES[i][2] for i, o in enumerate(s["oases"]) if o["owned"] and OASES[i][1] == "nakit")
def oasis_ammo_dk(s):
    return sum(OASES[i][2] for i, o in enumerate(s["oases"]) if o["owned"] and OASES[i][1] == "cephane")

def income_per_sec(s):
    racket = sum(racket_permin(RACKETS[i][0 + 1], r["tier"]) for i, r in enumerate(s["rackets"]) if r["owned"]) / 60.0
    bonus = (80 * blevel(s, "kasa") + region_income_dk(s) + oasis_cash_dk(s)) / 60.0
    return racket + bonus

def depo_kapasite(s): return 200_000 + blevel(s, "depo") * 250_000
def cephane_max(s): return 1_500 + 700 * blevel(s, "cephanelik")
def cephane_uretim_dk(s): return 30 * blevel(s, "cephanelik") + oasis_ammo_dk(s)
def max_kadro(s): return min(6, 4 + blevel(s, "kisla") // 2)
def korunak_savunma(s): return 60 * blevel(s, "korunak")

def nufuz_kapasite(s): return 2 + blevel(s, "karargah") + boss_level(s)
def regions_owned(s): return sum(1 for r in s["regions"] if r["owned"])
def oases_owned(s): return sum(1 for o in s["oases"] if o["owned"])
def nufuz_kullanim(s): return max(0, regions_owned(s) - 1) + oases_owned(s)
def nufuz_var(s): return nufuz_kullanim(s) < nufuz_kapasite(s)

def ordu_saldiri(s): return sum(s["army"].get(t, 0) * SOLDIERS[t][2] for t in SOLDIERS)
def ordu_savunma(s): return sum(s["army"].get(t, 0) * SOLDIERS[t][3] for t in SOLDIERS)
def ordu_yagma(s): return sum(s["army"].get(t, 0) * SOLDIERS[t][4] for t in SOLDIERS)

def power(s):
    return ordu_saldiri(s) + ordu_savunma(s) + s["respect"] + sum(s["buildings"].values()) * 25


# ── Tick (otoriter zaman ilerletme) ────────────────────────────────
def tick(s):
    now = NOW()
    dt = max(0, now - s["last_tick"])
    if dt > 0:
        # gelir → idle (depo tavanı)
        s["idle"] = min(depo_kapasite(s), s["idle"] + int(income_per_sec(s) * dt))
        # mühimmat
        if cephane_uretim_dk(s) > 0:
            s["cephane"] = min(cephane_max(s), s["cephane"] + int(cephane_uretim_dk(s) / 60.0 * dt))
    # inşaat bitti mi
    if s["build_tip"] and s["build_finish"] and now >= s["build_finish"]:
        s["buildings"][s["build_tip"]] = s["buildings"].get(s["build_tip"], 0) + 1
        s["build_tip"] = ""; s["build_finish"] = 0
    # eğitim bitti mi
    if s["train_tip"] and s["train_finish"] and now >= s["train_finish"]:
        s["army"][s["train_tip"]] = s["army"].get(s["train_tip"], 0) + s["train_count"]
        s["train_tip"] = ""; s["train_count"] = 0; s["train_finish"] = 0
    # fetihler bitti mi
    for r in s["regions"]:
        if r.get("finish") and now >= r["finish"]:
            r["owned"] = True; r["finish"] = 0
    for o in s["oases"]:
        if o.get("finish") and now >= o["finish"]:
            o["owned"] = True; o["finish"] = 0
    s["last_tick"] = now
    return s


def _sync_players(pid, s):
    """players tablosunu güncelle (lider tablosu + PvP havuzu world'le tutarlı)."""
    try:
        p = db.get_by_id(pid)
        ad = p["ad"] if p else "Patron"
        db.update_state(pid, ad, power(s), s["respect"], s["cash"] + s["idle"], [], korunak_savunma(s) + ordu_savunma(s))
    except Exception:
        pass


def view(pid):
    """Tick + tam dünya görünümü (istemci için)."""
    s = tick(_load(pid)); _save(s); _sync_players(pid, s)
    now = NOW()
    return {
        "cash": s["cash"], "idle": s["idle"], "cephane": s["cephane"], "respect": s["respect"],
        "bossLevel": boss_level(s),
        "incomePerMin": int(income_per_sec(s) * 60),
        "depoKapasite": depo_kapasite(s), "cephaneMax": cephane_max(s),
        "cephaneUretimDk": cephane_uretim_dk(s), "maxKadro": max_kadro(s),
        "nufuzKapasite": nufuz_kapasite(s), "nufuzKullanim": nufuz_kullanim(s),
        "rackets": [{
            "idx": i, "ad": RACKETS[i][0], "owned": r["owned"], "tier": r["tier"],
            "perMin": racket_permin(RACKETS[i][1], r["tier"]) if r["owned"] else racket_permin(RACKETS[i][1], 1),
            "fiyat": RACKETS[i][2] if not r["owned"] else racket_upcost(RACKETS[i][2], r["tier"]),
        } for i, r in enumerate(s["rackets"])],
        "buildings": [{
            "tip": t, "seviye": blevel(s, t),
            "fiyat": build_cost(blevel(s, t)),
            "sure": int(build_time(blevel(s, t), blevel(s, "karargah"))),
            "insaatta": s["build_tip"] == t,
            "kalan": max(0, s["build_finish"] - now) if s["build_tip"] == t else 0,
        } for t in BUILDINGS],
        "insaatMesgul": bool(s["build_tip"]),
        "regions": [{
            "idx": i, "ad": REGIONS[i][0], "gelirDk": REGIONS[i][1], "owned": r["owned"],
            "fiyat": region_cost(i), "sure": int(region_time(i, blevel(s, "karargah"))),
            "fetihte": bool(r.get("finish")), "kalan": max(0, r.get("finish", 0) - now),
        } for i, r in enumerate(s["regions"])],
        "oases": [{
            "idx": i, "ad": OASES[i][0], "tip": OASES[i][1], "bonusDk": OASES[i][2], "owned": o["owned"],
            "fiyat": oasis_cost(i), "sure": int(oasis_time(i, blevel(s, "karargah"))),
            "fetihte": bool(o.get("finish")), "kalan": max(0, o.get("finish", 0) - now),
        } for i, o in enumerate(s["oases"])],
        "army": s["army"],
        "train": {"tip": s["train_tip"], "count": s["train_count"],
                  "kalan": max(0, s["train_finish"] - now)} if s["train_tip"] else None,
    }


# ── Aksiyonlar (otoriter; sunucu doğrular) ─────────────────────────
class WErr(Exception):
    def __init__(self, msg): self.msg = msg


def collect(pid):
    s = tick(_load(pid))
    s["cash"] += s["idle"]; s["idle"] = 0
    _save(s); _sync_players(pid, s)
    return view(pid)


def racket(pid, idx):
    s = tick(_load(pid))
    if idx < 0 or idx >= len(RACKETS): raise WErr("geçersiz işletme")
    r = s["rackets"][idx]
    if not r["owned"]:
        fiyat = RACKETS[idx][2]
        if s["cash"] < fiyat: raise WErr("nakit yetersiz")
        s["cash"] -= fiyat; r["owned"] = True
    else:
        fiyat = racket_upcost(RACKETS[idx][2], r["tier"])
        if s["cash"] < fiyat: raise WErr("nakit yetersiz")
        s["cash"] -= fiyat; r["tier"] += 1
    _save(s); _sync_players(pid, s)
    return view(pid)


def building(pid, tip):
    s = tick(_load(pid))
    if tip not in BUILDINGS: raise WErr("geçersiz bina")
    if s["build_tip"]: raise WErr("zaten inşaat var")
    fiyat = build_cost(blevel(s, tip))
    if s["cash"] < fiyat: raise WErr("nakit yetersiz")
    s["cash"] -= fiyat
    s["build_tip"] = tip
    s["build_finish"] = NOW() + int(build_time(blevel(s, tip), blevel(s, "karargah")))
    _save(s)
    return view(pid)


def conquer(pid, kind, idx):
    s = tick(_load(pid))
    if not nufuz_var(s): raise WErr("nüfuz yetersiz — Karargah yükselt")
    busy = any(r.get("finish") for r in s["regions"]) or any(o.get("finish") for o in s["oases"])
    if busy: raise WErr("zaten fetih sürüyor")
    if kind == "region":
        if idx < 0 or idx >= len(REGIONS) or s["regions"][idx]["owned"]: raise WErr("geçersiz bölge")
        fiyat = region_cost(idx)
        if s["cash"] < fiyat: raise WErr("nakit yetersiz")
        s["cash"] -= fiyat
        s["regions"][idx]["finish"] = NOW() + int(region_time(idx, blevel(s, "karargah")))
    elif kind == "oasis":
        if idx < 0 or idx >= len(OASES) or s["oases"][idx]["owned"]: raise WErr("geçersiz vaha")
        fiyat = oasis_cost(idx)
        if s["cash"] < fiyat: raise WErr("nakit yetersiz")
        s["cash"] -= fiyat
        s["oases"][idx]["finish"] = NOW() + int(oasis_time(idx, blevel(s, "karargah")))
    else:
        raise WErr("geçersiz fetih tipi")
    _save(s)
    return view(pid)


def train(pid, tip, count):
    s = tick(_load(pid))
    if tip not in SOLDIERS: raise WErr("geçersiz asker")
    if s["train_tip"]: raise WErr("zaten eğitim var")
    count = max(1, min(int(count), 50))
    mal, cmal, *_ = SOLDIERS[tip]
    if s["cash"] < mal * count: raise WErr("nakit yetersiz")
    if s["cephane"] < cmal * count: raise WErr("mühimmat yetersiz")
    s["cash"] -= mal * count; s["cephane"] -= cmal * count
    hiz = 1.0 / (1.0 + 0.05 * blevel(s, "kisla"))
    s["train_tip"] = tip; s["train_count"] = count
    s["train_finish"] = NOW() + int(TRAIN_SEC_PER * count * hiz)
    _save(s)
    return view(pid)


def attack(pid, target_id):
    """Sunucu-çözümlü oyuncular-arası saldırı (paylaşılan dünya)."""
    if target_id == pid: raise WErr("kendine saldıramazsın")
    me = tick(_load(pid))
    if ordu_saldiri(me) <= 0: raise WErr("ordun yok — asker eğit")
    tgt = tick(_load(target_id))
    atk = ordu_saldiri(me) * (1.0 + 0.07 * blevel(me, "cephanelik"))
    deff = ordu_savunma(tgt) + korunak_savunma(tgt)
    won = atk >= deff
    loot = 0
    if won:
        havuz = tgt["idle"] + int(tgt["cash"] * 0.10)
        loot = max(0, min(ordu_yagma(me), havuz))
        # yağmayı paylaştır: önce idle, sonra cash
        if loot <= tgt["idle"]:
            tgt["idle"] -= loot
        else:
            rem = loot - tgt["idle"]; tgt["idle"] = 0; tgt["cash"] = max(0, tgt["cash"] - rem)
        me["cash"] += loot; me["respect"] += 10
        # küçük birlik kaybı (saldıran)
        for t in me["army"]:
            me["army"][t] = int(me["army"][t] * 0.92)
    else:
        for t in me["army"]:
            me["army"][t] = int(me["army"][t] * 0.75)
    _save(me); _save(tgt); _sync_players(pid, me); _sync_players(target_id, tgt)
    try:
        db.record_attack(pid, target_id, won, loot)
    except Exception:
        pass
    return {"won": won, "loot": loot, "world": view(pid)}
