# Środowisko

## Wykryte

- Git `2.55.0.windows.2`;
- Node.js i npm;
- Python `3.14.3` dostępny przez launcher `py`;
- działające projektowe `.venv` korzystające z systemowych pakietów bazowych;
- przenośny Godot `4.7 stable` w `Desktop\Gierka\installers`;
- Fallout 2 Steam w oczekiwanej lokalizacji.

## Brakujące

- CMake;
- Visual Studio Build Tools z workloadem Desktop development with C++;
- źródła `fallout2-ce` — terminal w tej sesji ma zablokowane połączenia pobierające.

Próba globalnej instalacji przez `winget` została wykonana. Python został
rozpoznany, natomiast instalacja CMake zatrzymała się na błędzie `0x8A150001`
środowiska App Installer. Ten sam skrypt powinien zadziałać w zwykłym terminalu
Windows z dostępem do źródeł `winget`.

## Docelowe wersje

- Python: obecne 3.14.3 spełnia wymaganie projektu `>=3.13`;
- CMake: bieżące stabilne 4.x;
- MSVC: aktualny toolset x64 z Visual Studio Build Tools 2026;
- Godot: istniejące 4.7 stable, wersja standardowa bez .NET;
- `fallout2-ce`: przypięty commit zapisany po pierwszym udanym klonowaniu.

## Instalacja w zwykłym terminalu użytkownika

Uruchom PowerShell i wykonaj:

```powershell
.\scripts\install-global-tools.ps1
```

Po ponownym otwarciu terminala:

```powershell
.\scripts\bootstrap.ps1 -Python py -InstallDependencies
```

Opcjonalny, szerszy pakiet Universal Modder można dodać osobno:

```powershell
.\scripts\install-optional-universal-modder.ps1
```

Projektowy skill w `.codex/skills/fallout2-perspective-remix` nie wymaga globalnej instalacji i pozostaje wersjonowany razem z projektem.

## Dlaczego nie instalujemy teraz Ghidry i Blendera

Kod silnika jest dostępny, więc Ghidra nie jest potrzebna do pierwszej fazy. Blender stanie się potrzebny dopiero wtedy, gdy placeholdery zostaną zastąpione prawdziwą geometrią lub assetami.

