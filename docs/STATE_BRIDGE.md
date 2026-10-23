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

Skrypt uruchamia binarkę z katalogiem danych Steam ustawionym jako katalog
roboczy, ale trace zapisuje wyłącznie do ignorowanego
`artifacts/fallout2-ce-state.jsonl`.

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

## Zweryfikowane własności

- pełny build Release x64 przechodzi bez błędów;
- patch stosuje się czysto do przypiętego commita w świeżym worktree;
- test kontraktu kompiluje prawdziwy `fpp_bridge.cc` i sprawdza kolejność oraz
  treść czterech zdarzeń;
- niezmieniony stan gracza nie tworzy drugiego `player_moved`;
- nazwy map są escapowane jako JSON;
- interakcja zachowuje `instance_id`, `object_id`, PID, heks, elevation,
  rotację i rezultat.

Dowód testu jest zapisany w ignorowanym
`artifacts/fallout2-ce-bridge-contract.jsonl`.

## Następny krok

Godot ma już odbiornik śledzący przyrost pliku JSONL. Domyślnie działa jako
obserwator i pokazuje zgodność w HUD. Flaga `--bridge-live` wyłącza lokalny ruch
i stosuje stan CE do wspólnego gracza oraz obiektów. Test `--bridge-probe`
potwierdza `map_loaded`, `player_moved`, `interaction`, przyrostowe dopisywanie,
buforowanie przeciętego rekordu JSONL i zachowanie stanu podczas ISO/FPP.

Następny krok to test dwóch prawdziwych procesów: uruchomić najpierw Godota z
`--bridge-live`, potem instrumentowany `fallout2-ce`, rozpocząć nową grę,
wykonać jeden ruch i jedną interakcję. Dowód musi zestawić dokładnie te same
heks/elevation/rotację i `instance_id` po obu stronach.
