# Punkt wznowienia

## Ostatnia iteracja: fałszywa „skrzynia” ze screena (2026-10-23)

Użytkownik zaakceptował skalę FPP względem mrówek i skorpionów oraz potwierdził,
że ich kierunkowe billboardy obracają się poprawnie. Screen `gowno.png` pokazał
natomiast dwa nieruchome, rozcięte obiekty. Identyfikacja po pozycji kamery
(`hex 14683`, elevation 1, direction 1) wykazała, że są to instancje narożnej
ławki `TEMPSF05.FRM` (`2061` i `2142`), a nie skrzynia `chest1.frm`.

Przyczyną był tryb `source_solid`: pełny izometryczny FRM był nakładany z przodu
i tyłu płytkiej bryły, co pod kątem tworzyło dwa skośne „skrzydła”. Całe rodziny
`TEMPSF04/05` używają teraz `billboard_y`. Ich blokowanie nadal pochodzi z
`scene-v1.blocking_hexes` wyeksportowanych z MAP/PRO, więc zmiana dotyczy wyłącznie
warstwy wizualnej. Kontrakt dodatkowo sprawdza, że każdy `billboard_y` oraz
`directional_6` naprawdę ma w materiale Godota `BILLBOARD_FIXED_Y`.

Dowód z tej samej kamery: `artifacts/feedback-furniture-candidate.png`. Stare
skrzyżowane powierzchnie zniknęły, a obie ławki pokazują kompletne źródłowe FRM.
`28 passed`, Ruff, blocking probe i collider prawdziwej skrzyni przechodzą;
performance probe osiąga 144.93 FPS. Licznik osobnych colliderów wizualnych spadł
z 30 do 4, ponieważ 26 ławek używa istniejących blokad MAP zamiast duplikatów.

## Ostatnia iteracja: billboardy wolnostojących obiektów i skala FPP (2026-10-23)

Przyjęto hybrydową regułę renderowania zamiast jednej techniki dla całej sceny.
NPC i potwory pozostają kierunkowymi billboardami z sześciu rotacji FRM. Skrzynie
`chest*.frm` oraz wazy `arvase*.frm` są teraz `billboard_y`, natomiast ich wygląd
nie steruje fizyką: skrzynia ma osobny, nieruchomy `BoxShape3D`, więc karta może
obracać się do kamery bez obracania lub utraty kolizji. Długie ławki i pozostałe
obiekty, dla których głębokość wpływa na czytelność przejścia, nadal używają
minimalnej geometrii. Pochodnie ścienne zachowują źródłową kotwicę MAP; przycięty
uchwyt i osobny animowany płomień są billboardami Y. Płomień nadal pochodzi z
12 klatek `firepit.frm`, ale maska zachowuje tylko ciepłe piksele źródłowe, więc
nie przenosi na ścianę prostokątnego fragmentu kamiennej misy. Najbliższy nośnik
ściany służy do ustalenia strony pomieszczenia i odsunięcia karty przed relief.

Skalę aktorów oparto na prawdziwym ludzkim `nmwarraa.frm`: klatki mają 63-66 px,
więc 36 px/m daje około 1,75-1,83 m. Wysokość oczu gracza wynosi 1,62 m, a pionowe
FOV zmniejszono z 75 do 65 stopni. Eliminuje to wcześniejszą sytuację, w której
człowiek miał tylko około 1,31 m względem kamery 1,68 m i gracz wyglądał jak
olbrzym.

Dowody: `feedback-chest-candidate.png`, `feedback-critter-candidate.png` oraz
`feedback-torch-candidate.png`. Kontrakt Godota raportuje `eye_height: 1.62`;
source-solid probe potwierdza nieprzenikalną skrzynię (`distance 1.073`), movement
probe przechodzi, `28 passed`, Ruff bez błędów, a performance probe osiąga
144.94 FPS. Kolejny krok to ręczny spacer użytkownika i ocena skali w ruchu.

## Ostatnia iteracja: usunięcie ścian scalanych w poprzek (2026-10-23)

Test użytkownika odrzucił samą korektę szczelin: w dalszym ciągu występowały
otwarte dziury i ściany przeprowadzone poprzecznie przez przestrzeń. Przyczyną
nie były brakujące końcówki, tylko wcześniejszy flood-fill komponentów. Dwie
równoległe ściany mogły połączyć się przez wspólną kotwicę narożną, po czym ich
pozycja poprzeczna była uśredniana do jednego fałszywego odcinka.

