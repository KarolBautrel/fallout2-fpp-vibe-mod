# Renderer and cameras

## Reguła po teście ARCAVES

Niewidocznego `block.frm` nie zamieniaj automatycznie na ścianę. Może utworzyć
krótki nośnik wyłącznie wtedy, gdy dwa widoczne rekordy MAP potwierdzają tę samą
oś po przeciwnych stronach markera; skrzyżowania i przypadki jednostronne
pozostają niewidoczne. Dla wolnostojącego obiektu wybierz regułę rodzinną, nie
regułę per egzemplarz. Zwarty pojemnik z jednym użytecznym rzutem (np. skrzynia)
może być billboardem Y, jeżeli ma osobny, nieruchomy collider. Długi mebel lub
obiekt, którego głębokość zmienia przechodniość, zwykle wymaga minimalnej bryły z
powierzchniami z właściwego FRM. Wyjątek potwierdzony w ARCAVES: `TEMPSF04/05`
mają już blokowanie z MAP/PRO, a source-solid z pełnym izometrycznym FRM tworzył
skrzyżowane powierzchnie. Dla tej rodziny używaj billboardu Y i zachowaj istniejącą
kolizję logiczną. Pełny izometryczny sprite architektury na pionowej karcie nadal
nie jest akceptowalną bryłą.

Po scaleniu prostych odcinków wykonaj osobny audyt końcówek. Dopuszczalny
łącznik narożny jest krótkim przedłużeniem osi istniejącej ściany do
prostopadłego nośnika potwierdzonego sąsiedztwem MAP. Musi zachować grubość,
materiał i fazę UV ściany. Nie używaj uniwersalnych kostek/słupów i nie łącz
równoległych ścian tylko dlatego, że są blisko w przestrzeni.

Nie buduj prostych przebiegów flood-fillem po wszystkich sąsiadach tej samej
klasy osi. W heksowym zapisie Fallouta równoległe przebiegi mogą współdzielić
kotwicę narożną; flood-fill scali je i narysuje ścianę przez uśredniony środek.
Grupuj krawędzie grafu według normalnej współrzędnej ich środka, a dopiero potem
wyznaczaj spójne komponenty lane. Audyt musi raportować zero komponentów o
rozrzucie normalnym większym niż 0.51.

## First renderer

Use Godot only as a replaceable visualization client. It reads `scene-v1.json`; it does not own Fallout rules in the first milestone.

Generate simple primitives:

- floor/hex: flat mesh with a debug label or color;
- wall: extruded box along the logical edge;
- door/scenery: colored placeholder with object ID;
- critter: billboard initially, capsule for collision/debug;
- player: distinct ISO placeholder and visible forward vector; hide the head/body geometry that would obstruct the FPP camera.

Do not manufacture detailed geometry from the prerendered background until the logical layout passes validation.

## Fidelity contract after logical validation

Follow `docs/FIDELITY_SPEC.md`. The production renderer uses the smallest geometry
that can carry the original Fallout pixels. MAP/PRO owns topology and state; FRM
owns visible identity, palette, ornament and animation. A hand-authored or
procedural proxy without source-derived texture is debug-only and cannot satisfy
visual acceptance.

For each asset family choose one explicit rule: projected geometry, directional
billboard, fixed sprite or ground decal. Hidden faces may only use a crop or tile
derived from the same Fallout art family. Never use generated replacement art.
Retain a matched ISO reference, an FPP capture and the local source hashes as
evidence before promoting a family beyond blockout.

### Bramka rekonstrukcji architektury

Nie wnioskuj o otworze, drzwiach ani ciągłości ściany wyłącznie z nazwy lub
sylwetki FRM. Najpierw potwierdź topologię przez MAP/PRO, sąsiednie rekordy,
blokady oraz obiekt drzwi. Zbuduj jeden egzemplarz i zachowaj kadry z przodu,
stanu alternatywnego (np. otwarte drzwi) oraz z boku pokazującego grubość.
Pełnego izometrycznego sprite'a architektury nie nakładaj na prostokątną kartę.
Jeżeli potrzebuje nośnika 3D, prostuj tylko właściwe powierzchnie źródłowe.
Nie rozszerzaj metody na rodzinę przed akceptacją egzemplarza i sprawdzeniem
drugiego zgodnego przypadku.

## Camera contract

Maintain one authoritative player transform. Cameras observe it; they never each own a separate copy.

- ISO: orthographic, configurable pitch/yaw/zoom, mouse selection through a ground/hex query.
- FPP: perspective camera located at character eye height, with yaw/pitch look and no trailing boom or over-the-shoulder offset.
- Switch: changes active camera and input map only; it must not rewrite player position, selected object or current elevation.

In FPP, cast interaction rays from the center of the camera. Calibrate camera and
sprites against a human FRM, not an arbitrary prop: `nmwarraa` is 63-66 px, so
36 px/m yields about 1.75-1.83 m. The current prototype uses a 1.62 m eye height
and 65 degree vertical FOV. Keep collision radius explicit and validate apparent
scale in motion as well as in a still capture.

Keep input actions semantic (`move`, `interact`, `toggle_camera`) so later integration can translate them to `fallout2-ce` commands.

## Integration decision

After the slice works, compare:

- external Godot client fed by a state bridge;
- Godot used only as a prototyping tool, followed by a native renderer inside `fallout2-ce`;
- manual per-map 3D metadata layered over automatic logical geometry.

Choose based on measured fidelity and synchronization cost, not visual preference alone.

