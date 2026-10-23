# Kierunek wizualny pionowego wycinka

## Rama techniczna

- silnik: Godot 4.7, renderer `gl_compatibility`;
- widok docelowy: perspektywiczne FPP na wysokości oczu oraz kontrolny widok ISO;
- skala: jeden metr świata na odległość między sąsiednimi heksami;
- źródło układu: MAP/PRO/FRM użytkownika, bez kopiowania assetów do repozytorium;
- budżet prototypu: co najmniej 30 FPS, maksymalnie 12 aktywnych świateł lokalnych.

## System wizualny

- kamień świątyni: duże, czytelne bloki, ostre spoiny, matowa powierzchnia;
- naturalna skała: nieregularne, drobniejsze przełamania bez wzoru cegieł;
- sufit wnętrza: ciemne płyty z subtelną, ostrą fugą zamiast gładkiej szarej płaszczyzny;
- ogień: geometryczny płomień emisyjny, bez płaskiej wycinanki i bez migotania światła;
- ruiny i drzewa: niskopoligonowa, kanciasta sylwetka w ziemistej palecie;
- interaktywne drzwi: źródłowa klatka FRM pozostaje do czasu zbudowania rodziny 3D.

## Kryterium akceptacji

Asset jest zaakceptowany dopiero po obejrzeniu w FPP na właściwej mapie. Musi
mieć stabilny pivot, skalę i pozycję wynikającą z profilu rodziny, nie może
z-fightować ani odsłaniać szczelin podczas ruchu kamery. Manifest znajduje się w
`godot/data/procedural_asset_manifest.json`.
