# DevBrain kierunki rozwoju i propozycje do omówienia

Stan rozmowy: 8 listopada 2026. Użytkownik chce rozwijać trzy obszary: wiarygodność pamięci, samodzielność agentów i wygodę codziennej pracy. Poniższe pięć nowych propozycji czeka na omówienie zakresu i kolejności. 9 listopada 2026 dopisano propozycje i usterki z oceny projektu w sekcji „Propozycje z oceny projektu”. Zapisanie pomysłu nie oznacza rozpoczęcia implementacji ani przypisania go do konkretnego wydania.

## Wcześniej zapisany pomysł użytkownika

### Konfigurowalny koordynator

Mały koordynator kieruje planowanie, implementację i review do wybranych klientów lub modeli. Ten zamiar jest zapisany w [przekazaniu projektu](../../START_HERE.txt), w sekcji „Co dalej”.

Obecne zarządzanie panelami i pętla własnego agenta API nie realizują przekazywania etapów między różnymi wykonawcami. Koordynator pozostaje funkcją do zbudowania. Jego wartością byłoby wykorzystanie istniejących planów, pamięci i dowodów do prowadzenia całego zadania.

## Wiarygodniejsza pamięć

### MEM01 Skrzynka sprzecznych ustaleń

DevBrain pokazuje dwie potencjalnie sprzeczne decyzje obok siebie, wraz z datami, zakresem i źródłami. Przykład: jedno ustalenie mówi o sesji trwającej 24 godziny, drugie o wygaśnięciu po godzinie. Użytkownik wskazuje, czy nowsza decyzja zastępuje starszą, obie dotyczą różnych przypadków, czy alarm jest nietrafny.

**Już istnieje:** oznaczanie możliwych konfliktów przy zajętym kluczu rekordu, relacja `supersedes` i ocena pojedynczych rekordów. **Nowy zakres:** wykrywanie także podobnych znaczeniowo ustaleń pod różnymi kluczami oraz wspólna lista i historia rozstrzygnięć.

Pierwsza wersja powinna ograniczać się do faktów i decyzji. Sugestia modelu nie zmienia automatycznie obowiązujących ustaleń. Odbiór obejmuje prawdziwą sprzeczność, dwa poprawne zakresy tej samej reguły oraz zachowanie źródeł po rozstrzygnięciu.

Podstawa: [ekstrakcja wiedzy](../src/devbrain/agent.py), [wersjonowanie rekordów](../src/devbrain/store.py), [inspektor](../src/devbrain/inspector.py).

### MEM02 Ustalenia do przeglądu po zmianie kodu

Po zmianie kodu pojawia się krótka lista powiązanych decyzji, opisów dokumentacji i zadań, które warto ponownie sprawdzić. Przykład: zmiana `refresh_token()` wskazuje regułę długości sesji i opis logowania. Każda pozycja wyjaśnia, skąd wynika powiązanie.

**Już istnieje:** snapshoty źródeł, relacje kodu i wiedzy oraz aktualność wyników testów. **Nowy zakres:** trwała lista przeglądu z akcjami „nadal aktualne”, „wymaga aktualizacji” i „nie dotyczy”.

Pierwsza wersja korzysta z bezpośrednich powiązań i pokazuje podgląd przed zastosowaniem zmian. Zależność oznacza potrzebę sprawdzenia, nie dowód błędu. Kolejne skany tej samej zmiany nie powinny powielać zgłoszeń; lista nie zmienia samodzielnie historycznego statusu wykonania zadania.

Podstawa: [graf i wyszukiwanie](../src/devbrain/retrieval.py), [weryfikacja wyników](../src/devbrain/verification.py).

## Większa samodzielność agentów

### AUT01 Osobna kopia robocza dla zadania koordynatora

Koordynator tworzy dla zadania oddzielny Git worktree. Implementacja i review odnoszą się do konkretnej wersji zmian, a wynik wraca jako diff z testami i uwagami. Dzięki temu dwa zadania mogą pracować bez edytowania tych samych plików w jednym katalogu.

