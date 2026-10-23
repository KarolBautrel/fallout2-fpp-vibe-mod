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
- 23 testy i Ruff;
- zainstalowany i wykrywany toolchain MSVC/CMake;
- sklonowany oraz przypięty niezmieniony `fallout2-ce`;
- udany build Release x64;
- udane uruchomienie na danych Steam z responsywnym oknem `FALLOUT II`;
- minimalny renderer Godot z niepustymi komórkami podłogi wszystkich elevation;
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
- parser skryptów i pełnej sekcji obiektów MAP, w tym rekurencyjnych
  ekwipunków oraz typów instancji zależnych od `.pro`;
- resolver prototypów zgodny z 1-based listami `proto/<type>/<type>.lst`;
- `scene-v1` rozszerzone o ściany, scenerię, drzwi, flagi i blokowane heksy;
- debugowa geometria Godot oraz 419 colliderów dla blokad `ARTEMPLE.MAP`;
- runtime probe potwierdzający, że ściana ID `164` blokuje heks `15284`.
- eksport nadaje każdemu rekordowi stabilne `instance_id`, ponieważ prawdziwe
  `object_id` MAP nie jest unikalne (55 powtarzających się wartości w 116
  rekordach `ARTEMPLE.MAP`);
- wspólna interakcja ISO/FPP z blokującą scenerią: celowanie środkiem kamery w
  FPP, wybór kliknięciem w ISO, klawisz `E`, wspólny stan `activated` i
  zachowanie wyboru podczas przełączania kamery;
- runtime probe potwierdzający ten sam `instance_id = 0`, źródłowe
  `object_id = 16` i identyczny wynik w ISO oraz FPP.
- zakończony test dwóch prawdziwych procesów: ruch gracza i przejścia map
  `ARTEMPLE`/`ARCAVES` z `fallout2-ce` są odbierane na żywo przez Godota;
- eksport `ARCAVES.MAP` zawiera 4528 zadeklarowanych obiektów, 4 drzwi i 2821
  blokowanych heksów; wybiera się go argumentem Godota `--map=arcaves`;
- prawdziwa interakcja z drzwiami na `ARCAVES.SAV` została dopasowana po obu
  stronach: `instance_id = 1338`, `object_id = 1482`, PID `33555366`, heks
  `24308`, rezultat `0` i stan `activated = true`;
- odbiornik rozpoznaje `.MAP` i `.SAV` jako tę samą mapę oraz ignoruje ruch i
  interakcje z mapy innej niż załadowany `scene-v1`, zamiast nakładać je na
  błędną geometrię;
- launcher bridge'a używa zapisywalnego
  `artifacts/fallout2-ce-runtime`, a instalację Steam traktuje jako źródło
  archiwów tylko do odczytu.
- crash przy pierwszym przejściu mapy został przypisany do upstreamowego
  `char temp[80]` w `_map_save()` przy 94-znakowej ścieżce runtime; nakładka
  używa teraz `COMPAT_MAX_PATH` i ograniczonych `snprintf`, a build Release i
  test kontraktu przechodzą;
- Godot automatycznie przebudowuje geometrię po `map_loaded` między
  `ARTEMPLE` i `ARCAVES`, więc FPP śledzi postać od początku gry i nie wymaga
  ręcznego uruchamiania na następnej mapie.
- `ARCAVES` renderuje podłogi elevation 0/1/2 zamiast samych obiektów z wyższych
  poziomów; domyślny pusty tile `1` nie tworzy debugowego bloku;
- bridge emituje pełny snapshot wszystkich drzwi po `map_loaded`, a następnie
  delty `object_state` po zmianie stanu. Wczytanie starszego save'a przywraca
  zamknięte drzwi, grafikę oraz collider zamiast pozostawiać stan z poprzedniej
  sesji;
- probe `--bridge-probe --map=arcaves` potwierdza 6 zdarzeń, zamknięte drzwi po
  snapshotcie, klatkę `18` po delcie otwarcia i `door_collision_disabled = true`.
- renderer buduje wspólną siatkę topologii ścian z zajętych heksów zamiast
  osobnych prostokątów oraz pokazuje wyłącznie elevation bieżącej postaci;
- eksporter rozwiązuje teraz `FID -> art/<typ>/<typ>.lst -> FRM` zgodnie z
  `fallout2-ce`; na dwóch rzeczywistych rekordach ARCAVES potwierdzono
  `temple19.frm` i `acavedr4.frm`. Szczegóły: `docs/ART_PIPELINE.md`.
