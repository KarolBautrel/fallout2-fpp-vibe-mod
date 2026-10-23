# Billboardy z oryginalnych danych Fallouta 2

Warstwa FPP używa hybrydy. Podłogi, ściany, schody i sufity pozostają geometrią
3D rekonstruowaną z `MAP`/`PRO`. Postacie, drobne obiekty i efekty korzystają z
przezroczystych klatek `FRM`, które są dekodowane lokalnie z legalnie posiadanych
archiwów użytkownika.

## Automatyczny przepływ

```powershell
.\scripts\refresh-billboard-cache.ps1
```

Skrypt czyta `master.dat` i `critter.dat` tylko do odczytu, eksportuje ARTEMPLE
oraz ARCAVES do `artifacts/*.scene-v1.json`, a następnie buduje ignorowany cache
PNG pod `artifacts/art-cache/<map>`. Żaden oryginalny asset nie trafia do Gita.

Resolver critterów jest portem reguł `artBuildFilePath`, `_art_get_code` i
`artAliasFid` z przypiętego `fallout2-ce`. Cache zapisuje wszystkie sześć rotacji
postaci i wszystkie klatki animacji. Na danych użytkownika potwierdzono co najmniej
dwa niezależne FID-y: `nmwarrga.frm`, `mascp2aa.frm` oraz `maanttaa.frm`.

## Tryby renderowania

- `directional_6`: NPC/przeciwnik; dobiera jedną z sześciu rotacji na podstawie
  kierunku postaci i położenia aktywnej kamery.
- `billboard_y`: wolnostojący rekwizyt lub mebel z jednym użytecznym rzutem
  źródłowym (obecnie skrzynie, wazy i ławki `TEMPSF04/05`) albo efekt obracany
  wokół osi pionowej.
- `billboard_screen`: efekt zawsze skierowany pełną płaszczyzną do kamery.
- `billboard_fixed`: dekoracja ścienna zachowująca rotację obiektu z mapy.
- `billboard_cross`: dwie prostopadłe karty, obecnie dla drzew.
- `ground_decal`: płaska karta tuż nad podłogą, obecnie dla kości.

Każdy quad ma pivot przy dolnym środku, alpha-scissor, brak filtrowania liniowego
i zachowuje kolory źródłowej palety. Dobór trybu jest rodzinny i znajduje się w
`godot/data/fallout_art_profiles.json`, więc nie konfigurujemy każdej mapy osobno.

## Kontrola jakości

Skill `ai3d-transparent-billboard-asset` jest zainstalowany w katalogu użytkownika
Codexa. W tym projekcie używamy jego audytora przezroczystości do lokalnych PNG;
nie kopiujemy skilla do repo, ponieważ jego repozytorium nie publikuje jawnego
pliku licencji. Audyt prawdziwego crittera, drzewa i pochodni potwierdził brak
białej obwódki i brak półprzezroczystej maty. Oryginalne FRM-y mają ciasne płótno,
więc audyt oznacza ich brzegi jako wymagające oględzin, ale nie jako regenerację.

Billboarding nie tworzy brakującej bryły ani tylnej strony architektury. Dlatego
budynki, ściany, schody, drzwi, sufity i obiekty wymagające czytelnej głębi używają
geometrii 3D. NPC i potwory korzystają z sześciu kierunków FRM. Wolnostojące
obiekty mogą używać `billboard_y`, ale wygląd i fizyka pozostają rozdzielone:
skrzynia jest oryginalnym sprite'em Fallouta oraz niewidocznym, nieruchomym
colliderem, więc obrót karty do kamery nie zmienia blokowania ruchu. Pochodnia
ścienna zachowuje kotwicę obiektu z MAP, a jej przycięty uchwyt i płomień obracają
się tylko wokół osi Y, aby zachować czytelność z perspektywy FPP. Dwanaście klatek
płomienia jest wycinanych z `firepit.frm`; maska koloru usuwa kamienną misę, nie
generując ani nie domalowując nowych pikseli.
Nieznana sceneria jest domyślnie ukryta do czasu sklasyfikowania.

`TEMPSF05` jest narożną ławką, chociaż wadliwy source-solid wyglądał w FPP jak
rozcięta skrzynia. Obie rodziny ławek zachowują blokowanie z `blocking_hexes`
MAP/PRO; billboard zastępuje tylko widok. Nie dodajemy drugiej kolizji obracanej
razem z kamerą.

## Skala FPP

Wspólną skalę aktorów kalibrujemy na ludzkim FRM `nmwarraa`: 63-66 px przy
36 px/m daje około 1,75-1,83 m. Oczy gracza są na 1,62 m, a pionowe FOV wynosi
65 stopni. Dzięki temu kamera nie góruje nad ludźmi i rekwizytami; skali nie
dobieramy osobno dla każdego kadru.
