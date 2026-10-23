# Eksperymenty architektury ARCAVES

## Rozdzielanie równoległych przebiegów ścian (2026-10-23)

Werdykt użytkownika odrzucił wariant oparty wyłącznie na łącznikach końców:
pozostawały dziury i fałszywe ściany w poprzek. Audyt wykazał 30 komponentów,
których kotwice nie mieściły się na jednej prostej (rozrzut normalny do 1.50).
Źródłem był flood-fill po czterech kierunkach heksa, który łączył równoległe
przebiegi przez kotwicę narożną, a następnie uśredniał ich położenie.

Przyjęty kandydat buduje graf krawędzi i grupuje je po kwantowanej współrzędnej
normalnej środka krawędzi. Dwie kolejne krawędzie zygzaka heksowego mają ten sam
środek normalny i tworzą prosty przebieg; sąsiedni przebieg dostaje osobny lane.
Kotwica skrzyżowania może uczestniczyć w obu lane'ach bez łączenia ich geometrii.

Po zmianie: 0 nieprostych komponentów, maksymalny rozrzut 0.500004, 569
nośników, 261 łączników i 12176 trójkątów. Siedem kadrów FPP, jeden ISO oraz
testy bridge/blocking/source-solid przeszły. Status: kandydat do ręcznego testu
ARCAVES, jeszcze nie wzorzec dla innych map.

## Proceduralne łączniki końców ścian (2026-10-23)

Audyt geometrii wykrywa końcówki scalonych prostych nośników, które według
sąsiedztwa heksów MAP stykają się z prostopadłym nośnikiem, ale w przestrzeni 3D
kończą się 0.16-0.58 jednostki przed nim. Zamiast stawiać w takim miejscu
uniwersalny słup, renderer przedłuża wyłącznie kończącą się ścianę do punktu
kontaktu. Łącznik ma grubość 0.22 i kontynuuje okres oraz przesunięcie UV ściany.

Pierwsza próba z kwadratowymi złączami została odrzucona: w ujęciu
`feedback-gap2-left` tworzyła sztuczne pionowe listwy. Przyjęty wariant został
sprawdzony na ośmiu największych szczelinach z obu stron (16 kadrów), następnie
na siedmiu zapisanych ujęciach regresyjnych FPP i jednym ISO. Wynik ARCAVES:
535 nośników, 247 kandydatów/łączników i 11696 trójkątów ścian. Baseline można
odtworzyć flagą `--disable-seam-connectors`, a serię dowodową flagą
`--seam-audit-screens`.

Status: przyjęte domyślnie dla ARCAVES; reguły nie przenosić automatycznie na
inną rodzinę map bez identycznego audytu MAP i porównania FPP/ISO.

## Korekta `block.frm` i rekwizytów źródłowych (2026-10-23)

Poprzedni kandydat, który zamieniał wszystkie 386 ściennych rekordów
`art/walls/block.frm` na widoczną geometrię, został odrzucony po teście
użytkownika. Markery stoją również w przejściach i przy złożonych warstwach
izometrycznych, więc bezwarunkowa konwersja tworzyła poprzeczne zapory.

Aktualna reguła jest lokalnym testem topologii:

- `block.frm` sam nigdy nie wyznacza osi ściany;
- marker staje się krótkim mostkiem tylko wtedy, gdy po obu jego przeciwnych
  stronach istnieją widoczne rekordy ściany z MAP;
- marker pasujący do kilku osi (skrzyżowanie) jest odrzucany;
- na ARCAVES reguła dopuściła 156 z 386 markerów i utworzyła 535 scalonych
  nośników / 9226 trójkątów zamiast 556 / 9436 z odrzuconej wersji.

Rekwizyty również nie są już pełnymi sprite'ami na płaskiej karcie:

- `TEMPSF04.FRM` ma minimalną geometrię ławki (siedzisko i nogi), a jej górna
  i przednia powierzchnia używają wyprostowanych fragmentów oryginalnego FRM;
- `chest1.frm` ma pełną bryłę skrzyni, wyprostowaną powierzchnię wieka i frontu;
- oba typy mają dopasowany `StaticBody3D`/`BoxShape3D`; łącznie utworzono 30
  źródłowych brył kolizyjnych w ARCAVES;
- `godot-source-solid-runtime.json` potwierdza 90 klatek ruchu przeciw skrzyni
  bez przeniknięcia (`passed: true`).

Kadry do oceny: `feedback-holes-candidate.png`,
`feedback-gap2-iso.png`, `feedback-bench-candidate.png` oraz
`feedback-chest-candidate.png`. To nadal kandydat oczekujący na werdykt
użytkownika, nie reguła zatwierdzona dla innych map.

