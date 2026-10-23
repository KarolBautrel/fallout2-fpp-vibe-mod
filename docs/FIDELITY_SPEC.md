# Specyfikacja wierności ISO → FPP

## Cel

Projekt ma zrobić dla Fallouta 2 to, co prototyp Drelvaka robi dla Diablo:
uruchamiać tę samą grę, logikę i świat w nowej perspektywie, zachowując
rozpoznawalny wygląd oryginału. To nie jest remake, remaster ani reinterpretacja
graficzna.

Źródłem wzorcowym jest materiał autora Diablo First Person oraz jego opis:
minimalna geometria odwzorowuje topologię, a oryginalne tekstury gry są
mapowane na jej powierzchnie. Strona projektu:
`https://drelvak.pages.dev/`.

## Niezmienne zasady wizualne

1. `MAP` i `PRO` określają topologię, pozycje, blokady, typ i stan obiektu.
2. `FRM`, paleta i klatki animacji określają wygląd. Piksele źródłowe mają być
   używane bezpośrednio, a nie zastępowane podobnym materiałem.
3. Geometria jest tylko minimalnym nośnikiem tekstury: podłoga, płaszczyzna
   ściany, grubość narożnika, stopnie, cokół, prosty cylinder lub pudełko.
4. Nie tworzymy nowych budynków, ornamentów, kamienia, skrzyń ani dekoracji,
   jeżeli oryginalny asset istnieje. Proceduralna bryła bez źródłowej tekstury
   jest dozwolona wyłącznie jako jawny debugowy blockout.
5. Powierzchnia widoczna w rzucie ISO musi używać projekcji lub UV pochodzących
   z odpowiedniego FRM. Ukryte boki mogą korzystać tylko z powtarzalnego
   fragmentu pobranego z tej samej rodziny assetów Fallouta.
6. Billboard pozostaje właściwym rozwiązaniem dla obiektu, który jest czytelny
   jako sprite: postaci, część skrzyń/mebli, roślinność, ogień i efekty.
   Billboard nie może być stosowany do ściany, pomieszczenia ani całego budynku.
7. Baked shadow nie jest materiałem powierzchni. Jeżeli po zmianie perspektywy
   wygląda błędnie, zastępujemy go neutralnym fragmentem z tej samej rodziny
   źródłowej, nigdy wygenerowaną grafiką.
8. Nie używamy ImageGen ani zewnętrznych assetów do odtwarzania świata gry.
   Narzędzia AI mogą pomagać w kodzie, analizie, UV i automatyzacji.
9. Cała kompozycja izometryczna nie może być użyta jako jedna pionowa fasada.
   Najpierw odzyskujemy nośną topologię z MAP/PRO i technicznych blockerów, a
   następnie przypisujemy osobne regiony FRM do powierzchni o właściwych
   normalnych. Oryginalne piksele bez zmiany perspektywy nie spełniają celu FPP.

## Pipeline rodziny assetów

```text
MAP/PRO + FID/LST + FRM
        ↓
rekord logiczny + źródłowe piksele + offset/pivot
        ↓
klasyfikacja: projected_geometry | directional_billboard | fixed_sprite | decal
        ↓
minimalna geometria i reguła UV/projekcji dla rodziny
        ↓
lokalny bake/cache w artifacts/
        ↓
Godot FPP + porównanie z referencją ISO
```

Reguła jest definiowana dla rodziny/tile-setu i może wymagać ręcznego
dopasowania. Nie zakładamy konwersji całej gry jednym kliknięciem.

## Pierwszy wizualny pionowy wycinek

Pierwszym celem jest ARTEMPLE:

- podłoga z oryginalnych kafli;
- fasada, relief, wieże, wejście i schody świątyni rozpoznawalne jako te same
  elementy `TEMPLE01–TEMPLE08`;
- żadnego proceduralnego „zamku” jako finalnego widoku;
- paleniska i roślinność zachowujące źródłową grafikę;
- przełączenie ISO/FPP bez zmiany stanu świata.

Stan każdej powierzchni i wymagane dowody prowadzi
`docs/ARTEMPLE_SURFACE_LEDGER.md`. Element oznaczony tam jako prototyp albo
nierozwiązany nie może być przedstawiany jako ukończone odwzorowanie.

Dopiero po zaakceptowaniu tej lokacji reguły są przenoszone do ARCAVES.

## Test akceptacyjny

Rodzina assetów przechodzi test dopiero, gdy:

1. lista źródłowych FRM i ich hashe są zapisana w ignorowanym dowodzie;
2. geometria, UV, skala i pivot mają wersjonowaną regułę;
3. render z kalibrowanej kamery ISO jest zestawiony z oryginalną kompozycją;
4. dostępny jest kadr FPP z tego samego miejsca;
5. ornamenty, paleta i sylwetka są rozpoznawalnie tym samym assetem;
6. nie ma z-fightingu, dziur, obracania architektury do kamery ani sztucznie
   wygenerowanych tekstur;
7. wynik został obejrzany w runtime, nie tylko w Blenderze lub na pojedynczym
   PNG.

Technicznie poprawna geometria nie oznacza wierności wizualnej. Ostateczna
akceptacja należy do użytkownika.

## Zatwierdzony toolchain

- `fallout2-ce` — źródło prawdy dla formatu, projekcji, mapy i zachowania;
- `fo2remix scene-source-composite` — odtwarzalna kompozycja źródłowych FRM;
- Godot 4.7 — runtime ISO/FPP i wspólny stan gry;
- Blender 5.1 headless — opcjonalny edytor minimalnej siatki i UV, nigdy
  generator nowego wyglądu;
- REA/Ghidra — wyłącznie gdy zachowania wersji retail nie można rozstrzygnąć ze
  źródeł `fallout2-ce`.

MCP jest środkiem automatyzacji, nie elementem jakości. Dodajemy serwer tylko,
gdy wykonuje potrzebną operację, której nie zapewnia stabilny CLI. Na obecnym
etapie deterministyczne polecenia Godota i Blendera są łatwiejsze do odtworzenia
i audytu niż stałe połączenie z edytorem.
