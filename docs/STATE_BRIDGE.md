# Bridge stanu `fallout2-ce` → Godot

Stan implementacji: 23 października 2026.

Bridge jest opcjonalną, read-only instrumentacją przypiętego commita
`fallout2-ce` `e97087b9582f37075db347a89898887320753f8b`. Nie zmienia instalacji Steam,
nie zapisuje danych gry i nie jest aktywny bez zmiennej środowiskowej
`FALLOUT2_FPP_BRIDGE_PATH`.

## Odtworzenie

Na czystym checkoutcie przypiętego `fallout2-ce`:

```powershell
.\scripts\apply-fallout2-ce-bridge.ps1
cmake --build engine\fallout2-ce\out\build\windows-x64-vs2022 `
  --config Release --verbose
.\scripts\test-fallout2-ce-bridge.ps1
```

Uruchomienie instrumentowanej gry:

```powershell
.\scripts\run-fallout2-ce-bridge.ps1
```

Skrypt czyta `master.dat`, `critter.dat` i `patch000.dat` z instalacji Steam,
ale uruchamia grę z zapisywalnym katalogiem roboczym
`artifacts/fallout2-ce-runtime`. Kopiuje tam wyłącznie zbudowaną przez nas
binarkę CE i generuje lokalne `fallout2.cfg`/`ddraw.ini`; oryginalne archiwa nie
są kopiowane. `master_patches` i `critter_patches` wskazują na podkatalog
runtime `data`, więc pliki `.SAV`, `worldmap.dat` i inne nadpisania nie trafiają
do instalacji Steam. Trace jest zapisywany do
`artifacts/fallout2-ce-state.jsonl`.

Przy pierwszym teście dłuższa ścieżka runtime ujawniła upstreamowy bufor
`char temp[80]` w `_map_save()`. Zapis `ARTEMPLE.SAV` przepełniał stos i kończył
proces kodem `0xc0000409`. Wersjonowana nakładka zamienia go na
`COMPAT_MAX_PATH` i dwa ograniczone `snprintf`; test bridge'a sprawdza obecność
tej poprawki, a build Release przechodzi bez ostrzeżeń.

## Kontrakt `fo2remix.bridge-v1`

Każdy wiersz jest osobnym obiektem JSON. Pole `sequence` rośnie w ramach
procesu, a `schema` ma zawsze wartość `fo2remix.bridge-v1`.

### `session_started`

Pierwszy rekord potwierdza otwarcie kanału.

```json
{"schema":"fo2remix.bridge-v1","sequence":0,"event":"session_started"}
```

### `map_loaded`

Emitowany po pomyślnym zakończeniu `mapLoad`, gdy mapa, skrypty, gracz i rotacja
są już ustawione.

```json
{"schema":"fo2remix.bridge-v1","sequence":1,"event":"map_loaded","map":{"name":"ARTEMPLE.MAP","index":1},"player":{"object_id":18000,"pid":16777216,"hex_index":18492,"elevation":0,"rotation":1}}
```

### `player_moved`

Emitowany w `mainLoop` tylko wtedy, gdy zmienił się heks, elevation albo
rotacja `gDude`. Niezmienione klatki nie generują duplikatów.

### `interaction`

Emitowany po `_obj_use`. Zawiera stan aktora, rezultat funkcji oraz cel.
`target.instance_id` jest nadawane przy `objectLoadAll` w tej samej kolejności
rekordów MAP, której używa eksporter `scene-v1`, więc pozostaje wspólnym ID dla
silnika i Godota.

### `object_state`

Emitowany z callbacka animacji drzwi po zmianie ich flagi otwarcia. Zawiera tę
samą tożsamość celu oraz `state.kind = "door"`, `open`, `locked`, `jammed` i
`blocks_movement`. Godot obraca otwarte debugowe drzwi, zmienia ich kolor i
wyłącza collider przypisany do ich `instance_id`.

## Zweryfikowane własności

- pełny build Release x64 przechodzi bez błędów;
- patch stosuje się czysto do przypiętego commita w świeżym worktree;
- test kontraktu kompiluje prawdziwy `fpp_bridge.cc` i sprawdza kolejność oraz
  treść pięciu zdarzeń, w tym otwarcie drzwi;
- niezmieniony stan gracza nie tworzy drugiego `player_moved`;
- nazwy map są escapowane jako JSON;
- interakcja zachowuje `instance_id`, `object_id`, PID, heks, elevation,
  rotację i rezultat.

Dowód testu jest zapisany w ignorowanym
`artifacts/fallout2-ce-bridge-contract.jsonl`.

## Następny krok

Godot ma już odbiornik śledzący przyrost pliku JSONL. Domyślnie działa jako
obserwator i pokazuje zgodność w HUD. Flaga `--bridge-live` wyłącza lokalny ruch
i odtwarza ostatni zapisany stan CE przed śledzeniem nowych zdarzeń, dzięki
czemu okno Godota można bezpiecznie uruchomić ponownie w trakcie sesji.
Następnie stosuje stan CE do wspólnego gracza oraz obiektów. Test `--bridge-probe`
potwierdza `map_loaded`, `player_moved`, `interaction`, `object_state`,
przyrostowe dopisywanie, buforowanie przeciętego rekordu JSONL i zachowanie
stanu podczas ISO/FPP. Wariant na `ARCAVES` dodatkowo potwierdza otwarte drzwi i
wyłączony collider.

Następny krok to test dwóch prawdziwych procesów: uruchomić najpierw Godota z
`--bridge-live`, potem instrumentowany `fallout2-ce`, rozpocząć nową grę,
wykonać jeden ruch i jedną interakcję. Dowód musi zestawić dokładnie te same
heks/elevation/rotację i `instance_id` po obu stronach.

W trybie live Godot nadpisuje po każdym odebranym zdarzeniu maszynowy snapshot
`artifacts/godot-bridge-live-runtime.json`. Pozwala to porównać zastosowany stan
z ostatnią sesją w `artifacts/fallout2-ce-state.jsonl` bez polegania na samym
obrazie.

Godot rozpoznaje granice map z `map_loaded` i automatycznie przebudowuje aktywną
debugową geometrię między dostępnymi `ARTEMPLE` i `ARCAVES`. Dla nieznanej mapy
ruch i interakcje są jawnie ignorowane zamiast nakładania ich na błędną
geometrię. Początkową mapę nadal można wybrać argumentem `--map=artemple` albo
`--map=arcaves`; rozszerzenia `.MAP` i `.SAV` są porównywane jako ta sama
logiczna mapa.