Generator grupuje teraz krawędzie grafu ścian według współrzędnej normalnej ich
środka. Zygzak kotwic heksowych należący do jednej prostej trafia do jednego
lane, natomiast kotwica skrzyżowania może należeć do dwóch niezależnych lane'ów.
Przed zmianą ARCAVES miało 30 komponentów o rozrzucie poprzecznym większym niż
0.51, maksymalnie 1.50. Po zmianie liczba takich komponentów wynosi 0, a maksimum
to 0.500004. Runtime tworzy 569 prostych nośników, 261 łączników końców i 12176
trójkątów ścian.

Powtórzona regresja siedmiu kadrów FPP i jednego ISO nie wykazała ponownego
zamknięcia znanych przejść. `28 passed`, Ruff, bridge, blocking i source-solid
probe przechodzą; performance probe wynosi 144.92 FPS. Zmiana nadal oczekuje na
ręczny spacer użytkownika w świeżym oknie i nie jest jeszcze zatwierdzona dla
innej mapy.

## Ostatnia iteracja: proceduralne domknięcie narożników ARCAVES (2026-10-23)

Renderer wykonuje teraz audyt końców wszystkich scalonych nośników ścian. Gdy
końcówka jednego nośnika dotyka w MAP prostopadłego nośnika, lecz ich powierzchnie
nie dochodzą do wspólnego przecięcia, powstaje krótki łącznik będący przedłużeniem
pierwszej ściany. Łącznik zachowuje jej grubość, materiał oraz fazę UV. Nie jest
kostką ani kolumną i nie jest tworzony między równoległymi, odsuniętymi ścianami.

ARCAVES ma 535 scalonych nośników, 247 potwierdzonych styków i 247 łączników.
Liczba trójkątów ścian wzrosła z 9226 do 11696. Audyt zapisuje pełną listę do
`artifacts/arcaves-wall-seam-audit.json`; `--seam-audit-screens` zapisuje po dwa
ujęcia ośmiu największych szczelin, a `--disable-seam-connectors` zachowuje
baseline diagnostyczny. Kadry `arcaves-wall-seam-00-a-baseline.png` i
`arcaves-wall-seam-00-a-connector.png` pokazują reprezentatywny wynik.

Regresja objęła siedem zapisanych ujęć FPP i jedno ISO. Przejścia i łuki pozostały
otwarte, natomiast szczeliny narożne zostały domknięte. Testy: `28 passed`, Ruff
bez błędów, bridge 6/5, blocking i source-solid `passed: true`; headless renderer
osiągnął 144.95 FPS. Następny krok to ręczny spacer użytkownika po ARCAVES, a po
akceptacji przejście do animowanych billboardów postaci i obiektów, nie dalsze
ręczne poprawianie pojedynczych pomieszczeń.

## Ostatnia iteracja: dziury, ławki i skrzynie (2026-10-23)

Odrzucono bezwarunkowe renderowanie wszystkich ściennych `block.frm`, ponieważ
tworzyło poprzeczne zapory w prawdziwych przejściach. Obecny renderer dopuszcza
marker tylko jako mostek pomiędzy dwoma widocznymi rekordami leżącymi po jego
przeciwnych stronach; wieloznaczne skrzyżowania pozostają niewidoczne. Kontrakt
ARCAVES raportuje 156 selektywnych mostków i 535 scalonych nośników. Wartość
9226 trójkątów dotyczy baseline bez późniejszych łączników narożnych.

`TEMPSF04.FRM` używa minimalnej geometrii 3D z wyprostowanymi powierzchniami
pochodzącymi wyłącznie z oryginalnych pikseli. `chest1.frm` używał w tej starszej
iteracji podobnej bryły, ale został później zastąpiony billboardem Y z osobnym
colliderem. Test `--source-solid-probe` nadal próbuje przez 90 klatek wejść
w skrzynię i zapisuje wynik w `artifacts/godot-source-solid-runtime.json`;
bieżący wynik to `passed: true`, gracz pozostał na elevation 1.

Dowody wizualne:

