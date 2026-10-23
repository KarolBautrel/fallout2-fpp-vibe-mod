# REA jako narzędzie integracyjne

Stan potwierdzony 23 października 2026.

REA służy w tym projekcie do weryfikowania zachowania retailowego Fallouta 2
względem czytelnego kodu `fallout2-ce`. Nie jest zależnością runtime prototypu
Godot ani docelowej gry. Instalacja Steam pozostaje tylko do odczytu.

## Lokalny toolchain

Narzędzia są zainstalowane w ignorowanym `artifacts/tools/`:

| Narzędzie | Wersja | SHA-256 archiwum |
| --- | --- | --- |
| Node.js | 24.22.1 | `D2046D28C2C3DCD211AC5145C0BF30E2047EF9DFB306693C8C6E2ECCD8B95FA5` |
| Eclipse Temurin JDK | 21.0.12.1+1 | `F9D6E191AB098C0D416E7D588A24420A8621CD2F4720DAB2459B8B7B2D2D8B4E` |
| Ghidra | 12.1.4 | `DDAC49F903DA9D5BAC833E5CC79395098B9C33CFD3279BE5F31BD00387D2D4DB` |
| `rea-agents` | 6.7.0 | npm SHA-1 `11F23BA377303A5C28B3162180CF2BF3F3643708` |

Wrapper `scripts/run-rea.ps1` przypina te wersje i ustawia Ghidrę jako provider.
Nie pobiera niczego i kończy pracę czytelnym błędem, jeśli lokalnego toolchainu
brakuje.

```powershell
.\scripts\run-rea.ps1 doctor --provider ghidra --format json
```

REA zostało także zarejestrowane jako MCP dla Codexa. Nowy serwer MCP staje się
dostępny po ponownym uruchomieniu sesji Codexa; wrapper działa od razu.

## Tożsamość badanego pliku

```text
C:\Program Files (x86)\Steam\steamapps\common\Fallout 2\fallout2.exe
rozmiar: 1 189 888 bajtów
SHA-256: 581C09C20FEE70EDC09EC412EE034E62E89CDEFA13092E534DDD17D23F8163CB
format: PE x86
image base: 0x400000
```

Analiza Ghidry wykryła 2 956 procedur, 2 419 zdefiniowanych napisów i siedem
segmentów. Retailowy plik nie był modyfikowany. Prywatny projekt Ghidry był
efemeryczny i został usunięty po analizie.

Snapshot jest dowodem lokalnym, nie artefaktem do publikacji:

```text
artifacts/rea/fallout2-ghidra-snapshot.json
SHA-256: 9187BC6CF4A6CD70CA009C3D61902C1F3AA923F5373AB924DE5BD108781E5246
```

Odtworzenie przeglądu:

```powershell
.\scripts\run-rea.ps1 analyze `
  'C:\Program Files (x86)\Steam\steamapps\common\Fallout 2\fallout2.exe' `
  --provider ghidra `
  --snapshot artifacts\rea\fallout2-ghidra-snapshot.json `
  --format json
```

## Potwierdzone punkty integracji

| Rola | Retail | `fallout2-ce` | Potwierdzenie |
| --- | --- | --- | --- |
| Pętla główna / synchronizacja klatki | `0x480E48` | `main.cc`, `mainLoop` | Te same wywołania wejścia, `gameHandleKey` i `scriptsHandleRequests`. |
| Granica pełnego przeładowania mapy | `0x482B74` | `map.cc`, `mapLoad` | Te same wersje map 19/20, błędy pliku i ustawienie pozycji gracza. |
| Autorytatywna zmiana pozycji obiektu | `0x48A568` | `object.cc`, `objectSetLocation` | Te same ograniczenia: heks 0–39999 i elevation 0–2. |
| Wskaźnik gracza `gDude` | `0x6610B8` | `object.cc`, `gDude` | Adres jest zapisany w komentarzu źródłowym CE i używany przez retailową funkcję pozycjonującą. |

Układ `Object` w `fallout2-ce` dodatkowo potwierdza `tile` pod offsetem `+0x04`
i `elevation` pod `+0x28` dla 32-bitowego buildu. Wniosek: `mainLoop` jest
naturalnym punktem synchronizacji, `objectSetLocation` zdarzeniem zmiany
pozycji, a `mapLoad` granicą pełnego resyncu świata.

## Zrealizowana granica implementacyjna

Nie zaczęliśmy od wstrzykiwania kodu do retailowego EXE. Powstała wersjonowana
nakładka na lokalny `fallout2-ce`, która emituje tylko do odczytu zdarzenia
JSONL:

- `frame` — numer klatki i bieżący tryb;
- `map_loaded` — mapa, elevation i pełny punkt resynchronizacji;
- `player_moved` — heks, elevation i rotacja `gDude`;
- `interaction` — stabilne ID celu i rezultat akcji.

Implementacja i kontrakt są opisane w `docs/STATE_BRIDGE.md`. Godot ma teraz
konsumować ten sam strumień w ISO i FPP. Pierwszy test akceptacyjny
porówna heks/elevation/rotację po pojedynczym ruchu oraz `instance_id` po
pojedynczej interakcji. Dopiero po zgodności tego kontraktu ocenimy, czy
potrzebny jest hook retailowej binarki.
