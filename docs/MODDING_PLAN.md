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

- kamera izometryczna;
- kamera FPP na wysokości oczu postaci, bez kamery za plecami;
- wspólny stan pozycji i zaznaczenia;
- przełączanie bez teleportacji i zmiany aktywnego heksa.

### M4 — interakcja

- jedno działające drzwi lub obiekt;
- ten sam rezultat w ISO i FPP;
- zapis logu wejścia, pozycji i wyniku.

## Kryterium decyzji

- **Integracja:** geometria i sterowanie są wiarygodne — podłączamy stan `fallout2-ce` lub przenosimy renderer do forka.
- **Hybryda:** dane logiczne są dobre, ale obraz 3D wymaga ręcznych poprawek — dodajemy per-map metadata.
- **Pivot:** dane mapy nie wystarczają — robimy tryb FPP tylko dla ręcznie odtworzonych lokacji.