- `artifacts/feedback-holes-candidate.png` — FPP po selektywnym domknięciu;
- `artifacts/feedback-gap2-iso.png` — kontrola układu ścian z góry;
- `artifacts/feedback-bench-candidate.png` — bryła ławki z `TEMPSF04.FRM`;
- `artifacts/feedback-chest-candidate.png` — aktualny billboard skrzyni z `chest1.frm`.

Weryfikacja tej iteracji: `28 passed`, `ruff check .`, bridge probe 6/5,
blocking probe `passed: true` i source-solid probe `passed: true`. Następny krok
to test użytkownika w świeżym oknie Godota; nie rozszerzać reguł na nową mapę
przed oceną tych czterech kadrów i przejściem po ARCAVES.

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

## Historia iteracji ARCAVES (starsze punkty odniesienia)

Poniższe liczby opisują kolejne eksperymenty i są zachowane dla audytu. Aktualny
stan oraz obowiązujące metryki znajdują się w pierwszej sekcji dokumentu.

- trzy zgłoszone kadry można odtworzyć argumentami `--feedback-gowno1`,
  `--feedback-gowno2` i `--feedback-gowno3`; baseline oraz bieżące kandydaty są
  zapisane w ignorowanym `artifacts/`;
- źródłowym oracle pojedynczego poziomu jest teraz
  `artifacts/arcaves-walls-e0-source-composite.png` (1145 rekordów elevation 0),
  nie starszy kompozyt mieszający wszystkie trzy elevation;
- wszystkie 9 par `temple33/34` elevation 0–2 jest odwzorowanych jako otwarte
  portale; ich yaw jest snapowany do kanonicznej osi ściany zamiast błędnej osi
  pomiędzy izometrycznymi kotwicami FRM;
- `temple90–95` są rozpoznawane jako źródłowe słupy/końcówki, co zachowuje
  prawdziwe boczne przejścia zamiast pokazywać je jako przypadkowe dziury;
- `temple35/36` bez bliskiego muru nośnego ma skrzydła po `1.1` jednostki;
- bieżący kontrakt ARCAVES raportuje 9 portali, 12 reliefów, 0 rekordów bez pary,
  503 nośniki ścian oraz 8892 trójkąty;
- werdykt wizualny użytkownika dla tej iteracji nadal oczekuje. Podłoga, sufit
  i rytm tekstur nie są jeszcze uznane za rozwiązane.
- odtworzono dodatkowe zgłoszenie na heksach `20505` i `21107`: skrzydła
  `temple35/36` dochodzą proceduralnie do najbliższego kontaktu MAP,
  `temple99` należy do narożników, a materiały źródłowe ARCAVES nie są już
  wtórnie zaciemniane per-pixel. Kadry front/±20°/ISO znajdują się jako
  `feedback-gap2-*.png`. Szerokie, przechodnie otwarcia nadal potrzebują
  czytelnych ościeży, ale nie mogą być automatycznie zamurowane.
- po kolejnym odrzuceniu przejrzano pełny kadr `20513/0`. Renderer tworzy teraz
  kamienne nośniki również dla 386 rekordów ściennych `art/walls/block.frm`,
  które wcześniej były tylko wskazówkami topologii. Rekordy scenery o tej samej
  nazwie nadal są ukryte. Bieżący kontrakt ARCAVES raportuje 556 nośników i
  9436 trójkątów; kadry `feedback-holes-candidate.png` oraz wcześniejsze
  `feedback-gowno1–3-candidate.png` zostały ponownie wyrenderowane.

## Ukończone etapy

- eksporter obejmuje crittery i odtwarza ich nazwy FRM zgodnie z
  `fallout2-ce` (`artBuildFilePath`, `_art_get_code`, aliasy);
- `scene-art-cache` czyta `master.dat` oraz `critter.dat`, zapisuje sześć rotacji
  postaci i wszystkie klatki wyłącznie w ignorowanym `artifacts/`;
- Godot ma rodzinny renderer billboardów: sześć kierunków dla critterów,
  Y-billboard, fixed plane, cross-plane i ground decal;
- ARTEMPLE eksportuje 1 crittera, ARCAVES 22; oba headless probe'y przechodzą
  przy około 145 FPS na bieżącym środowisku;
- odtwarzalna komenda to `scripts/refresh-billboard-cache.ps1`, a pełne reguły są
  w `docs/BILLBOARDS.md`;