**Już istnieje:** wybór zarejestrowanych worktree, plany i dowody przypisane do kodu. **Nowy zakres:** tworzenie i przypisywanie kopii przez koordynatora oraz śledzenie właściciela i etapu zadania. To rozszerzenie wcześniejszego pomysłu koordynatora.

Pierwsza wersja może obsługiwać jedno zadanie i sekwencję implementacja → review. Musi uwzględniać niezacommitowane zmiany oraz po przerwaniu wracać do tego samego zadania bez ponownego wykonywania ukończonych działań. Review musi dotyczyć dokładnie zmian przedstawionych do przyjęcia. Przyjmowanie zmian ręczne czy automatyczne pozostaje decyzją do omówienia. Pełne scalanie rozbieżnych historii pamięci nie jest częścią tej propozycji.

Podstawa: [obecne granice workspace](TERMINAL.md), [plany](../src/devbrain/plans.py), [kontrakt przenośnej pamięci](MEMORY_CONTRACTS.md).

## Łatwiejsza codzienna obsługa

### UX01 Zestawienie wykorzystania modeli w projekcie

Jeden widok pokazuje obserwowane tokeny i szacowane koszty dla projektu, dnia lub tygodnia, z podziałem na model i asystenta. Pomaga ocenić, jak wykorzystano narzędzia podczas konkretnej pracy.

**Już istnieje:** limity tury, zdarzenia użycia i opcjonalne stawki profilu. **Nowy zakres:** podsumowanie wielu sesji, kompletność danych i próg ostrzegawczy projektu.

Brakujące dane pozostają „nieznane”. Koszt szacowany według zapisanych stawek jest oddzielony od faktycznej faktury; nie należy zgadywać pozostałego limitu abonamentu. Agregacja musi unikać podwójnego liczenia narastających raportów tej samej tury. Próg ostrzegawczy nie jest gwarantowanym limitem wydatków.

Podstawa: [konfiguracja limitów i użycia](API.md), [zdarzenia agenta API](../src/devbrain/api_agent.py).

### UX02 Czytanie snapshotu bez uruchamiania usług

Użytkownik otwiera `.memory/devbrain/` i przegląda zapisane plany, decyzje oraz fragmenty źródeł. Może wyszukiwać tekst bez importowania danych do ArcadeDB, uruchamiania Javy czy Ollamy i logowania asystenta. Przydaje się do szybkiego poznania projektu lub odczytu pamięci na słabszym komputerze.

**Już istnieje:** `devbrain memory inspect`, które sprawdza integralność i pokazuje podsumowanie bez uruchamiania usług. **Nowy zakres:** wygodna przeglądarka treści snapshotu, działająca tylko do odczytu.

Pierwsza wersja pokazuje datę snapshotu i pochodzenie informacji. Historyczne wyniki testów nie stają się aktualnymi wynikami lokalnymi. Odbiór powinien potwierdzić odrzucanie uszkodzonych pakietów i brak zapisu danych, uruchamiania usług oraz inferencji podczas przeglądania.

Podstawa: [kontrakt snapshotów](MEMORY_CONTRACTS.md), [polecenie inspect](../src/devbrain/cli.py).

## Propozycje z oceny projektu 8 listopada 2026

Poniższe pomysły powstały podczas wieloagentowej oceny projektu. Trzech niezależnych sędziów oceniło 21 kandydatów; zapisano te, które wszyscy lub większość zachowali. Kolejność w każdej grupie odpowiada ocenie sędziów. Pomysły oznaczone ★ zalecono jako pierwsze.

### Wiarygodniejsza pamięć

#### MEM03 ★ Stan kotwicy dowodowej rekordu

Usunięcie lub zmiana źródła wygasza jego fragmenty, ale rekord `confirmed` i krawędź `supported_by` pozostają. Ustalenie może więc przeżyć zniknięcie jedynego dowodu, a pakiet wznowienia liczy tylko źródła brakujące, nie nieaktualne.

