# Mapa źródeł `fallout2-ce`

Pierwszy przegląd wykonano na gałęzi `main` repozytorium `alexbatalov/fallout2-ce`. Po sklonowaniu silnika należy przypiąć commit i ponownie potwierdzić numery linii.

## Ładowanie mapy

`src/map.cc::mapLoad` czyta dane w tej kolejności:

1. nagłówek mapy;
2. zmienne globalne mapy;
3. zmienne lokalne mapy;
4. dane podłóg/dachów dla dostępnych poziomów;
5. skrypty;
6. obiekty.

Silnik akceptuje wersje mapy `19` i `20`.

## Nagłówek

`src/map.h::MapHeader` i `src/map.cc::mapHeaderRead` opisują nagłówek o rozmiarze 236 bajtów:

- wersja: `int32`;
- nazwa: 16 bajtów;
- wejściowy heks, poziom i obrót;
- liczba zmiennych lokalnych;
- indeks skryptu;
- flagi i ciemność;
- liczba zmiennych globalnych;
- indeks mapy;
- czas ostatniej wizyty: `uint32`;
- 44 zarezerwowane `int32`.

`src/db.cc::fileReadInt32` jawnie odwraca kolejność bajtów na hostach little-endian, więc liczby w plikach map są zapisywane big-endian.

## Kafelki i poziomy

`src/map.cc::_square_load` przechodzi przez trzy poziomy. Dla każdego obecnego poziomu czyta `SQUARE_GRID_SIZE` wartości `int32`. Dolne 16 bitów i górne 16 bitów przechowują identyfikatory/flagowanie warstw; dokładne znaczenie bitów trzeba potwierdzić w kodzie renderowania przed eksportem.

## Heksy i ekran

`src/tile.cc` ustawia siatkę heksów na 200 × 200. Indeks logiczny jest przeliczany następująco:

```text
column = 199 - (tile % 200)
row    = tile / 200
```

`tileToScreenXY` używa charakterystycznych kroków 32/16 px w poziomie oraz 12 px w pionie. `tileGetTileInDirection` wybiera sąsiada według parzystości kolumny i jednego z sześciu obrotów.

Nie kopiujemy projekcji ekranowej bezpośrednio do świata 3D. Najpierw zachowujemy indeks heksa oraz kolumnę/wiersz, a osobna jawna transformacja tworzy współrzędne Godot.

## Obiekty

`src/object.cc::objectRead` zaczyna od stałego zestawu pól `int32`: ID, heks, przesunięcia, współrzędne ekranowe, klatka, obrót, FID, flagi, poziom, PID, CID, światło i skrypt. Następna część zależy od typu prototypu i może wymagać danych `.pro`.

Pierwszy parser nie będzie próbował odczytywać wszystkich obiektów. Zacznie od nagłówka mapy i współrzędnych, a obiekty dojdą po sklonowaniu źródeł i wybraniu konkretnej lokacji.

## Potwierdzone na instalacji Steam

- parser katalogu `master.dat` znalazł 23 140 wpisów i 155 plików `.map`;
- `maps\artemple.map` poprawnie rozpakowano przez zlib;
- nagłówek ma wersję `20`, nazwę `ARTEMPLE.MAP` i startowy heks `18492`;
- flagi `12` oznaczają, że w pliku istnieje tylko poziom `0`;
- poziom zawiera 10 000 wartości podłoga/dach, zgodnie z siatką `100 × 100`.

## Najbliższy krok

1. Sklonować i przypiąć `fallout2-ce`, gdy terminal odzyska dostęp do sieci.
2. Rozpoznać listy nazw kafelków i format `.frm`, aby powiązać ID z grafiką.
3. Wczytać `artemple.scene-v1.json` do minimalnego projektu Godot.
4. Narysować podłogę zastępczymi materiałami i zaznaczyć startowy heks.
5. Dodać przełączanie kamery ISO/TPP nad tą samą sceną.

