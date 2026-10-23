# Automatyczny pipeline geometrii i wyglądu

Nie będziemy modelować każdej mapy osobno. Docelowy przepływ jest wspólny dla
wszystkich lokacji:

```text
MAP + PRO + FID/LST + FRM -> scene-v1 -> topologia 3D -> materiały/asset profiles -> Godot
```

## Co pochodzi z danych Fallouta 2

- `MAP` dostarcza poziomy, podłogi, dachy, heksy, pozycje obiektów i stan mapy.
- `PRO` dostarcza typ i znaczenie obiektu, na przykład ściana, drzwi lub sceneria.
- `FID` wybiera typ grafiki i zero-based indeks wpisu w odpowiednim pliku `.lst`.
- `art/<typ>/<typ>.lst` wskazuje konkretny plik `FRM`.
- `FRM` zawiera oryginalny wygląd 2D, klatki oraz offsety używane przez renderer
  izometryczny.

Resolver w `src/fo2remix/art_format.py` odtwarza regułę `artBuildFilePath` z
`fallout2-ce`. Eksporter zapisuje przy obiekcie jawne pole `art`, ale nie kopiuje
oryginalnych plików do repozytorium. Na danych użytkownika potwierdzono między
innymi mapowanie ściany na `art\walls\temple19.frm` oraz drzwi na
`art\scenery\acavedr4.frm`.

Parser `src/fo2remix/frm_format.py` odczytuje już nagłówek, wymiary, liczbę
klatek, offsety i deskryptory sześciu kierunków. Dekoduje też indeksy palety
`color.pal` do RGBA i zapisuje pojedyncze klatki jako PNG z przezroczystością.
Polecenie `frm-inspect` zostawiło dowody w ignorowanych plikach
`artifacts/temple19.frm-metadata.json` i
`artifacts/acavedr4.frm-metadata.json`. Pierwszy asset ma jedną klatkę
`33 × 116`, a animowane drzwi mają 19 klatek i pierwszą klatkę `105 × 97`.
Polecenie `scene-art-cache` przetwarza każdy unikalny asset sceny tylko raz.
Cache obejmuje obecnie również źródłowe kafle podłóg i dachów: ARCAVES używa
151 unikalnych FRM, a ARTEMPLE 193. Manifest ma schemat
`fo2remix.art-cache-v1`. Eksporter zapisuje również średni
kolor nieprzezroczystych pikseli FRM, z którego korzysta debugowy materiał 3D.
Eksperyment z bezpośrednim nakładaniem całej klatki FRM na każdą odsłoniętą
ścianę został odrzucony po teście wizualnym: izometryczne sprite'y tworzyły
nachodzące na siebie pionowe karty, widoczne zęby i niespójne łączenia. Nie jest
to jednak zgoda na proceduralny wygląd. Docelowa powierzchnia dostaje minimalną
geometrię i UV lub projekcję z odpowiedniego fragmentu źródłowego FRM. Obecne
proceduralne materiały ARCAVES są blockoutem diagnostycznym, nie zaakceptowanym
wynikiem wizualnym.
Drzwi korzystają z osobnego panelu źródłowego: stan zamknięty pokazuje klatkę
`0`, a odebrane z bridge'a otwarcie przełącza grafikę na ostatnią klatkę FRM.
Kolizja i stan nadal pochodzą z `fallout2-ce`, nie z animacji.

`scene-v1` zapisuje teraz również `frame`, ekranowy offset instancji,
`light.distance`, `light.intensity` oraz komplet deskryptorów klatek i rotacji
FRM. Potwierdzenie na ARCAVES wykazało 54 widoczne pochodnie, ale ich własne
pola światła są zerowe. Oświetlenie pochodzi z 76 osobnych, niewidzialnych
rekordów `block.frm`. Godot zachowuje ten model zamiast przypisywać zgadywane
światło każdej grafice pochodni.

## Co jest automatyczne

