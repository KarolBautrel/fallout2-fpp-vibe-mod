# ARTEMPLE — rejestr powierzchni ISO → FPP

Ten plik jest roboczą bramką jakości dla pierwszej rodziny architektonicznej.
Żaden element nie jest „gotowy” tylko dlatego, że istnieje w runtime. Metoda
odpowiada procesowi opisanemu dla Diablo First Person: dane mapy tworzą minimalną
topologię, a ręcznie nadzorowane reguły rodziny przypisują oryginalne piksele do
powierzchni 3D o właściwych normalnych.

## Odrzucony wariant

`artifacts/rejected-artemple-flat-facade.png` pokazuje odrzuconą projekcję całej
kompozycji `TEMPLE01–08` na jedną pionową kartę. Zachowywała piksele, ale nie
zmieniała perspektywy: dach, ściany i ornamenty wisiały w jednej płaszczyźnie.
Kod tworzący tę fasadę został usunięty z runtime.

## Aktywne źródła topologii

- 45 rekordów `art\\walls\\block.frm` — ścieżki ścian i autorytatywna blokada;
- `art\\scenery\\block.frm` — pozostałe blokady, domyślnie niewidoczne;
- kafle podłogi MAP — poziom gruntu i dojście;
- `TEMPLE01–08` — widoczna tożsamość, nie samodzielna geometria;
- `temple19.frm` — oryginalny materiał rodzinny dla roboczych powierzchni ścian.

## Ledger

| Część | Źródło | Nośnik | Stan | Następny dowód |
|---|---|---|---|---|
| Ściany nośne | 45 heksów `walls/block.frm` | połączone odcinki + złącza | zaimplementowane, wizualnie niezaakceptowane | front, bok i przejście bez dziur |
| Materiał ścian | crop `temple19.frm` | powtarzalne UV | prototyp; zbyt widoczne powtórzenia | bake atlasu z kontrolą texel density |
| Portal | crop `TEMPLE01` | nieruchoma powierzchnia na krawędzi dwóch heksów | prototyp; wymaga kalibracji | matched FPP front + 45° |
| Lewa bryła / wieża | `TEMPLE02`, `TEMPLE03` | brak zatwierdzonego nośnika | nierozwiązane | segmentacja front/bok, osobne UV |
| Relief twarzy | `TEMPLE04` | płytki relief lub decal na ścianie | nierozwiązane | front + niski kąt bez rozciągnięcia |
| Środkowy trim | `TEMPLE05` | geometria krawędziowa + UV | nierozwiązane | zbliżenie narożnika |
| Prawa bryła / wieża | `TEMPLE06` | brak zatwierdzonego nośnika | nierozwiązane | segmentacja front/bok, osobne UV |
| Cień / okap | `TEMPLE07`, `TEMPLE08` | nie może tworzyć bryły | sklasyfikowane jako baked shadow | porównanie z wariantem bez shadow |
| Dach i sufity | footprint MAP + crop tej samej rodziny | minimalna płyta/pryzmat | nierozwiązane | widok z góry i z wnętrza |
| Schody | dojście i blokady MAP | rzeczywiste stopnie | nierozwiązane po usunięciu arbitralnych schodów | zgodność wysokości i przejścia gracza |
| Paleniska | `FIRPIT01/02` | stała powierzchnia, nie billboard do kamery | prototyp | dwa kąty i animacja bez obracania tła |

## Kolejność pracy

1. Zablokować geometrię ścian z MAP i usunąć dziury/z-fighting.
2. W Blenderze podzielić `TEMPLE01–06` na nazwane regiony powierzchni, bez
   generowania nowej grafiki.
3. Dla każdej powierzchni wybrać najlepszy fragment źródłowy i zapisać UV.
4. Wyrenderować stałe kamery: front FPP, FPP 45°, bok FPP oraz kalibrowane ISO.
5. Porównać pełną rozdzielczość, nie miniaturę. Poprawiać konstrukcję przed
   detalem i oświetleniem.
6. Dopiero po akceptacji użytkownika przenieść regułę na kolejną rodzinę/mapę.

Runtime techniczny, screenshot i udany test nie oznaczają akceptacji wizualnej.

