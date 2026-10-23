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
- 16 testów i Ruff;
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

Na prawdziwym `master.dat` znaleziono 23 140 wpisów i 155 map. Dla
`ARTEMPLE.MAP` eksport zawiera spawn na heksie `18492`, kolumnę `107`,
wiersz `92`, elevation `0` i jedną warstwę 100 × 100.

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
modyfikowane.

## Godot ISO/FPP

Projekt: `godot/project.godot`.

Sterowanie:

- `Tab`: ISO/FPP;
- mysz: rozglądanie w FPP, `Esc` zwalnia kursor;
- `W` / `S`: przód/tył;
- `A` / `D`: strafe lewo/prawo;
- `Shift`: sprint.

Transformacja współrzędnych jest opisana w `docs/COORDINATES.md`. Stan
logiczny zachowuje indeks heksa; kamery tylko go obserwują.

## Dowody w artifacts

- logi prerekwizytów, konfiguracji, buildu i uruchomienia `fallout2-ce`;
- `fallout2-ce-build-evidence.json`;
- `godot-iso-fpp-contract.json`;
- `godot-movement-runtime.json` — rzeczywisty test strafe `D` przez 30
  klatek fizyki;
- `godot-preview00000002.png` — widok ISO;
- `godot-fpp-preview00000002.png` — widok FPP;
- `godot-headless-contract-2026-10-23.log`.

Oryginalne `.dat`, `.map`, `.frm`, audio, filmy i save'y pozostają poza
Gitem. Instalacja Steam jest traktowana wyłącznie jako źródło do odczytu.

## Następny konkretny etap

Rozszerzyć parser i `scene-v1` o nagłówki obiektów mapy, co najmniej ściany,
drzwi i flagi blokowania. Najpierw należy potwierdzić format na dwóch rekordach
w `fallout2-ce/src/object.*`, `map.*` i `proto.*`. Dopiero wtedy debugowy
renderer może dostać kolizje oraz pierwszą wspólną interakcję ISO/FPP.