**Nowy zakres:** pochodne pole `evidence_state` o wartościach `anchored`, `evidence_replaced` (z informacją, czy cytat nadal występuje w nowej wersji źródła) i `orphaned`. Pole jest widoczne w inspektorze, w `unknowns` pakietu wznowienia i w poleceniu `devbrain memory orphans`. To prymityw potrzebny przed MEM02.

Podstawa: [dezaktywacja źródeł](../src/devbrain/ingest.py), [rekordy i krawędzie](../src/devbrain/store.py), [pakiet wznowienia](../src/devbrain/sessions.py).

#### MEM04 ★ Czas dowodu zamiast czasu zapisu

`created_at` oznacza chwilę zapisu do bazy. Transkrypt z marca zaimportowany dziś dostaje dzisiejszą datę, a `source_timestamp` leży nieużyty w metadanych. MEM01 rozstrzygałby wtedy sprzeczności według kolejności importu.

**Nowy zakres:** `evidence_time` jako przedział wyznaczony z `source_timestamp` źródeł albo daty commitu dla kodu i dokumentów, z jawnym `unknown`. Ostrzeżenie `anachronistic_supersede`, gdy starszy dowód zastępuje nowszy. Hash snapshotu i kolejność pakietu się nie zmieniają.

Podstawa: [import transkryptów](../src/devbrain/ingest.py), [zapis rekordów](../src/devbrain/store.py).

#### MEM05 Ważenie trafień statusem rekordu

`search()` odrzuca tylko `superseded`, a fuzja RRF nie ma wag, więc rekord `disputed` waży tyle co `confirmed`. `context()` już degraduje niepotwierdzone wpisy, więc oba widoki są niespójne, a `dispute` w inspektorze nie wpływa na odpowiedzi `ask`.

**Nowy zakres:** mnożnik statusu, np. 1.0 / 0.7 / 0.25, a po MEM03 także stanu dowodu. Test: `disputed` nie wyprzedza `confirmed` przy równym rankingu.

Podstawa: [wyszukiwanie](../src/devbrain/retrieval.py).

#### MEM06 Dziennik odpowiedzi `ask` i replay regresji

Odpowiedź `/ask` żyje 60 s w pamięci podręcznej usługi. Rodzaj `agent_answer` jest zarezerwowany, ale nigdy nie tworzony. Bez zapisu odpowiedzi strojenie wyszukiwania odbywa się na ślepo.

**Nowy zakres:** opcjonalny zapis odpowiedzi z cytatami (`source_id`, `sha256`, cytat), wyłączony z indeksu i ze snapshotu. Później `eval replay` porównujący zbiór dowodów, nie tekst odpowiedzi. Zapisana odpowiedź nigdy nie staje się dowodem.

Podstawa: [usługa](../src/devbrain/service.py), [agent wiedzy](../src/devbrain/agent.py), [ewaluacja](../src/devbrain/evaluation.py).

### Większa samodzielność agentów

#### AUT02 Dryf zakresu zadania

Manifest drzewa jest liczony przy każdym sprawdzeniu, ale nic nie porównuje go z zakresem, którego zadanie miało dotyczyć.

**Nowy zakres:** opcjonalne `metadata.scope` kroku planu jako wzorce plików, zapis manifestu przy przejściu do `in_progress` i odczyt `scope_drift` zwracający pliki poza zakresem. Ostrzeżenie w `next_task` i `check_status`, nigdy blokada. Działa dla każdego klienta, bo patrzy na drzewo, nie na rozmowę.

Podstawa: [weryfikacja](../src/devbrain/verification.py), [plany](../src/devbrain/plans.py).

#### AUT03 Sesja zewnętrzna: MCP dla Cursor, Cline i Zed

Każdy zapis przez MCP wymaga `DEVBRAIN_SESSION_ID` nadanego przez launcher, a launcher zna tylko Codexa i Claude'a. Pamięć nie jest więc dostępna z innych edytorów.

