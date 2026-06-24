"""Rajon online backend — anonim hesap, PvP havuzu, lider tablosu.

Offline oyun cihazda çalışır; online mod bu API'yi kullanır.
Saldırı çözümü istemcide (saldıranın ekibi vs savunanın snapshot'ı), sonuç buraya raporlanır.
"""
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json, time
import db

app = FastAPI(title="Rajon Online")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.on_event("startup")
def _startup():
    db.init_db()


def auth(token: str | None):
    if not token:
        raise HTTPException(401, "token yok")
    p = db.get_by_token(token.replace("Bearer ", "").strip())
    if not p:
        raise HTTPException(401, "geçersiz token")
    return p


# ── Modeller ───────────────────────────────────────────────
class RegisterBody(BaseModel):
    device_id: str
    ad: str = "İsimsiz"


class SyncBody(BaseModel):
    ad: str
    power: int
    respect: int
    cash: int
    crew: list = []          # savunma ekibi snapshot (istemci formatı)
    savunma: int = 0         # Korunak savunma puanı (yağmayı azaltır)


class AttackResultBody(BaseModel):
    defender_id: str
    won: bool
    loot: int = 0


class ClanCreateBody(BaseModel):
    ad: str
    aciklama: str = ""


class ClanJoinBody(BaseModel):
    clan_id: str


class ClanDonateBody(BaseModel):
    amount: int


class WarDeclareBody(BaseModel):
    target_clan_id: str


# ── Uçlar ──────────────────────────────────────────────────
@app.get("/rajon/health")
def health():
    return {"ok": True, "ts": int(time.time())}


@app.post("/rajon/register")
def register(b: RegisterBody):
    """Cihaz id ile anonim hesap. Varsa mevcut token'ı döner."""
    existing = db.get_by_id(b.device_id)
    if existing:
        return {"token": existing["token"], "player": _public(existing)}
    p = db.create_player(b.device_id, b.ad.strip()[:24] or "İsimsiz")
    return {"token": p["token"], "player": _public(p)}


@app.post("/rajon/sync")
def sync(b: SyncBody, authorization: str = Header(None)):
    """İstemci durumunu sunucuya yansıtır (PvP havuzu + lider tablosu için)."""
    p = auth(authorization)
    db.update_state(p["id"], b.ad.strip()[:24] or p["ad"], b.power, b.respect, b.cash, b.crew, b.savunma)
    return {"ok": True}


@app.get("/rajon/pvp/target")
def pvp_target(authorization: str = Header(None)):
    """Saldırmak için güce yakın bir rakip döner (savunma ekibiyle)."""
    p = auth(authorization)
    t = db.find_target(p["id"], p["power"])
    if not t:
        raise HTTPException(404, "uygun rakip yok, sonra dene")
    savunma = t["savunma"] if "savunma" in t.keys() else 0
    loot = max(50, int(t["cash"] * 0.10) - savunma * 10)   # Korunak yağmayı azaltır
    return {
        "id": t["id"],
        "ad": t["ad"],
        "power": t["power"],
        "respect": t["respect"],
        "savunma": savunma,
        "loot": loot,
        "crew": json.loads(t["crew_json"] or "[]"),
    }


@app.post("/rajon/pvp/result")
def pvp_result(b: AttackResultBody, authorization: str = Header(None)):
    """Saldırı sonucunu işler; kazanırsa yağma + itibar."""
    p = auth(authorization)
    defender = db.get_by_id(b.defender_id)
    if not defender:
        raise HTTPException(404, "rakip bulunamadı")
    loot = max(0, min(b.loot, int(defender["cash"] * 0.10) + 50))
    db.record_attack(p["id"], b.defender_id, b.won, loot)
    # Clan savaşı puanı (saldıran kazandıysa ve clanlar savaştaysa)
    if b.won:
        atk_clan = (db.get_by_id(p["id"]) or {}).get("clan_id") or ""
        def_clan = defender.get("clan_id") or ""
        db.war_puan(atk_clan, def_clan)
    me = db.get_by_id(p["id"])
    return {"ok": True, "won": b.won, "loot": loot if b.won else 0, "player": _public(me)}


@app.get("/rajon/raids/incoming")
def raids_incoming(authorization: str = Header(None)):
    """Bana yapılan baskınlar (savunma raporu)."""
    p = auth(authorization)
    return {"raids": db.incoming_attacks(p["id"], 20)}


@app.get("/rajon/leaderboard")
def leaderboard(authorization: str = Header(None)):
    me = auth(authorization)
    top = db.leaderboard(50)
    my_rank = next((i + 1 for i, r in enumerate(top) if r["id"] == me["id"]), None)
    return {"top": top, "me": me["id"], "my_rank": my_rank}


