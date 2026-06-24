"""Rajon online backend — anonim hesap, PvP havuzu, lider tablosu.

Offline oyun cihazda çalışır; online mod bu API'yi kullanır.
Saldırı çözümü istemcide (saldıranın ekibi vs savunanın snapshot'ı), sonuç buraya raporlanır.
"""
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import json, time, os, base64, urllib.request, urllib.parse, urllib.error, re
import db

# Twilio Verify (DayRide/hush ile paylaşılan hesap)
TW_KEY = os.environ.get("TWILIO_API_KEY", "")
TW_SECRET = os.environ.get("TWILIO_API_SECRET", "")
TW_VERIFY = os.environ.get("TWILIO_VERIFY_SID", "")

# App Review demo hesabı — reviewer SMS alamadığı için sabit numara+kod (Twilio atlanır)
DEMO_PHONE = "+15550000000"
DEMO_CODE = "424242"


def _phone_norm(p: str) -> str:
    """E.164'e yakın normalize: sadece rakam, baştaki 00/0 düzelt."""
    d = re.sub(r"[^\d+]", "", p or "")
    if d.startswith("+"):
        return d
    if d.startswith("00"):
        return "+" + d[2:]
    if d.startswith("0"):
        d = d[1:]
    return "+" + d if d else ""


