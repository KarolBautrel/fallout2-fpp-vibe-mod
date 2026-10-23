# Skille i narzędzia — przegląd

## Włączone projektowo

Repo zawiera jeden skupiony skill: `.codex/skills/fallout2-fpp-vibe-mod/SKILL.md`. Łączy routing do trzech osobnych referencji, dzięki czemu agent nie ładuje naraz instrukcji parsera, renderera i testów.

## Sprawdzone skille zewnętrzne

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

### RevEng / Ghidra skills

Na tym etapie pomijamy. Są przeznaczone do analizy binariów, a `fallout2-ce` daje nam czytelny kod C++ i jest lepszym źródłem prawdy.

## Zasada doboru

Skill ma zmieniać decyzje lub zapewniać powtarzalny test. Nie instalujemy osobnego skilla wyłącznie dlatego, że jego nazwa pasuje do projektu.

