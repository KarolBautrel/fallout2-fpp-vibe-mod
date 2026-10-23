# Fallout 2 Perspective Remix

Eksperymentalny projekt dodający do Fallouta 2 przełączanie między klasycznym widokiem izometrycznym a kamerą TPP, z możliwością późniejszego dodania FPP.

## Pierwszy cel

Jedna mała lokacja, w której:

- pozycje i kolizje pochodzą z danych Fallouta 2;
- postać porusza się po oryginalnej siatce heksowej;
- kamera przełącza się między ISO i TPP bez utraty stanu;
- działa co najmniej jedna interakcja z drzwiami albo obiektem;
- dane gry są czytane wyłącznie z legalnej instalacji użytkownika.

## Wybrana architektura na start

1. `fallout2-ce` jest źródłem prawdy dla formatów, logiki i współrzędnych.
2. Mały parser/eksporter w Pythonie tworzy neutralny opis jednej mapy.
3. Prototyp 3D w Godot wczytuje opis i generuje uproszczoną geometrię.
4. Po sprawdzeniu sterowania decydujemy, czy renderer pozostaje klientem zewnętrznym, czy wchodzi bezpośrednio do forka `fallout2-ce`.

To ogranicza ryzyko: najpierw potwierdzamy mapowanie świata, a dopiero potem przebudowujemy silnik.

## Repozytorium

- aktywny branch: `prototype/iso-tpp`;
- instalacja gry: `C:\Program Files (x86)\Steam\steamapps\common\Fallout 2`;
- źródła silnika mają trafić do `engine/fallout2-ce` i są ignorowane przez nadrzędne repo;
- oryginalne assety, pliki `.dat`, rozpakowane mapy i save'y nie mogą trafić do Git.

## Start

Po zainstalowaniu Pythona, CMake, MSVC Build Tools i Godota:

```powershell
.\scripts\bootstrap.ps1 -Python py -InstallDependencies
.\.venv\Scripts\python.exe -m pytest
```

Stan środowiska można sprawdzić bez zmian w systemie:

```powershell
.\scripts\check-prereqs.ps1
```

Archiwum zainstalowanej gry można bezpiecznie przejrzeć bez jego modyfikacji:

```powershell
.\.venv\Scripts\python.exe -m fo2remix dat-list `
  "C:\Program Files (x86)\Steam\steamapps\common\Fallout 2\master.dat" `
  --suffix .map
```

Nagłówek jednej mapy można sprawdzić i opcjonalnie skopiować mapę do
ignorowanego przez Git katalogu `artifacts/`:

```powershell
.\.venv\Scripts\python.exe -m fo2remix map-extract `
  "C:\Program Files (x86)\Steam\steamapps\common\Fallout 2\master.dat" `
  "maps\artemple.map" --output artifacts\artemple.map
```

Pierwszy neutralny opis sceny dla przyszłego renderera Godot:

```powershell
$env:PYTHONPATH = (Join-Path (Get-Location) 'src')
.\.venv\Scripts\python.exe -m fo2remix scene-export `
  "C:\Program Files (x86)\Steam\steamapps\common\Fallout 2\master.dat" `
  "maps\artemple.map" artifacts\artemple.scene-v1.json
```

Szczegóły znajdują się w `docs/MODDING_PLAN.md` oraz `docs/ENVIRONMENT.md`.