Status: kandydat do testów użytkownika. Zmiany są technicznie zweryfikowane,
ale nie są jeszcze zaakceptowanym wzorcem dla całej gry.

## Bieżąca korekta użytkownika

Drzwi są wyraźnie lepsze, lecz w lokacji nadal widać dziury, korytarze są
monotonne, a łuki pokojowe wyglądają źle. Celem tej iteracji było rozdzielenie
tych objawów na błędy topologii, materiału i klasyfikacji elementu MAP.

## 1. Dziury na końcach ścian

- **Baseline:** ściany były już scalane w maksymalne proste odcinki, ale
  `_add_wall_prism` nadal nie tworzył ścian czołowych. Była to pozostałość po
  rendererze jednego klocka na heks, gdzie czoło na każdym heksie tworzyło
  sztuczne filary.
- **Hipoteza:** po scaleniu brak czoła nie usuwa już wewnętrznych szwów, tylko
  otwiera oba końce całego odcinka.
- **Kandydat:** każdy scalony odcinek ma dwa czoła, grubość `0.22` oraz zakładkę
  długości `0.12`. Portal ma osobną zakładkę `0.5` na styku z następnym heksowym
  odcinkiem muru.
- **Obserwacja:** czoła są widoczne tylko na prawdziwych końcach komponentów;
  nie wróciły filary na każdym heksie. Szczelina przy wzorcu drzwi została
  przykryta przez połączenie portal–mur, bez poszerzania samych drzwi.
- **Dowód:** `artifacts/arcaves-doorway-exemplar-closed.png`. Pierwszy kandydat
  z samymi zamkniętymi końcami raportował `5724` trójkąty i `356` nośników;
  bieżący kandydat z krótkimi skrzydłami łuków raportuje `5674` trójkąty i `351`
  nośników.

## 2. Powtarzalność korytarzy

- **Baseline:** jedna pełna klatka `temple03.frm` była powtarzana co około
  `1.08` jednostki. Przezroczyste narożniki izometrycznego równoległoboku były
  traktowane jak część tekstury, a identyczny układ cegieł zdradzał każdy
  segment.
- **Hipoteza:** należy prostować samą powierzchnię muru i zmieniać warianty
  źródłowe bez rozbijania prostej geometrii.
- **Kandydat:** cztery źródłowe powierzchnie `temple01/03/05/07.frm` są
  prostowane z czworokątów do `32 × 102`, łączone w runtime w jeden pas i
  powtarzane co `4.32` jednostki. Początek UV jest deterministycznie przesuwany
  zależnie od pierwszego heksa komponentu.
- **Obserwacja:** przebiegi pozostają proste, a wariant cegieł nie resetuje się
  na każdym metrze. Nie powstały nowe piksele ani generowana tekstura.
- **Ograniczenie:** wszystkie cztery warianty należą do tej samej rodziny i są
  do siebie podobne; ostateczny rytm materiału nadal wymaga oceny w ruchu.

## 3. `temple35/36`: relief albo łuk z krótkimi skrzydłami muru

- **Potwierdzenie par:** 24 rekordy tworzą 12 jednoznacznych par o tym samym
  elevation i relacji `hex(second) = hex(first) + 800`. Greedy pairing po
  odległości został odrzucony, bo przy równoległych parach pozostawiał dwa
  rekordy bez partnera.
- **Test nośnika:** dla każdej pary szukany jest najbliższy mur
  `temple09–14.frm` na tym samym elevation.
- **Wynik:** sześć par ma nośnik w odległości około `1.732` i jest ornamentem na
  pełnej ścianie. Sześć pozostałych ma najbliższy taki mur w odległości
  `5.0–7.94`. Oznaczenie dokładnych prostokątów FRM na źródłowym kompozycie
  wykazało, że `temple35/36` zawiera łuk, mur nad nim i krótki fragment muru po
  obu bokach. Nie jest to ani sama obręcz, ani pełna ściana na całą rozpiętość
  heksów pary.
- **Reguła:** para z nośnikiem do `3.0` jest przyciągana do fizycznej płaszczyzny
  muru i dostaje płytki łuk-relief. Para bez takiego nośnika dostaje otwór,
  ościeża, pierścień, mur nad łukiem i dwa źródłowo uzasadnione skrzydła muru po
  `0.52` jednostki. Dłuższą kontynuację może utworzyć tylko osobny rekord MAP.
- **Źródło wyglądu:** prostowany wycinek `temple33.frm`; źródło topologii:
  rekordy MAP i obecność/nieobecność nośnika `temple09–14`.