# ── Çete / Sendika ─────────────────────────────────────────
import uuid as _uuid


@app.post("/rajon/clan/create")
def clan_create(b: ClanCreateBody, authorization: str = Header(None)):
    p = auth(authorization)
    ad = b.ad.strip()[:24]
    if len(ad) < 3:
        raise HTTPException(400, "çete adı çok kısa")
    if db.clan_by_name(ad):
        raise HTTPException(409, "bu isimde çete var")
    cid = _uuid.uuid4().hex[:12]
    db.create_clan(cid, ad, p["id"], b.aciklama.strip()[:120])
    return clan_mine(authorization)


@app.post("/rajon/clan/join")
def clan_join(b: ClanJoinBody, authorization: str = Header(None)):
    p = auth(authorization)
    if not db.clan_by_id(b.clan_id):
        raise HTTPException(404, "çete bulunamadı")
    db.join_clan(p["id"], b.clan_id)
    return clan_mine(authorization)


@app.post("/rajon/clan/leave")
def clan_leave(authorization: str = Header(None)):
    p = auth(authorization)
    db.leave_clan(p["id"])
    return {"ok": True, "clan": None}


@app.get("/rajon/clan/list")
def clan_list(authorization: str = Header(None)):
    auth(authorization)
    return {"clans": db.clan_list(50)}


@app.get("/rajon/clan/mine")
def clan_mine(authorization: str = Header(None)):
    p = auth(authorization)
    me = db.get_by_id(p["id"])
    cid = (me or {}).get("clan_id") or ""
    if not cid:
        return {"clan": None}
    clan = db.clan_by_id(cid)
    if not clan:
        return {"clan": None}
    members = db.clan_members(cid)
    return {
        "clan": {
            "id": clan["id"], "ad": clan["ad"], "aciklama": clan["aciklama"],
            "lider": clan["lider"], "lider_mi": clan["lider"] == p["id"],
            "uye": len(members),
            "toplam_respect": sum(m["respect"] for m in members),
            "toplam_guc": sum(m["power"] for m in members),
            "hazine": clan.get("hazine", 0),
            "savas_galibi": clan.get("savas_galibi", 0),
            "members": members,
        }
    }


@app.post("/rajon/clan/donate")
def clan_donate_ep(b: ClanDonateBody, authorization: str = Header(None)):
    """Sendika hazinesine bağış (takviye). İstemci nakdi düşer."""
    p = auth(authorization)
    cid = (db.get_by_id(p["id"]) or {}).get("clan_id") or ""
    if not cid:
        raise HTTPException(400, "çetede değilsin")
    db.clan_donate(cid, max(0, b.amount))
    return clan_mine(authorization)


@app.post("/rajon/clan/war/declare")
def clan_war_declare(b: WarDeclareBody, authorization: str = Header(None)):
    """Lider başka bir çeteye savaş ilan eder (24 saat)."""
    p = auth(authorization)
    me = db.get_by_id(p["id"])
    cid = (me or {}).get("clan_id") or ""
    clan = db.clan_by_id(cid) if cid else None
    if not clan or clan["lider"] != p["id"]:
        raise HTTPException(403, "sadece çete lideri savaş ilan eder")
    if not db.clan_by_id(b.target_clan_id) or b.target_clan_id == cid:
        raise HTTPException(400, "geçersiz hedef çete")
    wid = db.declare_war(cid, b.target_clan_id, 24 * 3600)
    if not wid:
        raise HTTPException(409, "zaten aktif bir savaş var")
    return clan_war(authorization)


@app.get("/rajon/clan/war")
def clan_war(authorization: str = Header(None)):
    """Çetemin aktif savaşı (skor + kalan süre)."""
    p = auth(authorization)
    db.resolve_wars()
    cid = (db.get_by_id(p["id"]) or {}).get("clan_id") or ""
    if not cid:
        return {"war": None}
    w = db.active_war(cid)
    if not w:
        return {"war": None}
    a_clan = db.clan_by_id(w["a"]); b_clan = db.clan_by_id(w["b"])
    benim_a = w["a"] == cid
    return {"war": {
        "benim_skor": w["skor_a"] if benim_a else w["skor_b"],
        "rakip_skor": w["skor_b"] if benim_a else w["skor_a"],
        "rakip_ad": (b_clan or {}).get("ad", "?") if benim_a else (a_clan or {}).get("ad", "?"),
        "bitis": w["bitis"],
    }}


def _public(p: dict):
    return {
        "id": p["id"], "ad": p["ad"], "power": p["power"], "respect": p["respect"],
        "cash": p["cash"], "wins": p["wins"], "losses": p["losses"],
        "def_wins": p["def_wins"], "def_losses": p["def_losses"],
        "shield_until": p["shield_until"],
    }
