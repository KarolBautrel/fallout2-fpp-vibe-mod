# Środowisko

Stan potwierdzony 23 października 2026.

## Wykryte narzędzia

- Git `2.55.0.windows.2`;
- Python `3.14.3` przez launcher `py` oraz działające projektowe `.venv`;
- CMake `4.5.0-rc1`;
- Visual Studio Build Tools 2022 `17.14.42`;
- MSVC x64 `14.44.35207`;
- Windows SDK `10.0.26100.0`;
- Godot `4.7.stable` w `Desktop\Gierka\installers`;
- Fallout 2 Steam w `C:\Program Files (x86)\Steam\steamapps\common\Fallout 2`.

`scripts/check-prereqs.ps1` wykrywa MSVC także ze zwykłego PowerShella przez
`vswhere`; nie trzeba uruchamiać Developer PowerShell.

## Bazowy build fallout2-ce

Źródła są lokalnie w ignorowanym `engine/fallout2-ce`. Checkout jest przypięty
w trybie detached do commita:

```text
e97087b9582f37075db347a89898887320753f8b
v1.3.0-59-ge97087b
```

Konfiguracja dla Visual Studio 2022 x64:

```powershell
cmake -S engine\fallout2-ce `
  -B engine\fallout2-ce\out\build\windows-x64-vs2022 `
  -G "Visual Studio 17 2022" -A x64 `
  "-DCMAKE_POLICY_VERSION_MINIMUM:STRING=3.5"
```

Flaga zgodności jest wymagana przez CMake 4.5 dla vendored SDL2 2.26.1. Nie
wymaga modyfikowania źródeł upstreamu.

Build:

```powershell
cmake --build engine\fallout2-ce\out\build\windows-x64-vs2022 `
  --config Release --verbose
```

Wynik bazowy: `fallout2-ce.exe`, 0 błędów i 256 ostrzeżeń upstreamu/MSVC.
SHA-256 nieinstrumentowanej binarki:

```text
7C7FA0F790A4D9E394B5F49FD7BED9B59A4141D7E5B2AE22D6EF00AD118E92ED
```

Pierwsza próba z `--parallel` zakończyła się kodem 1 przy generowaniu
nagłówków SDL. Powtórzenie sekwencyjne zakończyło się powodzeniem.

Lokalny checkout ma obecnie nałożony wersjonowany bridge z
`integration/fallout2-ce`. Instrumentowany build Release x64 również kończy
się bez błędów. Aktualna binarka ma SHA-256:

```text
651A0AEF2E7B1CAD8D3790C15AC3B08BFA69F56733D19B867230229EE59F594A
```

Instrukcje odtworzenia i testu: `docs/STATE_BRIDGE.md`.

## Uruchomienie referencyjne

Instrumentowane `fallout2-ce` czyta archiwa z instalacji Steam, lecz launcher
ustawia zapisywalny katalog roboczy i oba katalogi patches na
`artifacts/fallout2-ce-runtime`. Dzięki temu mapowe `.SAV`, `worldmap.dat` i
pozostały stan sesji nie są zapisywane do instalacji Steam. Launcher kopiuje
zbudowaną przez nas binarkę z ignorowanego checkoutu `engine/fallout2-ce` do
runtime; nie kopiuje żadnego archiwum ani assetu gry.

## Prototyp Godot

Projekt znajduje się w `godot/` i działa na Godot 4.7. Domyślnie wczytuje
ignorowany `artifacts/artemple.scene-v1.json`; argument `--map=arcaves` wybiera
`artifacts/arcaves.scene-v1.json`. Generuje wszystkie niepuste komórki podłogi
na każdym wyeksportowanym elevation oraz wspólny stan gracza z kamerami ISO i
FPP. W trybie bridge zdarzenie
`map_loaded` automatycznie przełącza aktywną geometrię między tymi dwiema
mapami.

Walidacja headless:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path godot --quit-after 2
```

W sandboxie warto przekierować `APPDATA` procesu do `artifacts/godot-user`,
ponieważ Godot próbuje tworzyć `user://logs`.

Walidacja odbiornika bridge’a:

```powershell
& "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" `
  --headless --path godot -- --bridge-probe
```

## REA i Ghidra

Projekt ma lokalny, przypięty toolchain REA w ignorowanym `artifacts/tools/`.
Uruchamia go wersjonowany wrapper:

```powershell
.\scripts\run-rea.ps1 doctor --provider ghidra --format json
```

Wersje, sumy kontrolne, tożsamość analizowanej binarki oraz odtwarzalne
polecenia są zapisane w `docs/REA_INTEGRATION.md`.

## Kontrola projektu

```powershell
.\scripts\check-prereqs.ps1 -GodotPath `
  "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
.\.venv\Scripts\python.exe -m pytest
.\.venv\Scripts\python.exe -m ruff check .
```

Aktualny wynik: komplet prerekwizytów, 16 testów zaliczonych i Ruff bez błędów.

