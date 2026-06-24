# Rajon

Sokak mafyası temalı, tur tabanlı strateji oyunu (iOS / SwiftUI).
*Mafia III: Rivals* tarzı oynanışın yerli, argo dilli alternatifi.

## Oynanış döngüsü
1. **Üs** — İşletmelerden (haraç) zamanla nakit birikir, topla. İşletme al/yükselt.
2. **Devşir** — Parayla sokaktan rasgele adam çek (gacha, 5 nadirlik kademesi).
3. **Ekip** — En iyi 4 adamı sahaya diz, adamları yükselt.
4. **Sokak** — Rakip çeteleri tur tabanlı çatışmada dağıt, sokakları ele geçir.
   Kazandıkça nakit + itibar + bazen bedava adam.

## Mimari (native SwiftUI, iOS 17+, iPhone-only)
- `Sources/Models` — Enforcer, Racket, RivalNode, Rarity, Klas
- `Sources/Engine` — GameStore (kayıt + idle ekonomi), CombatEngine (tur motoru), Factory
- `Sources/Views` — Üs / Ekip / Sokak / Devşir / Dövüş ekranları + tema
- `Sources/Content` — argo/sokak dili içeriği (isimler, laflar, çeteler)

Offline çalışır, hesap/backend yok. Tüm durum cihazda `rajon_save.json`.

## Build
XcodeGen ile `.xcodeproj` üretilir, CI'da (macos-26 + Xcode 26) arşivlenip TestFlight'a yüklenir.
```
cd Rajon-iOS && xcodegen generate && open Rajon.xcodeproj
```