- **Dowody:** `artifacts/arcaves-wall-relief-front.png`,
  `artifacts/arcaves-wall-relief-side.png`,
  `artifacts/arcaves-room-arch-front.png` i
  `artifacts/arcaves-room-arch-side.png`.

## Odrzucone reguły

1. Pełny sprite architektury jako karta — brak głębi i błędna perspektywa.
2. Każde `temple35/36` jako portal — kontrprzykład na ciągłym murze.
3. Każde `temple35/36` jako relief — sześć par nie ma muru nośnego i zawiera
   rzeczywiste otwory przejść.
4. Najbliższy partner FRM — jest niejednoznaczny dla równoległych par; relacja
   heksów `+800` jest stabilna dla wszystkich 12 par.
5. Stały offset reliefu — zastąpiony przyciąganiem do rzeczywistej płaszczyzny
   najbliższego potwierdzonego nośnika.
6. Wypełnienie murem całej rozpiętości niepodpartej pary `temple35/36` — dawało
   dwa zbyt szerokie, pełnowysokie bloki. Zastąpione krótkimi skrzydłami
   zmierzonymi z zawartości FRM.
7. Wolnostojąca obręcz bez muru nad łukiem i po bokach — stworzyła widoczne
   dziury. Odrzucona po korekcie użytkownika i porównaniu oznaczonych prostokątów
   `temple35/36` na kompozycie źródłowym.
8. Surowe scalanie wyłącznie po indeksach `±1/±200` — rozbiło warstwy obrazowe
   ścian na `648` nośników i `8644` trójkąty oraz utworzyło czarny grzebień
   pojedynczych płyt w ISO. Wariant został cofnięty.

## 4. Regresja „dziwny labirynt”

- **Korekta użytkownika:** po dodaniu pełnych portali mapa wyglądała jak sztuczny
  labirynt.
- **Przyczyna:** sama odległość od `temple09–14` nie mówi, jak szeroki fragment
  muru jest zaszyty w dwóch klatkach łuku. Pierwszy wariant tworzył zbyt szeroki
  mur, a kontrwariant usuwał go całkowicie.
- **Kandydat:** niepodparte pary mają łuk ze spandrelem i skrzydłami muru po
  `1.1` jednostki. Wartość została zwiększona dopiero po porównaniu konkretnego
  przejścia `19912/20712` z kompozytem źródłowym elevation 0.
- **Oracle:** `artifacts/arcaves-walls-e0-source-composite.png` składa `1145`
  rekordów `art\\walls` z samego elevation 0 dokładnie według pozycji MAP i
  offsetów `fallout2-ce`; manifest z hashami znajduje się obok w pliku JSON.
  Starszy `arcaves-walls-source-composite.png` mieszał trzy elevation i nie może
  już służyć jako oracle topologii pojedynczego poziomu. Kompozyt elevation 0
  potwierdza, że sama Świątynia Prób rzeczywiście ma układ labiryntowy, więc nie
  wolno usuwać pozostałych ścian tylko dlatego, że tworzą małe korytarze.
- **Dowód:** `artifacts/arcaves-room-arch-source-annotated.png` pokazuje na
  czerwono dokładne prostokąty `temple35/36`, a
  `artifacts/arcaves-room-arch-front.png` bieżący runtime. Werdykt wizualny
  użytkownika nadal oczekuje.

## 5. Trzy kadry `gowno1–3`: osie portali i słupy końcowe

- **Dowód wejściowy:** `feedback-gowno1-baseline.png`,
  `feedback-gowno2-baseline.png` oraz `feedback-gowno3-baseline.png` w
  ignorowanym `artifacts/`. Odtwarzalne pozycje kamery to odpowiednio heksy
  `13082`, `20306` i `23308`.
- **Błąd osi:** końce `temple33/34` są kotwicami rysunku izometrycznego, a nie
  punktami leżącymi na fizycznej osi muru. Normalizacja wektora między nimi
  obracała portal względem dochodzącej ściany. Renderer zachowuje teraz zwrot
  pary, ale snapuje yaw do kanonicznej osi siatki określonej przez regułę
  rodziny.
- **Błąd semantyczny:** `temple90–95.frm` przedstawiają zakończenia i słupy, ale
  trafiały do ogólnego scalania prostych ścian. Są teraz nośnikami kolumnowymi,
  tak jak potwierdzone `temple32/96/97/98`.
- **Kontrprzykład dla automatycznego „łatania dziur”:** źródłowy crop
  `feedback-gowno3-source-e0.png` pokazuje, że czarna przestrzeń na prawo od
  drzwi jest prawdziwym bocznym przejściem ograniczonym słupem. Nie wolno jej
  zamurować zwiększeniem zakładki portalu.
