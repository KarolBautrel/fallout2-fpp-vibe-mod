# Instrukcje projektu

## Cel

Buduj pionowy wycinek Fallouta 2 z przełączaniem ISO/TPP. Nie rozszerzaj zakresu na pełny remake, FPP ani nowe assety, dopóki jedna lokacja nie przejdzie testów akceptacyjnych.

## Niezmienne zasady

- Traktuj instalację Steam jako tylko do odczytu.
- Nie kopiuj do repo `master.dat`, `critter.dat`, `patch000.dat`, map, sprite'ów, muzyki ani save'ów.
- Narzędzia mogą czytać dane ze ścieżki przekazanej przez użytkownika; artefakty pośrednie zapisuj w ignorowanym `artifacts/`.
- Używaj `fallout2-ce` jako źródła prawdy przed zgadywaniem formatu lub zachowania.
- Każdą hipotezę o formacie potwierdź testem na co najmniej dwóch rekordach albo round-tripem, gdy istnieje zapis.
- Nie publikuj forka ani konwertera bez osobnego przeglądu licencji i zawartości.

## Kolejność pracy

1. Zbuduj niezmienione `fallout2-ce` i uruchom je na danych użytkownika.
2. Zidentyfikuj minimalny zestaw danych mapy: heksy, poziom, ściany, drzwi, obiekty i blokady ruchu.
3. Wyeksportuj jedną lokację do jawnego, wersjonowanego schematu pośredniego.
4. Wyrenderuj ją najpierw jako debugową geometrię 3D.
5. Dodaj jedną postać i przełączanie ISO/TPP.
6. Dodaj jedną interakcję i test zgodności pozycji.

## Weryfikacja

Każdy etap ma zostawić odtwarzalny dowód: polecenie, log, JSON lub screenshot w `artifacts/`. Nie traktuj efektu wizualnego jako zgodności logiki bez porównania współrzędnych i stanu.

