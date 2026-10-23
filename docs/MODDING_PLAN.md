# Plan techniczny

## Stan rozpoznania

- Gra: Fallout 2 ze Steam, AppID `38410`, build `303136`.
- Instalacja: `C:\Program Files (x86)\Steam\steamapps\common\Fallout 2`.
- Dane obecne: `master.dat`, `critter.dat`, `patch000.dat`, katalogi `data` i `sound`.
- Bazowy silnik: `alexbatalov/fallout2-ce`, działająca reimplementacja wymagająca danych użytkownika.
- Tryb: offline, single-player.

## Decyzja architektoniczna

Pierwszy pionowy wycinek powstanie jako parser/eksporter plus niezależny renderer Godot. Nie zaczynamy od wymiany renderera wewnątrz `fallout2-ce`, ponieważ najpierw trzeba sprawdzić, ile geometrii da się wiarygodnie odtworzyć z danych mapy.

### Przepływ danych

`instalacja Fallout 2 (read-only) -> parser -> scene-v1.json -> Godot -> ISO/FPP`

`fallout2-ce` pełni rolę dokumentacji wykonywalnej i późniejszego źródła symulacji.

## Kamienie milowe

### M0 — środowisko

- Python 3.13 i `.venv`;
- Git, CMake, MSVC Build Tools;
- Godot 4.7.x stable;
- źródła `fallout2-ce` w `engine/fallout2-ce`;
- czysty build oryginalnego CE.

### M1 — inwentaryzacja formatu

- [x] znaleźć ścieżkę ładowania `.dat` i `.map` w `fallout2-ce`;
- [x] zapisać znaczenie współrzędnych kafli/heksów i poziomów;
- [x] wybrać małą mapę testową (`maps\artemple.map`);
- [x] stworzyć pierwszy schemat `scene-v1.json` dla podłóg i dachów;
- [x] rozszerzyć schemat o obiekty, prototypy i kolizje.

### M2 — geometria debugowa

- [x] podłoga i siatka heksowa;
- [x] ściany jako proste bryły;
- [x] drzwi i obiekty jako kolorowe placeholdery;
- [x] test zgodności kilku znanych pozycji;
- [x] runtime test, że collider ściany nie wpuszcza gracza na blokowany heks.

### M3 — kamery i sterowanie

- [x] kamera izometryczna;
- [x] kamera FPP na wysokości oczu postaci, bez kamery za plecami;
- [x] wspólny stan pozycji i zaznaczenia;
- [x] przełączanie bez teleportacji i zmiany aktywnego heksa.

### M4 — interakcja

- [x] jeden działający obiekt blokującej scenerii;
- [x] ten sam `instance_id` i rezultat w ISO i FPP;
- [x] zapis ID, heksu, pozycji, dystansu i wyniku w
  `artifacts/godot-interaction-runtime.json`.

## Kryterium decyzji

- **Integracja:** geometria i sterowanie są wiarygodne — podłączamy stan `fallout2-ce` lub przenosimy renderer do forka.
- **Hybryda:** dane logiczne są dobre, ale obraz 3D wymaga ręcznych poprawek — dodajemy per-map metadata.
- **Pivot:** dane mapy nie wystarczają — robimy tryb FPP tylko dla ręcznie odtworzonych lokacji.

## M5 — wspólny stan z silnikiem

- [x] skonfigurować REA/Ghidrę i potwierdzić punkty integracji względem
  `fallout2-ce`;
- [x] dodać do lokalnego forka `fallout2-ce` read-only bridge JSONL;
- [x] dodać odbiornik Godot z trybem obserwacji, autorytetem CE i testem
  przyrostowego JSONL;
- [ ] zsynchronizować `map_loaded`, `player_moved` i `interaction` z Godotem;
- [ ] potwierdzić zgodność heksa, elevation, rotacji oraz celu interakcji w ISO
  i FPP;
- [ ] dopiero po tym zdecydować, czy potrzebny jest hook retailowego EXE.

Szczegóły i potwierdzone adresy: `docs/REA_INTEGRATION.md`.