- skill `ai3d-transparent-billboard-asset` jest zainstalowany użytkownikowo dla
  Codexa; audyt próbki critter/drzewo/pochodnia nie wykazał białych obwódek;
- read-only parser Fallout 2 DAT z obsługą zlib;
- parser nagłówka MAP, zmiennych i warstw podłoga/dach;
- eksport `fo2remix.scene-v1` do JSON;
- eksport `maps\artemple.map` do ignorowanego
  `artifacts\artemple.scene-v1.json`;
- 28 testów i Ruff;
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
- renderer buduje cienkie segmenty ścian 3D w dwóch osiach zakodowanych przez
  rodziny FRM 16/32 px oraz pokazuje wyłącznie elevation bieżącej postaci;
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
- ściany świątynne ARCAVES używają UV i pikseli `temple03.frm`; warstwy na tym
  samym heksie zapadają się do jednego nośnika, aby nie tworzyć migoczących kart;
- `temple32/96/97/98.frm` są filarami, nie szerokimi ścianami. Ich boczna
  powierzchnia jest prostowana z `TEMPLE97.FRM` na małą bryłę 3D. Uchwyty
  `atorch3/4/5.frm` dostały płomień z 12 oryginalnych klatek `firepit.frm`, a
  źródłowe emitery MAP zachowują pozycję i energię z subtelnym migotaniem;
- cztery drzwi ARCAVES mają źródłowe panele FRM; probe potwierdza przejście na
  klatkę `18` po stanie `open`, równolegle z wyłączeniem collidera;
- okienkowy benchmark ARCAVES/FPP po rozgrzaniu osiągnął `60,00 FPS` przez
  180 klatek przy 2 628 trójkątach nośników ścian i wejść, 13 361 komórkach
  sufitu, 135 renderowanych propsach i budżecie 12 aktywnych świateł. Bieżący
  dowód to `artifacts/godot-render-performance.json`; wcześniejsze warianty
  map pozostają osobnymi punktami odniesienia.
- podłogi są generowane z prawdziwych FRM typu `tiles`: ARCAVES ma 25 rodzin,
  a ARTEMPLE 166. Kalibracja narożników obrazu `80 x 36` usuwa czarne szczeliny
  pomiędzy kaflami;
- renderer 2.5D zachowuje źródłowe billboardy dla critterów, roślinności,
  pochodni, palenisk, efektów i jawnie zatwierdzonych płaskich dekoracji.
  Istniejące bryły proxy skrzyń, mebli, skał i waz są roboczą geometrią nośną;
  nie są zaakceptowanym zamiennikiem źródłowego wyglądu. ARCAVES nadal zawiera
  7 itemów. Itemy
  ARCAVES obejmują cztery skrzynie `chest1.frm`, dwie wazy i kości. Sprite
  `block.frm` pozostaje niewidzialny;
  MAP wskazuje 76 osobnych emiterów światła w ARCAVES i 2 w ARTEMPLE;
- widoczne ściany są scalane w maksymalne proste przebiegi. Oś jest wybierana z
  lokalnego sąsiedztwa MAP, a szerokość FRM rozstrzyga tylko remisy; dzięki temu
  szerokie lico i wąskie zakończenie tej samej ściany nie tworzą prostopadłych
  klocków ani efektu harmonijki;
  techniczne rekordy `block.frm` pozostają tylko w autorytatywnej kolizji;
- odrzucono automatyczne traktowanie 21 par `temple33–36.frm` jako wejść.
  Kontrprzykład `temple35/36` na heksach `28700/29500` nakłada się na ciągły
  mur, więc nazwa i sylwetka FRM nie wystarczają do wnioskowania o prześwicie;
- prawdziwe drzwi ARCAVES `instance_id=1338`, heks `24308`, pomiędzy
  `temple34.frm` na `24305` i `temple33.frm` na `24310` mają łukową geometrię
  3D, prostowane klatki `acavedr4.frm`, źródłowy kamień, głębokość ościeża oraz
  zakładkę zamykającą styk z sąsiednim murem;