**Nowy zakres:** `devbrain mcp --client external` sam przygotowuje sesję i pakiet bez archiwum rozmowy, oznaczony jawnie jako `history: unarchived`. Bramka ACK pozostaje ta sama. Kontrakt musi opisać ten tryb jako dowodowo zdegradowany.

Podstawa: [serwer MCP](../src/devbrain/mcp_server.py), [integracje klientów](../src/devbrain/integrations.py), [sesje](../src/devbrain/sessions.py).

#### AUT04 Plan jako kontrakt: kryteria akceptacji powiązane ze sprawdzeniami

`acceptance_criteria` to lista tekstów, a `required_profiles` człowiek wpisuje osobno. Nic nie wiąże kryterium z konkretnym sprawdzeniem.

**Nowy zakres:** kryterium jako `{text, check}` oraz `devbrain plan contract --write`, które proponuje profile `checks.toml` i pokazuje diff przed zapisem. `check_status` rozróżnia kryteria sprawdzane maszynowo i czekające na ręczną ocenę. Polecenie zaproponowane przez model nigdy nie jest wykonywane bez jawnego zatwierdzenia diffu.

Podstawa: [plany](../src/devbrain/plans.py), [weryfikacja](../src/devbrain/verification.py).

### Łatwiejsza codzienna obsługa

#### UX03 ★ `devbrain brief`: gdzie skończyłem, bez modelu

`devbrain context` zwraca JSON przeznaczony dla modelu. Człowiek na początku dnia sam składa obraz z kilku poleceń.

**Nowy zakres:** do 40 linii tekstu: ostatni checkpoint z wiekiem, następne zadanie i blokady, stan weryfikacji zadań w toku, commity od checkpointu i rekordy `proposed`. Każda linia oznacza, czy pochodzi z deklaracji (`reported`), czy z pomiaru (`machine`). Wpis „Brief” w palecie poleceń. Bez inferencji.

Podstawa: [kontekst](../src/devbrain/retrieval.py), [checkpointy](../src/devbrain/store.py), [weryfikacja](../src/devbrain/verification.py).

#### UX04 `Ctrl+B n`: szybkie ustalenie z panelu

`remember` z CLI tworzy źródło `manual://` bez kontekstu, a zapis przez model zależy od ACK i jego inicjatywy.

**Nowy zakres:** skrót tmux otwiera formularz z treścią, rodzajem i statusem, który zapisuje ustalenie bez wychodzenia z workspace. Pierwsza wersja nie dołącza zrzutu panelu, bo redakcja sekretów zna tylko zarejestrowane klucze, a nie klucz wklejony w rozmowie.

Podstawa: [skróty workspace](../src/devbrain/workspace.py), [CLI](../src/devbrain/cli.py).

### Usterki wykryte podczas oceny

Te punkty to poprawki istniejącego zachowania, nie nowe funkcje.

- **FIX01 Powiązania ustaleń z kodem nie powstają.** Ekstrakcja szuka węzłów rodzaju `file`, `module`, `function`, `class`, `test`, a parser tworzy `file`, `symbol`, `external_module` i `unresolved_reference`. Powiązania z symbolami nigdy nie zachodzą, co osłabia MEM02. Poprawka: lista `['file', 'symbol']` z testem. [agent.py](../src/devbrain/agent.py), [ingest.py](../src/devbrain/ingest.py).
- **FIX02 Cytat może mieć jeden znak.** Schemat odpowiedzi `ask` dopuszcza `minLength: 1`, a jedynym sprawdzeniem jest obecność cytatu w źródle. Poprawka: minimalna długość cytatu i pole `coverage` mówiące, jaka część odpowiedzi jest pokryta cytatami.
- **FIX03 `ask` nie ma wejścia w terminalu.** Paleta poleceń nie zawiera zapytania do pamięci; jedyny formularz jest w nieużywanym `tui.py`. Poprawka: „Ask memory” w palecie i inspektorze przez istniejące `POST /ask`.
- **FIX04 Kruche sondy klientów.** Możliwości Codexa i Claude'a są wykrywane regexami po `--help`. Poprawka: złote fixture'y wyjść per wersja klienta i `doctor --contract`; nieznany techniczny rekord transkryptu archiwizowany bez blokowania gotowości.

