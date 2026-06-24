"""Rajon online — SQLite veri katmanı."""
import sqlite3, os, json, time, secrets
from contextlib import contextmanager

DB_PATH = os.environ.get("RAJON_DB", "/opt/rajon-backend/rajon.db")


@contextmanager
def conn():
    c = sqlite3.connect(DB_PATH)
    c.row_factory = sqlite3.Row
    try:
        yield c
        c.commit()
    finally:
        c.close()


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with conn() as c:
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS players (
                id          TEXT PRIMARY KEY,        -- cihaz id (uuid)
                token       TEXT UNIQUE NOT NULL,
                ad          TEXT NOT NULL,
                power       INTEGER DEFAULT 0,
                respect     INTEGER DEFAULT 0,
                cash        INTEGER DEFAULT 0,
                crew_json   TEXT DEFAULT '[]',       -- savunma ekibi snapshot
                wins        INTEGER DEFAULT 0,
                losses      INTEGER DEFAULT 0,
                def_wins    INTEGER DEFAULT 0,
                def_losses  INTEGER DEFAULT 0,
                shield_until INTEGER DEFAULT 0,       -- saldırı kalkanı (epoch)
                last_sync   INTEGER DEFAULT 0,
                created     INTEGER DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS idx_power ON players(power);
            CREATE INDEX IF NOT EXISTS idx_respect ON players(respect);

            CREATE TABLE IF NOT EXISTS attacks (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                attacker    TEXT NOT NULL,
                defender    TEXT NOT NULL,
                won         INTEGER NOT NULL,
                loot        INTEGER DEFAULT 0,
                ts          INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS clans (
                id          TEXT PRIMARY KEY,
                ad          TEXT UNIQUE NOT NULL,
                lider       TEXT NOT NULL,
                aciklama    TEXT DEFAULT '',
                created     INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS clan_wars (
                id      INTEGER PRIMARY KEY AUTOINCREMENT,
                a       TEXT NOT NULL,
                b       TEXT NOT NULL,
                skor_a  INTEGER DEFAULT 0,
                skor_b  INTEGER DEFAULT 0,
                bitis   INTEGER NOT NULL,
                durum   TEXT DEFAULT 'active'
            );
            """
        )
        clan_cols = [r[1] for r in c.execute("PRAGMA table_info(clans)").fetchall()]
        if "hazine" not in clan_cols:
            c.execute("ALTER TABLE clans ADD COLUMN hazine INTEGER DEFAULT 0")
        if "savas_galibi" not in clan_cols:
            c.execute("ALTER TABLE clans ADD COLUMN savas_galibi INTEGER DEFAULT 0")
        # sonradan eklenen kolonlar (migration)
        cols = [r[1] for r in c.execute("PRAGMA table_info(players)").fetchall()]
        if "clan_id" not in cols:
            c.execute("ALTER TABLE players ADD COLUMN clan_id TEXT DEFAULT ''")
        if "savunma" not in cols:
            c.execute("ALTER TABLE players ADD COLUMN savunma INTEGER DEFAULT 0")


def new_token() -> str:
    return secrets.token_urlsafe(24)


def get_by_token(token: str):
    with conn() as c:
        r = c.execute("SELECT * FROM players WHERE token=?", (token,)).fetchone()
        return dict(r) if r else None


def get_by_id(pid: str):
    with conn() as c:
        r = c.execute("SELECT * FROM players WHERE id=?", (pid,)).fetchone()
        return dict(r) if r else None


def create_player(device_id: str, ad: str):
    token = new_token()
    now = int(time.time())
    with conn() as c:
        c.execute(
            "INSERT INTO players(id,token,ad,created,last_sync) VALUES(?,?,?,?,?)",
            (device_id, token, ad, now, now),
        )
    return get_by_id(device_id)


def update_state(pid: str, ad, power, respect, cash, crew, savunma=0):
    with conn() as c:
        c.execute(
            """UPDATE players SET ad=?, power=?, respect=?, cash=?, crew_json=?, savunma=?, last_sync=?
               WHERE id=?""",
            (ad, power, respect, cash, json.dumps(crew), savunma, int(time.time()), pid),
        )


def incoming_attacks(pid: str, limit: int = 20):
    """Bu oyuncuya yapılan son saldırılar (savunma raporu)."""
    with conn() as c:
        rows = c.execute(
            """SELECT a.attacker, a.won, a.loot, a.ts, COALESCE(p.ad,'?') AS attacker_ad
               FROM attacks a LEFT JOIN players p ON p.id = a.attacker
               WHERE a.defender=? ORDER BY a.ts DESC LIMIT ?""",
            (pid, limit),
        ).fetchall()
        return [dict(r) for r in rows]


def find_target(pid: str, power: int):
    """Saldıran oyuncuya yakın güçte, kalkanı olmayan bir rakip bul."""
    now = int(time.time())
    with conn() as c:
        # önce ±%35 güç bandında ara, bulamazsa genişlet
        for band in (0.35, 0.7, 5.0):
            lo, hi = int(power * (1 - band)), int(power * (1 + band)) or 999999999
            r = c.execute(
                """SELECT * FROM players
                   WHERE id!=? AND shield_until<? AND power BETWEEN ? AND ?
                   ORDER BY RANDOM() LIMIT 1""",
                (pid, now, lo, max(hi, 1)),
            ).fetchone()
            if r:
                return dict(r)
    return None


def record_attack(attacker: str, defender: str, won: bool, loot: int):
    now = int(time.time())
    with conn() as c:
        c.execute(
            "INSERT INTO attacks(attacker,defender,won,loot,ts) VALUES(?,?,?,?,?)",
            (attacker, defender, 1 if won else 0, loot, now),
        )
        if won:
            c.execute("UPDATE players SET wins=wins+1, respect=respect+15 WHERE id=?", (attacker,))
            c.execute(
                "UPDATE players SET def_losses=def_losses+1, cash=MAX(0,cash-?), shield_until=? WHERE id=?",
                (loot, now + 3600, defender),  # mağlup savunmaya 1 saat kalkan
            )
        else:
            c.execute("UPDATE players SET losses=losses+1 WHERE id=?", (attacker,))
            c.execute("UPDATE players SET def_wins=def_wins+1, respect=respect+8 WHERE id=?", (defender,))


def leaderboard(limit: int = 50):
    with conn() as c:
        rows = c.execute(
            """SELECT id, ad, power, respect, wins, def_wins
               FROM players ORDER BY respect DESC, power DESC LIMIT ?""",
            (limit,),
        ).fetchall()
        return [dict(r) for r in rows]


# ── Çete / Sendika ─────────────────────────────────────────

def create_clan(clan_id: str, ad: str, lider: str, aciklama: str):
    now = int(time.time())
    with conn() as c:
        c.execute(
            "INSERT INTO clans(id,ad,lider,aciklama,created) VALUES(?,?,?,?,?)",
            (clan_id, ad, lider, aciklama, now),
        )
        c.execute("UPDATE players SET clan_id=? WHERE id=?", (clan_id, lider))


def join_clan(pid: str, clan_id: str):
    with conn() as c:
        c.execute("UPDATE players SET clan_id=? WHERE id=?", (clan_id, pid))


def leave_clan(pid: str):
    with conn() as c:
        p = c.execute("SELECT clan_id FROM players WHERE id=?", (pid,)).fetchone()
        cid = p["clan_id"] if p else ""
        c.execute("UPDATE players SET clan_id='' WHERE id=?", (pid,))
        if not cid:
            return
        # Lider çıkarsa: kalan üyelerden birine devret, kimse yoksa çeteyi sil
        clan = c.execute("SELECT lider FROM clans WHERE id=?", (cid,)).fetchone()
        if clan and clan["lider"] == pid:
            yeni = c.execute(
                "SELECT id FROM players WHERE clan_id=? ORDER BY respect DESC LIMIT 1", (cid,)
            ).fetchone()
            if yeni:
                c.execute("UPDATE clans SET lider=? WHERE id=?", (yeni["id"], cid))
            else:
                c.execute("DELETE FROM clans WHERE id=?", (cid,))


def clan_by_name(ad: str):
    with conn() as c:
        r = c.execute("SELECT * FROM clans WHERE ad=?", (ad,)).fetchone()
        return dict(r) if r else None


def clan_by_id(cid: str):
    with conn() as c:
        r = c.execute("SELECT * FROM clans WHERE id=?", (cid,)).fetchone()
        return dict(r) if r else None


def clan_members(cid: str):
    with conn() as c:
        rows = c.execute(
            "SELECT id, ad, power, respect, wins FROM players WHERE clan_id=? ORDER BY respect DESC",
            (cid,),
        ).fetchall()
        return [dict(r) for r in rows]


def clan_donate(clan_id: str, amount: int):
    with conn() as c:
        c.execute("UPDATE clans SET hazine=hazine+? WHERE id=?", (max(0, amount), clan_id))


def declare_war(a: str, b: str, sure_sn: int):
    now = int(time.time())
    with conn() as c:
        # zaten aktif savaş var mı
        ex = c.execute(
            "SELECT id FROM clan_wars WHERE durum='active' AND (a=? OR b=? OR a=? OR b=?)",
            (a, a, b, b),
        ).fetchone()
        if ex:
            return None
        cur = c.execute(
            "INSERT INTO clan_wars(a,b,bitis) VALUES(?,?,?)", (a, b, now + sure_sn)
        )
        return cur.lastrowid


def active_war(clan_id: str):
    with conn() as c:
        r = c.execute(
            "SELECT * FROM clan_wars WHERE durum='active' AND (a=? OR b=?) LIMIT 1",
            (clan_id, clan_id),
        ).fetchone()
        return dict(r) if r else None


def war_puan(attacker_clan: str, defender_clan: str):
    """İki clan savaştaysa saldıranın clan skorunu artır."""
    if not attacker_clan or not defender_clan:
        return
    with conn() as c:
        r = c.execute(
            "SELECT * FROM clan_wars WHERE durum='active' AND ((a=? AND b=?) OR (a=? AND b=?))",
            (attacker_clan, defender_clan, defender_clan, attacker_clan),
        ).fetchone()
        if not r:
            return
        kol = "skor_a" if r["a"] == attacker_clan else "skor_b"
        c.execute(f"UPDATE clan_wars SET {kol}={kol}+1 WHERE id=?", (r["id"],))


def resolve_wars():
    """Süresi dolan savaşları kapat, galibe +1 zafer."""
    now = int(time.time())
    with conn() as c:
        for r in c.execute("SELECT * FROM clan_wars WHERE durum='active' AND bitis<=?", (now,)).fetchall():
            galip = r["a"] if r["skor_a"] >= r["skor_b"] else r["b"]
            c.execute("UPDATE clans SET savas_galibi=savas_galibi+1 WHERE id=?", (galip,))
            c.execute("UPDATE clan_wars SET durum='ended' WHERE id=?", (r["id"],))


def clan_list(limit: int = 50):
    """Çeteleri toplam itibara göre sırala (üye toplamları)."""
    with conn() as c:
        rows = c.execute(
            """SELECT cl.id, cl.ad, cl.aciklama, cl.lider,
                      COUNT(p.id) AS uye, COALESCE(SUM(p.respect),0) AS toplam_respect,
                      COALESCE(SUM(p.power),0) AS toplam_guc
               FROM clans cl LEFT JOIN players p ON p.clan_id = cl.id
               GROUP BY cl.id
               ORDER BY toplam_respect DESC LIMIT ?""",
            (limit,),
        ).fetchall()
        return [dict(r) for r in rows]