Godot buduje ściany jako cienkie segmenty 3D, a nie pionowe karty ani pełne
heksagonalne klocki. Kierunek jest klasyfikowany z wariantu FRM: rodziny o
szerokości bazowej 16 i 32 px odpowiadają dwóm osiom ścian Fallouta. Hipotezę
potwierdzają co najmniej pary `temple01/temple02` oraz `ca053/ca052`.
Wielokrotne sprite'y na tym samym heksie są kompozycją obrazu izometrycznego i
zapadają się do jednego segmentu, co usuwa z-fighting i falowanie. Techniczny
`art\\walls\\block.frm` uczestniczy wyłącznie w kolizji. ARTEMPLE odzyskuje
wygląd budowli z rodzinnych modeli
`TEMPLE01`–`TEMPLE08`. W ARCAVES ściany `temple*` używają ostrego materiału
bloków kamiennych, a `ca*` osobnego materiału naturalnej skały. Podłogi,
ściany, drzwi i sceneria z innych elevation są ukrywane,
gdy postać znajduje się na bieżącym poziomie. Ten kod działa na dowolnym
`scene-v1`, więc kolejna lokacja nie wymaga osobnego modelowania topologii.
Jeżeli MAP ma jawne `roof_ids`, powstają z nich sufity. Gdy dachy są puste,
gęste wnętrza, takie jak ARCAVES, otrzymują sufit nad footprintem wszystkich
niepustych kafli podłogi. Rzadka lokacja zewnętrzna ARTEMPLE nie dostaje
automatycznego sufitu; wcześniejszy flood-fill błędnie przykrywał niebo. Płyty
sufitu wnętrza lekko zachodzą na górną krawędź ścian, co usuwa prześwity.
Sufity są widoczne w FPP, ukryte w ISO i dzielone według aktywnego elevation.

Podłogi nie używają już kolorowych placeholderów. Typ `tiles` jest rozwiązywany
przez ten sam `FID -> .lst -> FRM`, a izometryczny romb `80 x 36` jest mapowany
na płaszczyznę świata przez cztery zmierzone narożniki nieprzezroczystego
obszaru. ARCAVES wykorzystuje 25 rodzin kafli, a ARTEMPLE 166. Surowe
izometryczne FRM są używane selektywnie jako billboardy 2.5D. Pochodnie i
dekoracje ścienne zachowują rotację z MAP, drzewa używają dwóch skrzyżowanych
kart, a kości leżą jako
decal podłoża. Crittery mają sześć kierunków pochodzących bezpośrednio z FRM;
renderer dobiera widok na podstawie kierunku obiektu i położenia kamery.
Architektura `TEMPLE01`–`TEMPLE08` pozostaje geometrią, bo billboard nie odzyska
jej wnętrza ani tylnej strony. ARCAVES ma 7 itemów: cztery skrzynie
`chest1.frm`, dwie wazy i kości. Maksymalnie 12 najbliższych źródłowych świateł
na aktywnym elevation jest włączonych jednocześnie. Pozycja, zasięg i energia
pochodzą z MAP; renderer dodaje jedynie subtelną modulację energii w czasie.

Statyczne `atorch3/4/5.frm` opisują uchwyt, nie animowany ogień. Płomień jest
wycinany z 12 źródłowych klatek `firepit.frm`. Rodzina filarów
`temple32/96/97/98.frm` nie jest już rozciągana jako ściana: boczny czworokąt
z `TEMPLE97.FRM` jest prostowany na minimalną bryłę nośną.

Nośnik ścian nie powstaje już jako osobny prostopadłościan dla każdego heksa.
Renderer odzyskuje dwie prostopadłe osie fizyczne z transformacji kwadratowej
siatki podłogi. Pierwsza z nich wymaga naprzemiennych kroków w kierunkach heksa
0/1, które są rzutowane na jedną prostą; druga pokrywa się z kierunkiem 2/5.
Spójne komponenty są następnie scalane w pojedyncze przebiegi. Usuwa to
harmonijkę wynikającą z traktowania kierunków 0 i 1 jako osobnych ścian.

