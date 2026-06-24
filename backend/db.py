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
            """
        )


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


def update_state(pid: str, ad, power, respect, cash, crew):
    with conn() as c:
        c.execute(
            """UPDATE players SET ad=?, power=?, respect=?, cash=?, crew_json=?, last_sync=?
               WHERE id=?""",
            (ad, power, respect, cash, json.dumps(crew), int(time.time()), pid),
        )


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
