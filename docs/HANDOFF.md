# Punkt wznowienia

Stan zapisany 23 października 2026. Projekt jest na branchu
`prototype/iso-fpp` w katalogu:

```text
C:\Users\karol\Documents\vibe-modding\fallout2-fpp-vibe-mod
```

## Git

- branch: `prototype/iso-fpp`;
- upstream: `origin/prototype/iso-fpp`;
- bieżący hash należy potwierdzić przez `git rev-parse HEAD`;
- historia obejmuje bazowy build `fallout2-ce`, prototyp Godot ISO/FPP oraz
  pełny kontroler ruchu WASD.

## Ukończone etapy

- read-only parser Fallout 2 DAT z obsługą zlib;
- parser nagłówka MAP, zmiennych i warstw podłoga/dach;
- eksport `fo2remix.scene-v1` do JSON;
- eksport `maps\artemple.map` do ignorowanego
  `artifacts\artemple.scene-v1.json`;
- 20 testów i Ruff;
- zainstalowany i wykrywany toolchain MSVC/CMake;
- sklonowany oraz przypięty niezmieniony `fallout2-ce`;
- udany build Release x64;
- udane uruchomienie na danych Steam z responsywnym oknem `FALLOUT II`;
- minimalny renderer Godot z 10 000 komórek podłogi;
- wspólny stan gracza na heksie `18492`;
- działające przełączanie ISO/FPP bez zmiany stanu;
- kamera FPP na wysokości oczu `1.68`, bez offsetu TPP.
- pełny kontroler `CharacterBody3D`: WASD, strafe, sprint, mysz, akceleracja,
  hamowanie i kapsuła kolizji;
- reużywalny rdzeń ruchu opublikowany jako repo MIT
  `KarolBautrel/godot-classic-fpp-controller`, oznaczony `v0.2.0` i podłączony
  jako przypięty submodule w `godot/addons/classic_fpp_controller`;
- kontroler `v0.2.0` ma automatyczny step-up oraz headless arena test dla
  ścian, narożnika, pochylni, ground snapu i sześciu fizycznych stopni;
- osobny adapter Fallouta zachowany w
  `godot/scripts/fallout_player_controller.gd`;
- odwrotne mapowanie ciągłej pozycji świata do najbliższego heksa Fallouta.
- parser skryptów i pełnej sekcji obiektów MAP, w tym rekurencyjnych
  ekwipunków oraz typów instancji zależnych od `.pro`;
- resolver prototypów zgodny z 1-based listami `proto/<type>/<type>.lst`;
- `scene-v1` rozszerzone o ściany, scenerię, drzwi, flagi i blokowane heksy;
- debugowa geometria Godot oraz 419 colliderów dla blokad `ARTEMPLE.MAP`;
- runtime probe potwierdzający, że ściana ID `164` blokuje heks `15284`.
- eksport nadaje każdemu rekordowi stabilne `instance_id`, ponieważ prawdziwe
  `object_id` MAP nie jest unikalne (55 powtarzających się wartości w 116
  rekordach `ARTEMPLE.MAP`);
- wspólna interakcja ISO/FPP z blokującą scenerią: celowanie środkiem kamery w
  FPP, wybór kliknięciem w ISO, klawisz `E`, wspólny stan `activated` i
  zachowanie wyboru podczas przełączania kamery;
- runtime probe potwierdzający ten sam `instance_id = 0`, źródłowe
  `object_id = 16` i identyczny wynik w ISO oraz FPP.

Na prawdziwym `master.dat` znaleziono 23 140 wpisów i 155 map. Dla
`ARTEMPLE.MAP` eksport zawiera spawn na heksie `18492`, kolumnę `107`,
wiersz `92`, elevation `0`, jedną warstwę 100 × 100, 567 obiektów, 45 ścian,
397 rekordów scenerii i 419 blokowanych heksów. Mapa nie ma drzwi. Format
drzwi potwierdzono dodatkowo na 24 rekordach z `KLAMALL.MAP`.

## fallout2-ce jako oracle

Checkout znajduje się w ignorowanym `engine/fallout2-ce` i jest przypięty w
trybie detached do:

```text
e97087b9582f37075db347a89898887320753f8b
v1.3.0-59-ge97087b
```

Build znajduje się w:

```text
engine\fallout2-ce\out\build\windows-x64-vs2022\Release\fallout2-ce.exe
```

