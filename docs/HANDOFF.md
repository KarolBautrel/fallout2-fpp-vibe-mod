# Punkt wznowienia

Stan zapisany 23 października 2026. Projekt można wznowić od razu na branchu
`prototype/iso-fpp`.

## Lokalizacja i Git

- katalog roboczy: `C:\Users\karol\AppData\Local\Temp\vibe-modding\repos\fallout2-perspective-remix`;
- docelowa lokalizacja użytkownika: `C:\Users\karol\Desktop\vibe-modding`;
- sandbox nie dostał prawa zapisu do Pulpitu, dlatego projekt pozostał w katalogu tymczasowym;
- aktywny branch: `prototype/iso-fpp`;
- ostatni ukończony commit przed tym handoffem: `8f92ff6`.

## Co działa

- Python 3.14.3 przez launcher `py`;
- projektowe `.venv`;
- parser katalogu Fallout 2 DAT z obsługą zlib;
- parser nagłówka MAP, zmiennych i warstw podłoga/dach;
- eksport `fo2remix.scene-v1` do JSON;
- 16 testów oraz Ruff;
- projektowy skill `.codex/skills/fallout2-fpp-vibe-mod`.

Na prawdziwym `master.dat` znaleziono 23 140 wpisów i 155 map. Mapa
`maps\artemple.map` została rozpakowana do ignorowanego `artifacts/` i
wyeksportowana jako `artemple.scene-v1.json`. Instalacja Steam jest traktowana
wyłącznie jako źródło do odczytu.

## Środowisko

Wykryte:

- Git 2.55;
- Python 3.14.3;
- Fallout 2 Steam w `C:\Program Files (x86)\Steam\steamapps\common\Fallout 2`.

Brakujące:

- CMake;
- Visual Studio Build Tools z workloadem C++;
- checkout `fallout2-ce` w `engine/fallout2-ce`.

Godot nie jest brakującym narzędziem. Znaleziono i uruchomiono istniejący
`Godot 4.7 stable`:

`C:\Users\karol\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`

Znaleziono też poprzedni projekt:

`C:\Users\karol\Desktop\Gierka\game_dir\sdd-game\project.godot`

`winget.exe` i App Installer 1.29.380.0 są obecne, ale w sandboxie każde
wywołanie `winget` kończy się przed wykonaniem polecenia błędem `0x8A150001`.
Brak też dostępnej przeglądarki sterowalnej przez agenta. Instalację trzeba
wykonać w zwykłym PowerShellu użytkownika lub ręcznie ze stron producentów.

## Polecenia po wznowieniu

Po zainstalowaniu narzędzi:

```powershell
cd "C:\Users\karol\AppData\Local\Temp\vibe-modding\repos\fallout2-perspective-remix"
.\scripts\check-prereqs.ps1
.\scripts\bootstrap.ps1 -Python py -InstallDependencies
.\.venv\Scripts\python.exe -m pytest
```

Do czasu dodania Godota do `PATH` sprawdzenie należy wykonać tak:

```powershell
.\scripts\check-prereqs.ps1 -GodotPath "$env:USERPROFILE\Desktop\Gierka\installers\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
```

Jeśli projekt zostanie wcześniej skopiowany na Pulpit, należy użyć nowej
lokalizacji zamiast ścieżki z `AppData\Local\Temp`.

## Następny etap

1. Potwierdzić CMake, kompilator i Godot przez `check-prereqs.ps1`.
2. Sklonować i przypiąć commit `alexbatalov/fallout2-ce`.
3. Stworzyć minimalny projekt Godot czytający `artemple.scene-v1.json`.
4. Wyrenderować siatkę 100 × 100 materiałami debugowymi.
5. Umieścić marker gracza na heksie `18492`.
6. Dodać kamery ISO i FPP korzystające z jednego stanu pozycji; FPP ma być widokiem z oczu postaci.
7. Następnie rozpoznać obiekty, kolizje, prototypy i format FRM.

Nie kopiować do Git oryginalnych `.dat`, `.map`, `.frm`, dźwięków ani filmów.
