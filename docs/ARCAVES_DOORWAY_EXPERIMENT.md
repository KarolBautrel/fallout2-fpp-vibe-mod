# Wzorzec wejścia ARCAVES

Status: kierunek oceniony przez użytkownika jako wyraźnie lepszy, ale jeszcze
niezaakceptowany. Nie jest regułą dla całej gry.

## Cel

Poprawić wejście do pomieszczenia bez płaskiej fasady, billboardu architektury,
nakładających się pełnych ścian ani wygenerowanych zamienników grafiki Fallouta.

## Wybrany egzemplarz

- mapa: `ARCAVES.MAP`, elevation `0`;
- drzwi: `instance_id = 1338`, heks `24308`, `acavedr4.frm`;
- lewy/prawy koniec portalu: `temple34.frm` na `24305` i `temple33.frm` na
  `24310`;
- źródło prawdy stanu drzwi: MAP/PRO oraz bridge `fallout2-ce`;
- źródło wyglądu: piksele `acavedr4.frm`, `temple33.frm` i `temple03.frm`.

## Odrzucone podejścia

1. Pełne izometryczne `temple33–36.frm` jako pionowe karty: brak prawdziwej
   głębi, rozjazd perspektywy i widoczne przecięcia.
2. Uznanie wszystkich par `temple33–36` za przejścia: para `28700/29500`
   okazała się ornamentem na ciągłym murze `temple09–14`, nie otworem.
3. Szerokość portalu równa odległości kotew FRM: drzwi były nieludzko szerokie.

Odrzucony baseline: `artifacts/rejected-arcaves-flat-arch-cards.png`.

## Kandydat

- otwór ma szerokość `2.0` jednostek i wysokość około `2.2`;
- półkolisty pierścień ma 16 segmentów, rzeczywistą grubość `0.28` i boczne
  ościeża;
- kamienne obramowanie używa prostowanego wycinka `temple33.frm`;
- 19 klatek `acavedr4.frm` jest prostowanych ścinaniem zgodnym z jego osią
  izometryczną i nakładanych na łukową siatkę, nie prostokątną kartę;
- stan `open` nadal zmienia klatkę i wyłącza autorytatywny collider.
- boczne wypełnienia zachodzą `0.5` jednostki na sąsiedni scalony mur, ponieważ
  kotwy portalu i środek następnego heksa zostawiały wcześniej widoczną szczelinę.

Dowody lokalne:

- `artifacts/arcaves-doorway-exemplar-closed.png`;
- `artifacts/arcaves-doorway-exemplar-open.png`;
- `artifacts/arcaves-doorway-exemplar-side-open.png`.

## Bramka dalszej pracy

Użytkownik potwierdził poprawę drzwi, ale zgłosił pozostałe dziury, monotonne
korytarze i brzydkie łuki. Te klasy są rozdzielone i opisane w
`docs/ARCAVES_ARCHITECTURE_EXPERIMENTS.md`. Nowy kadr drzwi po zamknięciu styku
portal–mur nadal oczekuje na werdykt. Brak uwag nie oznacza akceptacji.