Konfiguracja CMake wymaga
`-DCMAKE_POLICY_VERSION_MINIMUM:STRING=3.5`, ponieważ CMake 4.5 usunął tryb
kompatybilności używany przez vendored SDL2 2.26.1. Źródła upstreamu nie były
modyfikowane podczas bazowego buildu. Obecnie lokalny checkout ma nałożoną
wersjonowaną nakładkę bridge’a z `integration/fallout2-ce`; można ją odtworzyć
przez `scripts/apply-fallout2-ce-bridge.ps1`.

## Godot ISO/FPP

Projekt: `godot/project.godot`.

Zasada pracy: przed uruchomieniem wersji po każdej aktualizacji zamknąć
wszystkie starsze okna tego projektu i pozostawić dokładnie jedno świeże okno
Godota, żeby użytkownik nie testował nieaktualnego procesu.

Sterowanie:

- `Tab`: ISO/FPP;
- mysz: rozglądanie w FPP, `Esc` zwalnia kursor;
- `W` / `S`: przód/tył;
- `A` / `D`: strafe lewo/prawo;
- `Shift`: sprint.
- `E`: interakcja;
- w ISO: lewy przycisk myszy wybiera blokującą scenerię;
- w FPP: cel interakcji wskazuje środek ekranu.

Transformacja współrzędnych jest opisana w `docs/COORDINATES.md`. Stan
logiczny zachowuje indeks heksa; kamery tylko go obserwują.

## Dowody w artifacts

- logi prerekwizytów, konfiguracji, buildu i uruchomienia `fallout2-ce`;
- `fallout2-ce-build-evidence.json`;
- `godot-iso-fpp-contract.json`;
- `godot-movement-runtime.json` — rzeczywisty test strafe `D` przez 30
  klatek fizyki;
- `godot-blocking-runtime.json` — rzeczywisty test kolizji ze ścianą;
- `godot-interaction-runtime.json` — ten sam cel i wynik interakcji w ISO/FPP;
- `godot-bridge-runtime.json` — odbiór czterech zdarzeń CE, przyrostowy JSONL,
  zastosowanie heksa/rotacji i wspólnego `instance_id`;
- `artemple.scene-v1.objects.json` i `klamall.scene-v1.objects.json` —
  dowody pełnego odczytu obiektów z danych użytkownika;
- `godot-preview00000002.png` — widok ISO;
- `godot-fpp-preview00000002.png` — widok FPP;
- `godot-headless-contract-2026-10-23.log`.

Oryginalne `.dat`, `.map`, `.frm`, audio, filmy i save'y pozostają poza
Gitem. Instalacja Steam jest traktowana wyłącznie jako źródło do odczytu.

## Następny konkretny etap

REA 6.7.0, Ghidra 12.1.4 i wymagany przenośny toolchain są skonfigurowane
lokalnie. Analiza retailowego `fallout2.exe` potwierdziła względem źródeł
`fallout2-ce` trzy punkty integracji: `mainLoop` (`0x480E48`), `mapLoad`
(`0x482B74`) i `objectSetLocation` (`0x48A568`) oraz `gDude` pod `0x6610B8`.
Szczegóły i dowód odtworzenia są w `docs/REA_INTEGRATION.md`.

Lokalny, instrumentowany `fallout2-ce` emituje już read-only JSONL ze
zdarzeniami `map_loaded`, `player_moved` oraz `interaction`. Nakładka, skrypty
odtworzenia i test kontraktu są opisane w `docs/STATE_BRIDGE.md`. Pełny build
Release x64 i test czterech zdarzeń przechodzą.

Godot ma już odbiornik JSONL. Domyślnie obserwuje trace i raportuje zgodność w
HUD, a `--bridge-live` czyni CE autorytetem, wyłącza lokalny ruch i stosuje
`map_loaded`, `player_moved` oraz udane `interaction`. Headless probe potwierdza
cztery zdarzenia, przyrostowe dopisywanie, buforowanie niepełnej linii,
przejście z heksa `18492` na `18491`, rotację `2` i aktywację `instance_id = 0`
/ `object_id = 16`.

Następny konkretny etap to test end-to-end dwóch prawdziwych procesów:
`fallout2-ce` → plik JSONL → Godot `--bridge-live`, z jednym ruchem i jedną
interakcją użytkownika. Nie należy jeszcze hookować ani modyfikować retailowego
EXE.
