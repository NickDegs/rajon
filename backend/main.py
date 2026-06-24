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


class AttackResultBody(BaseModel):
    defender_id: str
    won: bool
    loot: int = 0


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
    db.update_state(p["id"], b.ad.strip()[:24] or p["ad"], b.power, b.respect, b.cash, b.crew)
    return {"ok": True}


@app.get("/rajon/pvp/target")
def pvp_target(authorization: str = Header(None)):
    """Saldırmak için güce yakın bir rakip döner (savunma ekibiyle)."""
    p = auth(authorization)
    t = db.find_target(p["id"], p["power"])
    if not t:
        raise HTTPException(404, "uygun rakip yok, sonra dene")
    return {
        "id": t["id"],
        "ad": t["ad"],
        "power": t["power"],
        "respect": t["respect"],
        "loot": max(50, int(t["cash"] * 0.10)),   # alınabilecek yağma
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
    me = db.get_by_id(p["id"])
    return {"ok": True, "won": b.won, "loot": loot if b.won else 0, "player": _public(me)}


@app.get("/rajon/leaderboard")
def leaderboard(authorization: str = Header(None)):
    me = auth(authorization)
    top = db.leaderboard(50)
    my_rank = next((i + 1 for i, r in enumerate(top) if r["id"] == me["id"]), None)
    return {"top": top, "me": me["id"], "my_rank": my_rank}


def _public(p: dict):
    return {
        "id": p["id"], "ad": p["ad"], "power": p["power"], "respect": p["respect"],
        "cash": p["cash"], "wins": p["wins"], "losses": p["losses"],
        "def_wins": p["def_wins"], "def_losses": p["def_losses"],
        "shield_until": p["shield_until"],
    }