### Kierunki bez konkretnej propozycji

Sędziowie wskazali obszary, których nie pokrył żaden pomysł:

- **Odejmowanie.** Żadna propozycja niczego nie usuwa. Kandydaci: `tui.py`, archiwalny kokpit `frontend/` i `web_static`, graf 3D jako stały panel.
- **Scalanie pamięci z dwóch komputerów.** Snapshot i import działają w jedną stronę; bez scalania rekordów to kopia, nie synchronizacja.
- **Wrażliwość źródeł.** Jedno pole `sensitivity` respektowane przez eksport, `ask` i API zamiast osobnych mechanizmów w każdej funkcji.
- **Retencja.** Stare rekordy `proposed` wypychają nowe ustalenia z budżetu kontekstu; brak pomiaru rozmiaru bazy.
- **Prompt injection ze źródeł.** Agent z `run_command` czyta cudze README i transkrypty; brak scenariusza adwersarialnego w `eval`.
- **Wersja ekstraktora.** Rekordy `proposed` nie niosą wersji promptu ani modelu, więc nie da się ich wyekstrahować ponownie.
- **Tania metryka jakości.** Odsetek `proposed → confirmed` wobec `disputed` z historii rewizji odpowiada, czy lokalny model się opłaca, bez dodatkowej inferencji.
- **Benchmark z pamięcią i bez.** Nie wiadomo jeszcze, czy ACK i pakiet wznowienia przyspieszają pracę, czy ją spowalniają.

### Odrzucone w ocenie

- Krzyżowa weryfikacja ekstrakcji drugim modelem jako „potwierdzenie”: łamie zasadę, że odpowiedź modelu nie staje się niezależnym dowodem.
- Tryb nocny z lokalnym modelem: większość jego wniosków daje się wyliczyć deterministycznie przez MEM03 i UX03.
- Lekki tryb na SQLite: wymagałby przebudowy warstwy danych wbrew kontraktowi jednego silnika.
- Rozszerzenie VS Code: drugi stos UI do utrzymania przez jedną osobę; AUT03 osiąga podobny cel taniej.

### Rekomendacja oceny co do kolejności

Ocena zaleca najpierw higienę repozytorium i zamknięcie 0.8.0 jedną bramką: pełny przebieg testów w CI, wykonany pilot i 20 przypadków `eval` na lokalnym modelu. Następnie tanie plasterki: UX02 jako `devbrain memory show`, UX03, MEM04, MEM05 i FIX01–FIX02. Potem MEM03 i MEM01 ograniczone do strony konfliktów z już zapisywanych `possible_conflicts`.

Dla wcześniejszych propozycji ocena sugeruje kolejność UX02 → MEM01 → UX01 → koordynator → MEM02 → AUT01. Koordynatora warto zawęzić do routera etapów: mapa etap → asystent i jedna akcja „uruchom następny etap”, bez automatycznych przejść stanów. AUT01 oceniono najniżej, bo tworzenie worktree łamie zasadę, że DevBrain nie wykonuje operacji Git. To rekomendacje, nie decyzje.

## Decyzje do wspólnego ustalenia

- Która propozycja daje największą korzyść w codziennej pracy użytkownika?
- Czy pierwsza wersja koordynatora kończy zadanie na przedstawieniu zmian do akceptacji, czy ma je także przyjmować automatycznie według ustalonych reguł?
- Który jeden scenariusz będzie kryterium ukończenia każdej wybranej funkcji?

Obecna stabilizacja wydania i kwalifikacja aktualizacji mają własne raporty. Ta lista nie zmienia ich statusu.
