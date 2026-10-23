# Skille i narzędzia — przegląd

## Włączone projektowo

Repo zawiera jeden skupiony skill: `.codex/skills/fallout2-fpp-vibe-mod/SKILL.md`. Łączy routing do trzech osobnych referencji, dzięki czemu agent nie ładuje naraz instrukcji parsera, renderera i testów.

## Sprawdzone skille zewnętrzne

### AI3D Transparent Billboard Asset

Repo: `https://github.com/kaojunn/ai3d-codex-skills`

Skill `ai3d-transparent-billboard-asset` jest zainstalowany w użytkownikowym
katalogu Codexa. W projekcie wykorzystujemy jego tryb Local Image Only: audyt
kanału alfa, białych obwódek, kadrowania i bottom-center pivotu. Część Unity nie
jest używana; odpowiednikiem prefabu jest rodzinny renderer Godot opisany w
`BILLBOARDS.md`. Upstream nie publikuje jawnego pliku licencji, dlatego skryptów
skilla nie vendoryzujemy do repo.

### Universal Modder

Repo: `https://github.com/rehan-remade/universal-modder`

Przydatne moduły:

- `game-recon` — inwentaryzacja instalacji i wybór najlżejszej ścieżki;
- `mashup-mods` — kontrakty między silnikiem/symulacją a rendererem;
- `reverse-engineering` — formaty danych, dowody i round-trip;
- `asset-pipeline` — dopiero później, gdy powstaną modele lub trzeba będzie obrabiać sprite'y.

Nie kopiujemy całego pakietu do projektu: jest szeroki, wymaga dodatkowego CLI/Pythona i wniósłby dużo nieużywanych instrukcji. Zasady potrzebne temu projektowi zostały zapisane w lokalnym skillu i podlinkowanych źródłach.

### Godot best practices

Repo: `https://github.com/jwynia/agent-skills/tree/main/skills/tech/game-development/godot/godot-best-practices`

Przydatny przy właściwym prototypie Godot. Nie instalujemy go przed utworzeniem projektu Godot, ponieważ nie pomaga w analizie danych Fallouta i nie obejmuje C++/GDExtension.

### Level Design

Repo: `https://github.com/gamedev-skills/awesome-gamedev-agent-skills`

Zainstalowany jako użytkownikowy skill `level-design`. Wymusza właściwą kolejność
dla tej fazy: najpierw czytelny blockout z bryłami, wysokościami i przejściami,
potem test poruszania i dopiero na końcu dressing. Nie konwertuje FRM do 3D, ale
pomaga nie mylić płaskiej dekoracji z geometrią poziomu.

### Godot Game Development

Repo: `https://github.com/setcodes/gamedev-skills`

Zainstalowany jako użytkownikowy skill `godot-gamedev`. Uzupełnia lokalne skille
Godota o workflow implementacji i testowania scen.

### Blender Game Assets

Repo: `https://github.com/setcodes/gamedev-skills`

Zainstalowany jako użytkownikowy skill `blender-game-assets` na licencji MIT.
Oficjalny przenośny Blender `5.1.2` znajduje się w ignorowanym
`artifacts/tools/`; SHA-256 archiwum:
`345bedea7b0acf7cc9666423d8553f9129622aea34ded65c23e8cb70f83f14ff`.
Pełny headless self-test skilla przechodzi (`SELFTEST OK`: GLB, UV, bake i cztery
rendery). W tym projekcie Blender służy wyłącznie do minimalnej siatki, UV i
porównań wielu widoków. Nie generuje zamienników grafiki Fallouta.

### Game Development Rendering

Repo: `https://github.com/jdavidkimj/game-development-rendering-skill`

Zainstalowany jako użytkownikowy skill `game-development-rendering` na licencji
MIT. Wprowadza obowiązkowy przegląd wielu ujęć i rozdziela wierność wyglądu od
poprawności technicznej assetu. To bezpośrednio wspiera test pary ISO/FPP.

### MCP

Sprawdzono `Coding-Solo/godot-mcp` i `hi-godot/godot-ai`. Oba skupiają się na
sterowaniu edytorem, uruchamianiu scen i inspekcji węzłów; nie rozwiązują
segmentacji izometrycznego FRM ani mapowania UV lepiej niż obecny CLI i probe'y,
więc nie dodano zbędnej zależności. Skill Blendera zawiera most stdio MCP, ale
połączenie live wymaga dodatku Blender Lab po stronie aplikacji. Do czasu
zweryfikowania jego źródła i instalacji używamy odtwarzalnego `blender -b`.

### Przegląd Ziva: Godot AI skills (2026-10-23)

Źródło: `https://ziva.sh/blogs/godot-ai-skills` oraz podlinkowane repozytoria.

Wniosek dla tego projektu:

- pakiet `awesome-gamedev-agent-skills` jest już zainstalowany selektywnie i
  pokrywa używane obecnie obszary: Godot 3D, GDScript, sceny/węzły, fizykę,
  shadery, sygnały i testy headless;
- nie instalujemy całych pakietów `gd-agentic-skills` (99 pozycji),
  `GodotPrompter` ani `vl4dt/godot-skills`, ponieważ ich ogólne wzorce dublują
  istniejące skille i nie rozwiązują rekonstrukcji topologii Fallouta;
- najbardziej przydatnym uzupełnieniem jest `haxqer/godot-skill`, ale tylko jego
  workflow diagnostyczny: `check_project`, `spatial_report`, scenariusze ze
  screenshotami i `smoke_scenes`. Może automatyzować wykrywanie kamery poza
  sceną, obiektów wbitych w podłogę i regresji wielu scen. Przed instalacją
  należy przejrzeć skrypty i włączyć go jako jedno narzędzie, nie kolejny pełny
  pakiet wzorców;
- `gd-agentic-skills/godot-3d-world-building` nie wnosi obecnie przewagi:
  opisuje głównie GridMap/CSG/WorldEnvironment, podczas gdy nasza geometria
  musi wynikać z MAP/PRO i oryginalnych FRM;
- skill nie daje agentowi dostępu do żywego drzewa sceny. Artykuł słusznie
  rozdziela wiedzę (skill) od dostępu (MCP). Ewentualny następny zakup techniczny
  to audytowalny, live-editor MCP, ale nie należy dodawać go w środku bieżącego
  eksperymentu architektury.

Kandydat MCP do osobnej próby: MIT-licencjonowany live bridge `tomyud1`, bo
udostępnia `run_scene`, `get_errors` i undo. Alternatywa `Coding-Solo` działa
przez CLI i pliki, co w dużej mierze dubluje nasze obecne probe'y. Ziva jako MCP
ma dostęp do drzewa sceny i uruchomionego projektu, ale jest zamkniętym buildem;
instalacja wymaga osobnej decyzji użytkownika i przeglądu uprawnień.

### RevEng / Ghidra skills

Na tym etapie pomijamy. Są przeznaczone do analizy binariów, a `fallout2-ce` daje nam czytelny kod C++ i jest lepszym źródłem prawdy.

## Zasada doboru

Skill ma zmieniać decyzje lub zapewniać powtarzalny test. Nie instalujemy osobnego skilla wyłącznie dlatego, że jego nazwa pasuje do projektu.

