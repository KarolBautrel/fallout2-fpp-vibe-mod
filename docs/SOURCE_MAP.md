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

`src/object.cc::objectRead` czyta 18 wartości `int32`: ID, heks, przesunięcia,
współrzędne ekranowe, klatkę, obrót, FID, flagi, poziom, PID, CID, światło,
pole nieznane, SID i indeks skryptu. Potem `objectDataRead` czyta trzy pola
ekwipunku oraz dane zależne od typu PID. Ekwipunek jest zapisany rekurencyjnie.

Typ przedmiotu lub scenerii pochodzi z odpowiadającego pliku `.pro`. Resolver
używa tej samej reguły co `_proto_list_str`: dolne 24 bity PID wybierają
1-based wiersz z `proto/<type>/<type>.lst`, a pierwszy token wiersza wskazuje
plik prototypu. Nie wyprowadzamy typu drzwi z FID ani nazwy grafiki.

`src/object.cc::_obj_blocking_at` uznaje obiekt za blokujący ruch, gdy:

- nie ma `OBJECT_HIDDEN` (`0x01`);
- nie ma `OBJECT_NO_BLOCK` (`0x10`);
- typ FID to critter, scenery lub wall.

`OBJECT_MULTIHEX` (`0x800`) rozszerza blokadę na sześć sąsiednich heksów.
Otwarte drzwi mają złożoną flagę `OBJECT_OPEN_DOOR` (`0xA0000010`), a stan
otwarcia jest dodatkowo zapisany w bicie `0x01` danych instancji drzwi.

## Potwierdzone na instalacji Steam

- parser katalogu `master.dat` znalazł 23 140 wpisów i 155 plików `.map`;
- `maps\artemple.map` poprawnie rozpakowano przez zlib;
- nagłówek ma wersję `20`, nazwę `ARTEMPLE.MAP` i startowy heks `18492`;
- flagi `12` oznaczają, że w pliku istnieje tylko poziom `0`;
- poziom zawiera 10 000 wartości podłoga/dach, zgodnie z siatką `100 × 100`.
- pełny odczyt `ARTEMPLE.MAP` daje 567 obiektów: 45 ścian, 397 rekordów
  scenerii i 419 blokowanych heksów;
- `ARTEMPLE.MAP` nie zawiera drzwi;
- kontrolny odczyt `KLAMALL.MAP` daje 24 drzwi; co najmniej rekordy ID `146`
  na heksie `12675` i ID `57` na heksie `12692` zostały rozpoznane przez
  realne prototypy `.pro` jako zamknięte drzwi blokujące;
- oba pliki zostały odczytane do końca wraz ze skryptami, obiektami zależnymi
  od prototypów i rekurencyjnymi ekwipunkami.

## Najbliższy krok

Wybrać jeden blokujący obiekt scenerii w `ARTEMPLE.MAP` i dodać wspólną
interakcję ISO/FPP. Jeśli pierwsza interakcja ma być koniecznie drzwiami,
trzeba jawnie zmienić mapę pionowego wycinka, ponieważ `ARTEMPLE.MAP` nie ma
żadnego rekordu drzwi.