- 24 rekordy `temple35/36.frm` tworzą 12 par przez potwierdzoną relację heksów
  `+800`. Sześć par z pobliskim nośnikiem `temple09–14` jest reliefem na pełnej
  ścianie, a sześć bez takiego nośnika ma łuk, mur nad nim i krótkie skrzydła
  po `0.52` jednostki, zgodne z oznaczonymi prostokątami źródłowych FRM. Obie
  klasy mają osobne kadry front/bok; szczegóły i odrzucone reguły są w
  `docs/ARCAVES_ARCHITECTURE_EXPERIMENTS.md`;
- scalone ściany mają teraz czoła tylko na końcach komponentów. Korytarze używają
  prostowanego pasa czterech oryginalnych powierzchni
  `temple01/03/05/07.frm`, powtarzanego co `4.32` jednostki zamiast jednego
  sprite'a `temple03` co około metr;
- ARTEMPLE jest traktowane jako lokacja zewnętrzna bez automatycznego sufitu.
  ARCAVES nadal ma sufit `floor_footprint` bez szczelin;
- `TEMPLE01`–`TEMPLE08` są składane z dokładnych pikseli źródłowych poleceniem
  `scene-source-composite`, ale cała kompozycja nie jest już renderowana jako
  fasada. Screenshot `artifacts/rejected-artemple-flat-facade.png` wykazał
  wiszącą kartę i brak prawdziwej
  zmiany perspektywy; ten wariant został usunięty. Runtime łączy teraz 45
  technicznych heksów ścian MAP w ciągłe odcinki, teksturuje je wycinkiem
  `temple19.frm` i osadza portal z `TEMPLE01` jako ograniczoną powierzchnię cechy.
  Reguła `artemple_temple01_08` jest zapisana w
  `godot/data/source_geometry_rules.json`. Pozostałe ornamenty wymagają osobnych
  projekcji front/bok i przeglądu UV. Techniczne rekordy nadal zachowują
  autorytatywną kolizję;
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
- `artemple-temple-source-composite.png/.json` — dokładna kompozycja ośmiu
  źródłowych FRM z hashami i prostokątami `objectGetRect`;
- `godot-artemple-iso-material-preview.png` oraz
  `godot-artemple-fpp-material-preview.png` — bieżąca para do przeglądu reguły
  `artemple_temple01_08`;
- `blender-selftest/` — lokalny wynik pełnego headless smoke-testu toolchainu
  Blender 5.1 (GLB, UV, bake i cztery rendery).

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
odwzorowany w geometrii i kolizji, a podłogi pochodzą z FRM. Kierunek wizualny
został skorygowany według prototypu Diablo First Person: MAP/PRO określa
topologię, FRM wygląd, a geometria jest wyłącznie nośnikiem oryginalnych pikseli.
Proceduralny model świątyni został odrzucony i runtime go już nie wywołuje.
`scene-source-composite` odtwarza dokładną referencję `TEMPLE01–08`, ale nie jest
już bezpośrednio wyświetlany. Godot buduje ściany z technicznych heksów MAP i
nakłada źródłowe piksele na powierzchnie. Bieżący kandydat ARCAVES zamyka końce
scalonych murów, używa czterowariantowego źródłowego pasa ścian i rozdziela
`temple35/36` na reliefy oraz łuki z krótkimi skrzydłami muru na podstawie
obecności nośnika MAP i pikseli obu FRM. Zarówno pełne wypełnienie rozpiętości
pary, jak i sama wolnostojąca obręcz zostały odrzucone. Referencyjny
`artifacts/arcaves-walls-source-composite.png` składa wszystkie `2622` źródłowe
klatki ścian i potwierdza, że pozostały labiryntowy układ pomieszczeń należy do
oryginalnej Świątyni Prób. Następny konkretny krok po ręcznym teście łączników
narożnych to animowany billboard jednej postaci i jednej rodziny obiektów, z
klatką oraz kierunkiem sterowanymi wspólnym stanem CE. Oświetlenie, podłoga i
sufit pozostają osobnymi, niezaakceptowanymi rodzinami.
Nie należy jeszcze hookować ani modyfikować retailowego EXE.

Podczas pierwszego testu starszy launcher ustawił instalację Steam jako katalog
roboczy i utworzył tam `data\maps\ARTEMPLE.SAV` oraz
`data\maps\ARCAVES.SAV`. Proces został zatrzymany, a launcher naprawiony.
Pliki pozostawiono bez zmian; ich usunięcie wymaga świadomej zgody użytkownika.
