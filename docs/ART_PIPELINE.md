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
Eksperyment z bezpośrednim nakładaniem klatki FRM na każdą odsłoniętą ścianę
został odrzucony po teście wizualnym: izometryczne sprite'y tworzyły nachodzące
na siebie pionowe karty, widoczne zęby i niespójne łączenia. Ściany korzystają
teraz wyłącznie ze wspólnej siatki topologii oraz proceduralnego materiału
kamienia. FRM nadal dostarcza kolor i identyfikację rodziny materiału, ale nie
jest rozciągany jako tekstura całej ściany.
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

Godot buduje obecnie zamkniętą siatkę graniczną sumy heksów zajętych przez
rekordy ścian MAP. Wspólne krawędzie są usuwane, więc sąsiednie komórki nie
tworzą nakładających się płaszczyzn ani szczelin. Techniczny sprite
`art\\walls\\block.frm` pozostaje niewidoczny, ale jego heks uczestniczy w
topologii i kolizji; dzięki temu ARTEMPLE zachowuje bryłę budowli mimo braku
zwykłych rekordów ścian. Świątynia używa proceduralnego kamienia, a ARCAVES
osobnego, ciągłego materiału skały bez ceglanego wzoru. Podłogi, ściany, drzwi
i sceneria z innych elevation są ukrywane,
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
izometryczne FRM nie są już domyślnie ustawiane pionowo w świecie FPP, ponieważ
powodowało to spłaszczone, źle zakotwiczone karty. Jawna lista bezpiecznych
rodzin zachowuje billboardy tylko dla efektów takich jak pochodnie, ogień i
wodospad. Drzewa, skały, wyposażenie świątyni, skrzynie, wazy i kości dostają
stabilne bryły proxy w dokładnych pozycjach MAP; nierozpoznane dekoracje są
ukryte do czasu dodania profilu rodziny. ARCAVES ma 7 itemów: cztery skrzynie
`chest1.frm`, dwie wazy i kości. Maksymalnie 12 najbliższych źródłowych świateł
na aktywnym elevation jest włączonych jednocześnie, ze stałą energią bez
syntetycznego migotania.

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

Po teście użytkownika następnym krokiem będzie porównanie kilku konkretnych
punktów mapy ISO/FPP, korekta profili rodzin proxy oraz płynne odtwarzanie
pośrednich klatek drzwi. Dopiero po zgodności układu i blokad dojdzie pierwszy
ruchomy critter. Profile nadal są definiowane dla rodzin assetów, nie osobno
dla map. Wygenerowane tekstury pozostają w ignorowanym `artifacts/`.