- read-only parser `FRM` odczytuje metadane klatek i kierunków; dowody dla
  `temple19.frm` (1 klatka, `33 × 116`) i `acavedr4.frm` (19 klatek,
  `105 × 97` dla pierwszej) są w ignorowanym `artifacts/`.
- parser dekoduje `color.pal`, przezroczystość oraz klatki FRM do PNG;
  `scene-art-cache` utworzył dla ARCAVES 126 unikalnych assetów zamiast
  przetwarzać 3038 instancji ścian/scenerii osobno;
- gdy `roof_ids` są puste, Godot automatycznie wybiera strategię sufitu:
  zewnętrzne ARTEMPLE pozostaje bez sufitu, a gęste wnętrze ARCAVES pokrywa
  pełny footprint niepustej podłogi
  (13 361 komórek na trzech elevation). Płyty zachodzą na ściany, więc nie ma
  prześwitów; sufit jest widoczny w FPP i ukryty w ISO;
- wersjonowany profil `temple_stone` pokrywa 1580 ścian ARCAVES kolorem
  obliczonym z `temple19.frm`; pozostałe ściany pobierają kolor automatycznie
  ze swojego źródłowego FRM.
- bezpośrednia projekcja FRM na ściany została odrzucona po teście wizualnym,
  ponieważ tworzyła nachodzące na siebie pionowe karty. Ściany korzystają teraz
  z jednej siatki topologii i antyaliasowanego proceduralnego materiału kamienia;
  FRM przekazuje paletę i profil rodziny, ale nie jest rozciągany na powierzchni;
- cztery drzwi ARCAVES mają źródłowe panele FRM; probe potwierdza przejście na
  klatkę `18` po stanie `open`, równolegle z wyłączeniem collidera;
- okienkowy benchmark ARCAVES/FPP po rozgrzaniu osiągnął średnio `60,29 FPS`
  przez 180 klatek przy 14 332 trójkątach ścian, 13 361 komórkach sufitu,
  113 renderowanych propsach i budżecie 12 aktywnych świateł. Dowód:
  `artifacts/godot-render-performance.json`.
- podłogi są generowane z prawdziwych FRM typu `tiles`: ARCAVES ma 25 rodzin,
  a ARTEMPLE 166. Kalibracja narożników obrazu `80 x 36` usuwa czarne szczeliny
  pomiędzy kaflami;
- renderer 2.5D renderuje tylko jawnie bezpieczne billboardy efektów oraz
  stabilne bryły proxy dla znanych rodzin scenerii i 7 itemów ARCAVES. Itemy
  ARCAVES obejmują cztery skrzynie `chest1.frm`, dwie wazy i kości. Sprite
  `block.frm` pozostaje niewidzialny;
  MAP wskazuje 76 osobnych emiterów światła w ARCAVES i 2 w ARTEMPLE;
- ściany są zamkniętą powierzchnią graniczną sumy zajętych heksów MAP; wspólne
  krawędzie znikają, a techniczne rekordy `block.frm` uzupełniają bryłę
  ARTEMPLE bez renderowania swojego sprite'a;
- ARTEMPLE jest traktowane jako lokacja zewnętrzna bez automatycznego sufitu.
  ARCAVES nadal ma sufit `floor_footprint` bez szczelin;
- tylko aktywne elevation ma włączoną fizykę. Naprawia to promień ISO, który
  wcześniej mógł trafić w niewidzialną podłogę wyższego poziomu;

Na prawdziwym `master.dat` znaleziono 23 140 wpisów i 155 map. Dla
`ARTEMPLE.MAP` eksport zawiera spawn na heksie `18492`, kolumnę `107`,
wiersz `92`, elevation `0`, jedną warstwę 100 × 100, 567 obiektów, 45 ścian,
397 rekordów scenerii i 419 blokowanych heksów. Mapa nie ma drzwi. Format
drzwi potwierdzono dodatkowo na 24 rekordach z `KLAMALL.MAP`.

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
modyfikowane podczas bazowego buildu. Obecnie lokalny checkout ma nałożoną
wersjonowaną nakładkę bridge’a z `integration/fallout2-ce`; można ją odtworzyć
przez `scripts/apply-fallout2-ce-bridge.ps1`.

## Godot ISO/FPP

Projekt: `godot/project.godot`.

Zasada pracy: przed uruchomieniem wersji po każdej aktualizacji zamknąć
wszystkie starsze okna tego projektu i pozostawić dokładnie jedno świeże okno
Godota, żeby użytkownik nie testował nieaktualnego procesu.

Sterowanie:

- `Tab`: ISO/FPP;
- mysz: rozglądanie w FPP, `Esc` zwalnia kursor;
- `W` / `S`: przód/tył;
- `A` / `D`: strafe lewo/prawo;
- `Shift`: sprint.
- `E`: interakcja;
- w ISO: lewy przycisk myszy wybiera blokującą scenerię;
- w FPP: cel interakcji wskazuje środek ekranu.

