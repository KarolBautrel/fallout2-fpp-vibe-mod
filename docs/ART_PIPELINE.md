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
Dla ARCAVES z 2622 instancjami ścian utworzyło 126 unikalnych PNG i manifest
`fo2remix.art-cache-v1` w około pół sekundy. Tryb `--all-frames` utworzył 166
PNG o łącznym rozmiarze około 0,5 MB. Eksporter zapisuje również średni
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

## Co jest automatyczne

Godot buduje obecnie jedną spójną siatkę debugowych ścian z zajętych heksów,
usuwa niewidoczne ściany pomiędzy sąsiadującymi komórkami i rozdziela wynik na
elevation. Podłogi, ściany, drzwi i sceneria z innych elevation są ukrywane,
gdy postać znajduje się na bieżącym poziomie. Ten kod działa na dowolnym
`scene-v1`, więc kolejna lokacja nie wymaga osobnego modelowania topologii.
Jeżeli MAP ma jawne `roof_ids`, powstają z nich sufity. Gdy dachy są puste,
renderer wybiera jedną z dwóch automatycznych strategii. Dla gęstych wnętrz,
takich jak ARCAVES, sufit pokrywa footprint wszystkich niepustych kafli podłogi;
dla rzadszych map, takich jak ARTEMPLE, zamknięte regiony są wykrywane
flood-fillem po blokadach. Płyty sufitu lekko zachodzą na górną krawędź ścian,
co usuwa prześwity. Sufity są widoczne w FPP, ukryte w ISO i dzielone według
aktywnego elevation.

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

Po akceptacji bieżącego wyglądu jednej lokacji następnym krokiem będzie
płynne odtwarzanie pośrednich klatek drzwi oraz pierwsza reprezentacja ruchomego
crittera. Profile materiałów nadal powinny być definiowane dla rodzin assetów,
nie osobno dla map. Wygenerowane tekstury pozostają w ignorowanym `artifacts/`.