- **Kandydaci:** `feedback-gowno1-candidate.png`,
  `feedback-gowno2-candidate.png` i `feedback-gowno3-candidate.png`. Portal ma
  wspólną oś z murem, a boczne przejście w trzecim kadrze ma czytelny słup.
  Materiał podłogi, sufit i rytm tekstur pozostają osobną, niezaakceptowaną
  klasą problemów wizualnych.

## Czarne szczeliny kontra prawdziwe przejścia (`20505` i `21107`)

- **Baseline runtime:** `feedback-gap-baseline.png` oraz
  `feedback-gap-live-after-first-fix.png`. Drugi kadr pochodzi z heksa `21107`,
  kierunek logiczny `4`.
- **Błąd geometrii portalu:** skrzydła niepodpartej pary `temple35/36` kończyły
  się przed niewidocznymi rekordami `block.frm`. Ich długość jest teraz liczona
  osobno dla każdej strony z najbliższego kontaktu na osi ściany, zamiast ze
  stałej właściwej tylko jednemu egzemplarzowi.
- **Błąd rodziny narożników:** `temple99.frm` był traktowany jak prosta ściana.
  Jest teraz częścią rodziny źródłowych narożników/słupów `temple90–99`, z
  nośnikiem `0.86 × 0.86` na pełną wysokość `3.0`.
- **Błąd materiału:** source material zaczynał jako unshaded, ale kod ARCAVES
  nadpisywał go na per-pixel lighting. Boczne i czołowe powierzchnie odwrócone
  od lampy wyglądały przez to jak brak geometrii. Oryginalne piksele Fallouta
  mają wypalone światło, więc ściany, słupy i trim ARCAVES pozostają unshaded.
- **Kontrola wielokątowa:** `feedback-gap2-candidate.png`,
  `feedback-gap2-left.png`, `feedback-gap2-right.png` oraz
  `feedback-gap2-iso.png`. Wąskie czarne szwy przy łuku zostały usunięte.
  Szerokie otwarcie z ciągłą podłogą jest przejściem z MAP, a nie szwem; nie
  wolno go zamurować tylko na podstawie koloru tła. Wymaga później osobnej
  reguły czytelnych ościeży dla nieobramowanych przejść.
- **Korekta po odrzuceniu użytkownika:** pełny kadr z `20513/0`
  (`feedback-holes-19920-full.png`) ujawnił regularnie odsłonięte miejsca za
  ścianą, których wcześniejsze ujęcia nie pokazywały. ARCAVES zawiera 386
  ściennych rekordów `art/walls/block.frm` (179/111/96 na elevation 0/1/2).
  Oryginał używa ich jako niewidocznej topologii i blokady, przykrywanej przez
  izometryczne FRM. FPP potrzebuje w tych miejscach rzeczywistego nośnika 3D.
  Renderer włącza więc wyłącznie rekordy **wall** `block.frm` do kamiennej
  geometrii; techniczne rekordy **scenery** `block.frm` pozostają niewidoczne.
  Wynik to 556 nośników i 9436 trójkątów, a długie ściany są ciągłe w FPP oraz
  ISO. `feedback-holes-candidate.png` jest kadrem akceptacyjnym technicznym;
  werdykt użytkownika nadal oczekuje.
- Szare prostokąty na tym samym kadrze były proxy mebli `TEMPSF04.FRM`, a nie
  otworami. Zostały zastąpione pikselami źródłowymi jako powierzchnie stałe.
  Ich docelowa minimalna geometria ławki pozostaje osobnym zadaniem jakościowym.

## Weryfikacja

- `28 passed` w `pytest`;
- `ruff check .` przechodzi;
- kontrakt Godot: 9 portali `temple33/34`, 12 reliefów `temple35/36`, zero
  nieużytych rekordów obu rodzin;
- bridge probe: 6 zdarzeń odebranych, 5 zastosowanych, drzwi na klatce `18`,
  collider wyłączony, `passed = true`;
- kadry front/bok dla reliefu i przejścia;
- źródłowy kompozyt `1145` ścian elevation 0 oraz manifest ich położeń i hashów;
- werdykt wizualny użytkownika: oczekuje.

## Lekcja dla kolejnych lokacji

Nazwa, obraz i para FRM nie definiują samodzielnie typu architektury. Najpierw
trzeba ustalić relację rekordów oraz obecność fizycznego nośnika w MAP. Dopiero
potem wybiera się minimalną geometrię: pełny mur, relief na murze albo otwarty
portal. Regułę wolno rozszerzyć na kolejną rodzinę dopiero po dwóch zgodnych
przypadkach i kadrze z boku.