W trybie live, gdy autorytetem jest `fallout2-ce`, Godot nie przechwytuje myszy,
bo orientacja pochodzi z CE. Okno ma jawną ramkę systemową i można je swobodnie
przesuwać. W lokalnym trybie FPP `Esc` zwalnia kursor, a kliknięcie widoku
ponownie włącza rozglądanie.

Transformacja współrzędnych jest opisana w `docs/COORDINATES.md`. Stan
logiczny zachowuje indeks heksa; kamery tylko go obserwują.

## Dowody w artifacts

- logi prerekwizytów, konfiguracji, buildu i uruchomienia `fallout2-ce`;
- `fallout2-ce-build-evidence.json`;
- `godot-iso-fpp-contract.json`;
- `godot-movement-runtime.json` — rzeczywisty test strafe `D` przez 30
  klatek fizyki;
- `godot-blocking-runtime.json` — rzeczywisty test kolizji ze ścianą;
- `godot-interaction-runtime.json` — ten sam cel i wynik interakcji w ISO/FPP;
- `godot-bridge-runtime.json` — odbiór sześciu zdarzeń CE, przyrostowy JSONL,
  snapshot zamkniętych drzwi, deltę otwarcia, zastosowanie heksa/rotacji i
  wspólnego `instance_id`;
- `artemple.scene-v1.objects.json` i `klamall.scene-v1.objects.json` —
  dowody pełnego odczytu obiektów z danych użytkownika;
- `godot-preview00000002.png` — widok ISO;
- `godot-fpp-preview00000002.png` — widok FPP;
- `godot-headless-contract-2026-10-23.log`.

Oryginalne `.dat`, `.map`, `.frm`, audio, filmy i save'y pozostają poza
Gitem. Instalacja Steam jest traktowana wyłącznie jako źródło do odczytu.

## Następny konkretny etap

REA 6.7.0, Ghidra 12.1.4 i wymagany przenośny toolchain są skonfigurowane
lokalnie. Analiza retailowego `fallout2.exe` potwierdziła względem źródeł
`fallout2-ce` trzy punkty integracji: `mainLoop` (`0x480E48`), `mapLoad`
(`0x482B74`) i `objectSetLocation` (`0x48A568`) oraz `gDude` pod `0x6610B8`.
Szczegóły i dowód odtworzenia są w `docs/REA_INTEGRATION.md`.

Lokalny, instrumentowany `fallout2-ce` emituje już read-only JSONL ze
zdarzeniami `map_loaded`, `player_moved`, `interaction` oraz `object_state`.
Nakładka, skrypty
odtworzenia i test kontraktu są opisane w `docs/STATE_BRIDGE.md`. Pełny build
Release x64 i test sześciu zdarzeń przechodzą.

Godot ma już odbiornik JSONL. Domyślnie obserwuje trace i raportuje zgodność w
HUD, a `--bridge-live` czyni CE autorytetem, wyłącza lokalny ruch i stosuje
`map_loaded`, snapshot drzwi, `player_moved`, udane `interaction` i późniejsze
delty stanu. Probe ARCAVES potwierdza sześć zdarzeń, przyrostowe dopisywanie,
buforowanie niepełnej linii, reset zamkniętych drzwi i późniejsze otwarcie.

Test end-to-end dwóch prawdziwych procesów został wykonany, stan drzwi jest
odwzorowany w geometrii i kolizji, podłogi pochodzą z FRM, a znane rodziny
propsów używają jawnych profili 2.5D/3D. Ściany mają zamkniętą siatkę graniczną
rozdzieloną na elevation. Bezpośrednia projekcja FRM na ściany i przypadkową
scenerię została odrzucona; obecne materiały zachowują paletę źródłową, światła
nie mają syntetycznego migotania, a sufit ARCAVES nie ma szczelin. Następny krok
po teście użytkownika to porównanie wybranych punktów ISO/FPP, korekta profili
rodzin, płynne klatki drzwi, a potem pierwszy ruchomy critter z tym samym
modelem snapshot + delty. Nie należy
jeszcze hookować ani modyfikować retailowego EXE.

Podczas pierwszego testu starszy launcher ustawił instalację Steam jako katalog
roboczy i utworzył tam `data\maps\ARTEMPLE.SAV` oraz
`data\maps\ARCAVES.SAV`. Proces został zatrzymany, a launcher naprawiony.
Pliki pozostawiono bez zmian; ich usunięcie wymaga świadomej zgody użytkownika.