def _tw(path: str, data: dict):
    url = f"https://verify.twilio.com/v2/Services/{TW_VERIFY}/{path}"
    body = urllib.parse.urlencode(data).encode()
    auth = base64.b64encode(f"{TW_KEY}:{TW_SECRET}".encode()).decode()
    req = urllib.request.Request(url, data=body,
                                 headers={"Authorization": f"Basic {auth}",
                                          "Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())

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


class SmsStartBody(BaseModel):
    phone: str


class SmsVerifyBody(BaseModel):
    phone: str
    code: str
    device_id: str = ""


class StatePushBody(BaseModel):
    blob: str


# ── Uçlar ──────────────────────────────────────────────────
@app.get("/rajon/health")
def health():
    return {"ok": True, "ts": int(time.time())}


PRIVACY_HTML = """<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rajon — Gizlilik Politikası / Privacy Policy</title>
<style>body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;max-width:760px;margin:0 auto;padding:24px;
background:#0d0d0f;color:#e8e8ea;line-height:1.6}h1{color:#d9b04d}h2{color:#c7170f;margin-top:28px}
a{color:#d9b04d}small{color:#9a9aa2}</style></head><body>
<h1>Rajon — Gizlilik Politikası</h1>
<small>Son güncelleme: 24 Haziran 2026</small>
<p>Rajon, sokak/mafya temalı bir strateji oyunudur. Gizliliğine önem veriyoruz. Bu politika hangi verileri
topladığımızı ve nasıl kullandığımızı açıklar.</p>
<h2>Topladığımız veriler</h2>
<ul>
<li><b>Anonim hesap kimliği:</b> Online özellikler için cihazında rastgele üretilen bir kimlik (UUID). Bu, cihazının
donanım kimliği DEĞİLDİR; sadece oyun hesabını tanımlar.</li>
<li><b>Takma ad:</b> Online'da görünmesi için kendi seçtiğin bir patron adı. Gerçek adını kullanmak zorunda değilsin.</li>
<li><b>Oyun ilerlemesi:</b> Güç, itibar gibi oyun istatistikleri — yalnızca online özellikleri (PvP eşleştirme, lider
tablosu, sendika) çalıştırmak için sunucumuzla eşitlenir.</li>
<li><b>Telefon numarası (İSTEĞE BAĞLI):</b> Yalnızca SMS ile giriş yapıp ilerlemeni telefonuna yedeklemeyi
seçersen alınır. Doğrulama kodu Twilio aracılığıyla gönderilir. Numaran hesabını tanımlamak için kullanılır;
reklam/pazarlama için KULLANILMAZ, üçüncü taraflara satılmaz. SMS girişini kullanmazsan numaran hiç alınmaz.</li>
</ul>
<h2>Toplamadığımız veriler</h2>
<p>E-posta, gerçek ad, konum, rehber, fotoğraf, reklam kimliği (IDFA) <b>toplanmaz</b>. Reklam yoktur,
uygulamalar/siteler arası takip yapılmaz, üçüncü taraf analiz/reklam SDK'sı yoktur.</p>
<h2>Satın almalar</h2>
<p>Tüm satın almalar Apple üzerinden yapılır; ödeme bilgini biz görmeyiz. Satın almalar yalnızca KOZMETİKTİR
(profil avatarı, isim rengi, rozet) ve oyunu güçlendirmez — pay-to-win yoktur.</p>
<h2>Paylaşım</h2>
<p>Veriler yalnızca oyunun online işlevlerini çalıştırmak için kendi sunucumuzda saklanır. Üçüncü taraflara
satılmaz veya paylaşılmaz.</p>
<h2>Çocuklar</h2>
<p>Uygulama 17+ içindir, çocuklara yönelik değildir.</p>
<h2>Veri silme</h2>
<p>Online oynamayı istediğin an bırakabilirsin. Hesap verilerinin silinmesini istersen aşağıdaki e-postadan bize
ulaş; talebini en geç 30 gün içinde işleriz.</p>
<h2>İletişim</h2>
<p>E-posta: <a href="mailto:support@nickdegs.com">support@nickdegs.com</a></p>
<hr>
<h1>Rajon — Privacy Policy (English)</h1>
<p>Rajon is a street/mafia-themed strategy game. We collect: a randomly generated anonymous account ID (a UUID created
on your device, not your hardware identifier), a display name you choose (no real name required), and in-game progress
(power, respect) synced solely to run online features (PvP matchmaking, leaderboard, clans). OPTIONALLY, if you choose
to log in via SMS to back up your progress to your phone, we collect your <b>phone number</b> (verification code sent
via Twilio). Your phone number is used only to identify your account; it is never used for advertising/marketing or
sold. If you do not use SMS login, no phone number is collected.</p>
<p>We do NOT collect email, real name, location, contacts, photos, or advertising identifiers (IDFA). There are
no ads, no cross-app/website tracking, and no third-party analytics/ad SDKs. Purchases are handled by Apple (we never
see your payment info) and are PURELY COSMETIC — no pay-to-win. Data is stored only on our own server to run online
features and is never sold or shared. The app is rated 17+. To request deletion of your account data, contact
<a href="mailto:support@nickdegs.com">support@nickdegs.com</a>.</p>
</body></html>"""


@app.get("/rajon/privacy", response_class=HTMLResponse)
def privacy():
    return PRIVACY_HTML


SUPPORT_HTML = """<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>Rajon — Destek / Support</title>
<style>body{font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;max-width:680px;margin:0 auto;padding:24px;
background:#0d0d0f;color:#e8e8ea;line-height:1.6}h1{color:#d9b04d}a{color:#d9b04d}</style></head><body>
<h1>Rajon — Destek</h1>
<p>Rajon, sokak/mafya temalı strateji oyunudur. Soru, hata bildirimi veya hesap/veri silme talepleri için:</p>
<p><b>E-posta:</b> <a href="mailto:support@nickdegs.com">support@nickdegs.com</a></p>
<p>Genelde 1–2 iş günü içinde yanıt veririz.</p>
<p><b>Sık sorulanlar:</b></p>
<ul>
<li><b>İlerlemem nasıl yedeklenir?</b> Ayarlar → "Telefonla Yedekle / Giriş" ile numaranı bağla; ilerlemen
telefonuna ve iCloud'a kaydedilir, yeni cihazda aynı numarayla geri yüklenir.</li>
<li><b>Satın almalar oyunu güçlendirir mi?</b> Hayır — tüm satın almalar kozmetiktir, pay-to-win yoktur.</li>
<li><b>Hesabımı sil:</b> Yukarıdaki e-postadan ulaş, 30 gün içinde sileriz.</li>
</ul>
<p><a href="/privacy">Gizlilik Politikası</a></p>
<hr><p><small>Rajon — Support. Contact: <a href="mailto:support@nickdegs.com">support@nickdegs.com</a></small></p>
</body></html>"""


@app.get("/rajon/support", response_class=HTMLResponse)
def support():
    return SUPPORT_HTML


@app.post("/rajon/register")
def register(b: RegisterBody):
    """Cihaz id ile anonim hesap. Varsa mevcut token'ı döner."""
    existing = db.get_by_id(b.device_id)
    if existing:
        return {"token": existing["token"], "player": _public(existing)}
    p = db.create_player(b.device_id, b.ad.strip()[:24] or "İsimsiz")
    return {"token": p["token"], "player": _public(p)}


@app.post("/rajon/auth/sms/start")
def sms_start(b: SmsStartBody):
    """Telefona doğrulama kodu gönder."""
    phone = _phone_norm(b.phone)
    if len(phone) < 8:
        raise HTTPException(400, "geçersiz telefon")
    if phone == DEMO_PHONE:          # App Review demo — Twilio çağırma
        return {"ok": True}
    try:
        _tw("Verifications", {"To": phone, "Channel": "sms"})
        return {"ok": True}
    except urllib.error.HTTPError as e:
        raise HTTPException(400, f"sms gönderilemedi: {e.read().decode()[:120]}")


@app.post("/rajon/auth/sms/verify")
def sms_verify(b: SmsVerifyBody):
    """Kodu doğrula → telefon hesabının token'ı + tam oyun durumu (geri yükleme)."""
    phone = _phone_norm(b.phone)
    if phone == DEMO_PHONE:          # App Review demo — sabit kodu doğrula
        if b.code != DEMO_CODE:
            raise HTTPException(401, "kod yanlış")
    else:
        try:
            r = _tw("VerificationCheck", {"To": phone, "Code": b.code})
        except urllib.error.HTTPError:
            raise HTTPException(401, "kod yanlış")
        if r.get("status") != "approved":
            raise HTTPException(401, "kod onaylanmadı")

    # Telefonun hesabı var mı?
    acc = db.get_by_phone(phone)
    if acc:
        # Var olan telefon hesabı → giriş/geri yükleme
        return {"token": acc["token"], "player": _public(acc), "state": acc.get("state_blob", "")}
    # Yok → mevcut cihaz hesabını bu telefona bağla (ilerlemeyi telefona taşı)
    me = db.get_by_id(b.device_id) if b.device_id else None
    if not me:
        me = db.create_player(b.device_id or phone.replace("+", "dev"), "Patron")
    db.link_phone(me["id"], phone)
    me = db.get_by_id(me["id"])
    return {"token": me["token"], "player": _public(me), "state": me.get("state_blob", "")}


@app.get("/rajon/me")
def me(authorization: str = Header(None)):
    """Token'a karşılık gelen oyuncu profili (SMS token'ı ile giriş için)."""
    p = auth(authorization)
    return {"player": _public(p)}


@app.post("/rajon/state/push")
def state_push(b: StatePushBody, authorization: str = Header(None)):
    """Tüm oyun durumunu (kayıt blob'u) hesaba yedekle."""
    p = auth(authorization)
    db.set_state_blob(p["id"], b.blob[:500_000])  # ~500KB sınır
    return {"ok": True}


@app.get("/rajon/state/pull")
def state_pull(authorization: str = Header(None)):
    """Hesabın yedeklenmiş oyun durumunu getir."""
    p = auth(authorization)
    me = db.get_by_id(p["id"])
    return {"state": (me or {}).get("state_blob", "")}


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