Zewnętrzne assety `TEMPLE01`–`TEMPLE08` są jedną rodziną kompozytową. Polecenie
`scene-source-composite` odtwarza ich obraz według `tileToScreenXY` i
`objectGetRect` z `fallout2-ce`; dowód zawiera hashe wszystkich ośmiu PNG.
Pierwsza próba zachowania całej kompozycji jako nieruchomej fasady została
odrzucona po runtime capture `artifacts/rejected-artemple-flat-facade.png`: nadal pokazywała rzut ISO jako
wiszącą kartę i nie zmieniała perspektywy. Aktualna reguła buduje ciągłe odcinki
ścian z 45 technicznych rekordów `art\\walls\\block.frm`, nakłada na nie piksele
z oryginalnego `temple19.frm`, a unikalny portal jest małą powierzchnią cechy
osadzoną na krawędzi wyznaczonej przez dwa heksy MAP. Następna iteracja rozcina
pozostałe ornamenty na front, lewy i prawy bok oraz przypisuje im osobne UV.
Reguła jest wersjonowana w
`godot/data/source_geometry_rules.json`; techniczne `block.frm` nadal zapewniają
autorytatywną kolizję.

Nie wolno uznawać każdej pary `temple33–36.frm` za wejście. Eksperyment z 21
automatycznymi łukami został odrzucony: `temple35/36.frm` może nakładać ornament
na ciągły mur `temple09–14.frm`, a nie oznaczać wolny prześwit. Pierwszym wzorcem
jest wyłącznie prawdziwy portal drzwi `instance_id = 1338` na heksie `24308`,
otoczony rekordami `temple34.frm` na `24305` i `temple33.frm` na `24310`.
Renderer prostuje klatki `acavedr4.frm`, nakłada je na łukową powierzchnię drzwi
i buduje nośnik 3D z ościeżami, krzywizną, grubością oraz bocznymi wypełnieniami.
Pełne izometryczne sprite'y łuku nie są wyświetlane jako karty. Reguła nie może
zostać rozszerzona na pozostałe portale przed osobnym przeglądem użytkownika.

## Czego nie da się odzyskać automatycznie 1:1

`FRM` jest prerenderowanym obrazem izometrycznym, a nie modelem 3D. Nie zawiera
tylnej strony ściany, jej prawdziwej głębokości ani kompletnego materiału PBR.
Dlatego warstwa FPP będzie hybrydą:

1. automatyczna topologia i kolizja z `MAP`/`PRO`;
2. automatyczny odczyt palety, klatek i wymiarów z `FRM`;
3. mały katalog wielokrotnie używanych profili dla rodzin assetów, na przykład
   ściana świątyni, metalowa ściana, drzwi i skała;
4. ręczne wyjątki tylko dla obiektów, których nie da się wiarygodnie uogólnić.

Przetwarzanie powinno być wykonywane na żądanie i cache'owane po unikalnym FID.
Koszt rośnie więc głównie z liczbą unikalnych assetów, a nie z liczbą map.

## Rola reverse engineeringu

Pierwszym źródłem prawdy pozostaje `fallout2-ce`. REA jest potrzebne dopiero,
gdy zachowanie retailowego EXE nie jest opisane w źródłach albo gdy trzeba
potwierdzić punkt integracji. Nie jest generatorem brakujących modeli 3D i nie
zastąpi danych `MAP`/`PRO`/`FRM`.

## Następny etap

Najbliższy krok to segmentacja `TEMPLE01–08` na powierzchnie fasady, boków,
portalu i stopni, a następnie bake UV bez zmiany pikseli źródłowych. Każda
iteracja musi zostawić zestawiony kadr ISO/FPP i dopiero po akceptacji przejść do
kolejnej rodziny. Statyczne crittery są już eksportowane i renderowane w sześciu
kierunkach; późniejszym krokiem jest przesyłanie ich bieżącej pozycji, rotacji i
klatki przez bridge. Profile nadal są definiowane dla rodzin assetów, nie osobno
dla map. Źródłowe i pośrednie tekstury pozostają w ignorowanym `artifacts/`.

Pełny opis trybów billboardów, komenda odtwarzająca cache i reguły QA znajdują
się w `docs/BILLBOARDS.md`.
