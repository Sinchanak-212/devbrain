# DevBrain 0.7.2 — aktualizacja i walidacja

Stan raportu: 7 listopada 2026, **aktualizacja wykonana; walidacja zakończona z ograniczeniami środowiska**. DevBrain 0.7.2 został zainstalowany w WSL i zweryfikowany względem finalnej paczki. Potwierdzono rzeczywiste połączenie z GitHub Copilot przez zalogowane konto, wykonanie protokołu pamięci przez model oraz odczyt pliku. Powtarzające się awarie środowiska, także po aktualizacji WSL, uniemożliwiają potwierdzenie pełnej stabilności. Produkcyjne usługi pozostawiono zatrzymane, aby nie kontynuować zapisów do bazy w tym stanie.

Zbiorczy zapis maszynowy: [devbrain-0.7.2-validation.json](devbrain-0.7.2-validation.json), status `updated_with_unresolved_host_instability`.

## Co zostało poprawione

- Logowanie Copilot przekazuje zgodę na lokalne przechowywanie poświadczeń w formacie wymaganym przez runtime: `allow` / `deny`.
- Tryb konta GitHub usuwa z otoczenia uruchamianego runtime ustawienia BYOK i offline, które mogły przejmować routing mimo poprawnego logowania. Nie wymaga podania klucza API.
- Weryfikacja integralności runtime Copilot porównuje zawartość plików; kolizja metadanych czasu i rozmiaru nie omija kontroli.
- Narzędzie `ack_resume` opisuje dokładny kontrakt: wymagane pola `plan` i `task`, każde jako `null` przy braku elementu albo jego dokładne `id` i całkowite `version`. Walidacja ACK pozostała ścisła.
- Ewaluator natywnego Codexa używa obsługiwanego `approval_policy`; test konta nie dziedziczy `CODEX_API_KEY`.
- Błędy zapisu ekstrakcji otrzymują bezpieczny kod przyczyny i etap operacji. Raport nie ujawnia treści wyjątków, źródeł ani sekretów. Błąd późnego zapisu lub zatwierdzenia transakcji nie pozostawia mylącego wyniku `ok`.
- Opcjonalny frontend otrzymał Vite 6.4.5 i Vitest 4.1.12 wraz z aktualizacją zależności.

Formaty danych pozostają bez zmian: schemat bazy 4, profile 2, backup administracyjny 5, przenośna pamięć projektu 1. ArcadeDB jest przypięte do 26.11.1.

## Potwierdzone wyniki

| Obszar | Wynik i granice dowodu | Dowód |
| --- | --- | --- |
| Copilot: konto | Uwierzytelnione konto GitHub, model `auto` dostępny, bez przekazanego klucza API. | [Pierwsza kontrola konta](copilot-live-account-20261107.json) |
| Copilot: wywołanie narzędzia | Rzeczywista odpowiedź usługi i zweryfikowane wywołanie narzędzia. | [Live probe](copilot-live-probe-20261107.json) |
| Copilot: pełny agent | `resume_context → ack_resume → read_file`, 3 wywołania w limicie 8, 17,053 s. ACK zapisany i sprawdzony w osobnej bazie; model odczytał syntetyczny plik i zwrócił znacznik. Projekt pozostał bez zmian, brak operacji wymagających zgody. | [E2E po poprawce](copilot-live-agent-e2e-20261107.json) |
| Copilot po restarcie WSL | Zainstalowane 0.7.2, SDK 1.0.29 / runtime 1.0.107; konto nadal zalogowane, `auto` aktywne, brak poświadczenia API w profilu. Ta kontrola nie wykonywała inferencji. | [Kontrola instalacji](installed-copilot-after-restart-20261107.json) |
| Natywni klienci | 3 rzeczywiste etapy Codex → Claude Code → świeży Codex: odtworzenie planu/zadania, przejście wersji 1 → 2, unieważnienie starego ACK i wznowienie po kompakcji. Osobna baza i syntetyczny projekt. | [Natywne przekazanie pamięci](local-native-20261107T092521Z.json) |
| Kontrakt ACK i integracje | 153 unikalne testy PASS: 152 z głównej próby oraz 1 z powtórzenia na spójnym środowisku 0.7.2. | [Pierwsza próba](devbrain-final-ack-integration-20261107.xml), [powtórzenie workera](devbrain-final-worker-e2e-20261107.xml) |
| Copilot: regresje | 34 testy PASS, w tym zgoda logowania, środowisko i integralność runtime. | [JUnit Copilot](copilot-account-regression-20261107.xml) |
| Ekstrakcja i diagnostyka | 24 testy bezpieczeństwa/groundingu oraz 13 diagnostyki zadań PASS. | [Ekstrakcja](devbrain-local-extraction-20261107T092122Z.xml), [diagnostyka](devbrain-local-job-diagnostics-20261107T092305Z.xml) |
| Frontend | Build, 10 testów jednostkowych i 8 przeglądarkowych PASS; `npm audit`: 6 → 0. Poprzednie podatności dotyczyły zależności deweloperskich. Testy przeglądarkowe używały kontrolowanych API/WebSocket. | [Walidacja frontendu](devbrain-frontend-validation-20261107.json) |
| Guardy aktualizatora | 5 testów PASS dla najnowszego aktualizatora: ochrona obcych procesów, poprawny receipt oraz rozpoznawanie brakujących plików. | [JUnit updatera](updater-guards-final-20261107.xml) |

Pierwszy rzeczywisty E2E Copilot ujawnił niejednoznaczny opis ACK: model zgadywał nazwy pól i nie uzyskał prawa odczytu. [Wynik sprzed poprawki](copilot-live-agent-e2e-20261107-before-fix.json) zachowano. Po uściśleniu schematu i promptu identyczny scenariusz oraz limit narzędzi zakończyły się sukcesem; walidacja nie została osłabiona.

Jedyny nieudany test w pierwszej próbie 153 integracji wynikał z połączenia brokera 0.7.2 i zainstalowanego workera 0.7.1. Worker uruchamia Python z `-I`, więc ignoruje `PYTHONPATH`; kontrola wersji odrzuciła uruchomienie. Powtórzenie na spójnym 0.7.2 przeszło bez zmiany kodu. To jeden przypadek testowy, nie dwa.

## Pokrycie backendu — bez sumowania powtórzeń

Końcowa kolekcja ma **1275 unikalnych przypadków**, w tym 13 nowych regresji. Każdy ma zachowany wynik PASS po deduplikacji `pytest nodeid`, lecz warunki są istotne: **1219 przeszło bez ograniczenia JIT do C1, a 56 wyłącznie w diagnostycznym powtórzeniu z C1**. Na pierwszą liczbę składa się 1149 wcześniejszych przypadków, 57 czystych wyników PASS po aktualizacji WSL i 13 nowych regresji. Jeden przypadek ze statusem PASS podczas wykonania, ale ERROR przy sprzątaniu, został wykluczony z tej pierwszej grupy i poprawnie powtórzony. Podzbiory z tabeli oraz 240 unikalnych testów z dodatkowych przebiegów są już uwzględnione; nie należy ich dodawać ponownie. Jest to liczba przypadków testowych, nie procent pokrycia linii kodu, ani jeden nieprzerwany przebieg całego zestawu.

Zestaw dowodów łączy zamrożoną kopię bazową z regresjami finalnego 0.7.2 i powtórzeniami po aktualizacji WSL; nie oznacza pełnego nieprzerwanego przebiegu na finalnych źródłach. Przebieg przerwany restartem WSL oraz fragmenty bez końcowego JUnit nie są dowodem przejścia całego zestawu. Po aktualizacji WSL powtórzenie 113 pozostałych przypadków także utraciło proces Java. Ostatnie **56/56 przeszło w 309,92 s**, przy `-XX:TieredStopAtLevel=1` wyłącznie dla izolowanego silnika testowego; proces zakończył się kodem 0 i posprzątał własny silnik. Nie ustawiono tej flagi globalnie ani dla produkcji. To wynik diagnostyczny, nie dowód usunięcia przyczyny C2 lub osobnego przerwania Pythona. Źródła: [JUnit C1](devbrain-c1-diagnostic-validation-20261107.xml), [deduplikowane pokrycie](devbrain-test-coverage-20261107.json) i [plan wcześniejszych powtórzeń](devbrain-post-update-retry-plan-20261107.json).

## Instalacja, zachowanie danych i paczki

Instalacja WSL: `/home/piotr/src/devbrain`; polecenie: `/home/piotr/.local/bin/devbrain`; dane: `/home/piotr/.local/share/devbrain`. [Końcowy dowód wdrożenia](devbrain-0.7.2-production-final.json) potwierdza wersję 0.7.2, zgodność **182 plików źródłowych i 64 zainstalowanych plików aplikacji** z finalnym ZIP oraz zachowanie 7 chronionych plików: konfiguracji, preferencji, kluczy API, logowania Copilot, blokady modeli i poświadczeń natywnych klientów. Raport nie zawiera ich wartości.

Backup wdrożenia: `/home/piotr/.local/state/devbrain-updates/20261107T093838Z-bbfafb96`. Aktualizator zachowuje źródła i bazę; kopia nie zastępuje oddzielnego zabezpieczenia poświadczeń. Nie wykonano automatycznego rollbacku ani usuwania pamięci użytkownika.

[Końcowy smoke aktualizacji 0.7.1 → 0.7.2](devbrain-0.7.2-upgrade-smoke.json) **przeszedł dla najnowszego aktualizatora `bf1b…` i ZIP `6b65…`**. Potwierdził migrację z realnym `uv tool`, zachowanie danych i 9 plików chronionych w syntetycznej instalacji, dokładny backup oraz zachowanie bajtów, uprawnień, mtime i inode 215 plików przy ponownym zastosowaniu. Próba działała w izolowanym silniku Java z `-Xmx1g -XX:TieredStopAtLevel=1`, bez powtórzeń, inferencji i dostępu do produkcyjnej bazy. Zakończyła się kodem 0 i zatrzymała własny silnik. To **smoke PASS w warunkach diagnostycznego C1**, nie dowód stabilności domyślnego C2. [Warunki i wykonanie smoke](devbrain-0.7.2-upgrade-smoke-c1.json).

Do wdrożenia produkcyjnego faktycznie użyto wcześniejszego aktualizatora `61c4da4c2fcbbb80abcbc091c4ca83eaaebb34584e28e06e527b8b62a251560e`; nie należy przypisywać mu hasha końcowego. Ostatnia zmiana paczki dotyczyła wyłącznie asercji w `tests/test_native_evaluation.py`; kod aplikacji obu paczek jest identyczny.

Ten jeden plik testowy zsynchronizowano osobno, z kontrolą oczekiwanej zawartości i [własnym backupem](final-native-test-source-sync-20261107.json): `/home/piotr/.local/state/devbrain-updates/20261107T101931Z-final-test-sync`. Operacja nie otwierała bazy, nie zmieniała zainstalowanej aplikacji ani receiptu updatera. Końcowe porównanie źródeł i instalacji z finalnym ZIP przeszło, podobnie jak 5 guardów końcowego updatera.

Aktualne pliki wydania i SHA-256, odczytane 7 listopada:

| Plik | SHA-256 |
| --- | --- |
| `releases/devbrain-update-0.7.2.py` | `bf1bd27200108e8e0da5bbbe42d44e7b3eb2736ae74e2886508c8cc5bb097e67` |
| `releases/devbrain-0.7.2.zip` | `6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c` |

Historyczne paczki 0.7.0/0.7.1 i `START_HERE.txt` pozostają archiwalne. Aktualnym punktem wejścia jest [START_HERE_0.7.2.txt](../START_HERE_0.7.2.txt).

## WSL i stabilność

Potwierdzono kernel panic gościa WSL 7 listopada o 10:18:52 czasu lokalnego. Windows nie został wtedy zrestartowany. Zachowany ślad wskazuje na `idle_cpu` i stos planisty; nie ustalono źródłowej przyczyny. Nie ma podstaw do przypisania jej Ollamie, GPU, niedostatkowi RAM, sprzętowi ani konkretnej wersji WSL. [Diagnostyka zdarzenia](wsl-restart-diagnosis-20261107.md) zachowuje historyczny stan sprzed aktualizacji.

Za zgodą użytkownika wykonano aktualizację i kontrolowany restart: **WSL 3.0.3, działający kernel 6.18.54.1**. [Dowód po restarcie](wsl-after-update-20261107.json) potwierdza także DevBrain 0.7.2.

Aktualizacja nie zamknęła problemu stabilności: późniejszy izolowany test zakończył się `SIGSEGV` OpenJDK 21.0.12.1 w `PhaseIFG::effective_degree`, wątku `C2CompilerThread0`. Identyfikator startu WSL pozostał ten sam; nie był to kolejny restart kernela. Zachowano [raport JVM](arcade-jvm-post-update-fatal-20261107.log). Diagnostyczna flaga `-XX:TieredStopAtLevel=1` dotyczy tylko powtórzenia testów, bez globalnej zmiany konfiguracji.

Oddzielny przebieg regresji ewaluacji/natywnych klientów po aktualizacji przerwał **Python `SIGABRT` (kod -6)** podczas `ssl.create_default_context`; proces Java tej próby nadal działał. Nie był to wynik modelu ani awaria GPU — próba nie wykonywała inferencji. Zakończyła się przed końcowym JUnit, dlatego 27 znaczników postępu nie zostało zaliczonych jako dowód przejścia testów. Zachowano [metadane próby](native-evaluation-post-update-20261107.json) i [log przerwania Pythona](native-evaluation-python-abort-20261107.log). Przyczyna powtarzających się awarii różnych procesów pozostaje nieustalona. Nie zmieniano BIOS ani sterowników.

## Stan pamięci produkcyjnej i granice wykonanej walidacji

Odczyt produkcyjny wykazał 6 historycznych nieudanych zadań: 3 importy `unknown_transcript_schema`, 2 ekstrakcje z timeoutem/błędnym JSON i 1 `persistence_failed`. Nie oznaczono ich automatycznie jako naprawione. Dla starego `persistence_failed` zachowało się 6 zaakceptowanych propozycji i 0 zapisów, lecz pierwotny wyjątek został utracony w dawnej diagnostyce. Regresje odtwarzają możliwe przyczyny i rollback, nie dowodzą przyczyny tego konkretnego zadania. [Odczyt pamięci](production-memory-read-20261107.json) jest migawką, nie bieżącym stanem kolejki.

Końcowy odczyt `doctor`, bez uruchamiania usługi ani bazy, wykazał dostępne: Ollamę, zainstalowane modele `qwen3.5:9b` i `qwen3-embedding:0.6b`, GPU RTX 4080 SUPER (16376 MiB) oraz klientów Codex 0.166.0 i Claude Code 2.1.319 z obsługą zweryfikowanego wznowienia. Usługa DevBrain i ArcadeDB były niedostępne, ponieważ celowo pozostawiono je zatrzymane. Dostępność komponentów nie jest wynikiem ewaluacji modelu. [Końcowy doctor](installed-doctor-final-20261107.json). Również [odczyt workspace](installed-workspace-final-status-20261107.json) zwrócił `available: false`; zapisane stany slotów `running` są stanem historycznym, nie dowodem działających procesów.

Końcowy zakres kontroli:

| ID | Kontrola | Status |
| --- | --- | --- |
| FINAL-BACKEND | Deduplikowane wyniki 1275 przypadków | **1275 z dowodem PASS: 1219 bez C1, 56 wyłącznie z diagnostycznym C1**; stabilność domyślnego środowiska niepotwierdzona |
| FINAL-NATIVE | Końcowe regresje ewaluatora/natywnych klientów po aktualizacji WSL | **PRZERWANE: Python SIGABRT**; wcześniejsze rzeczywiste 3 etapy PASS |
| FINAL-PACKAGE | Końcowa zgodność paczki i instalacji | **PASS: 182 pliki źródłowe, 64 zainstalowane, 7 chronionych**; smoke najnowszego updatera **PASS w izolowanym C1** |
| FINAL-RECALL | Rzeczywista ewaluacja 20 przypadków przez lokalne modele po aktualizacji | **NIEWYKONANA** z powodu powtarzających się awarii środowiska; wcześniejsze przerwanie nie jest wynikiem PASS |
| FINAL-UI | Końcowa kontrola zainstalowanego TUI/grafu | **NIEWYKONANA** z tej samej przyczyny; testy automatyczne nie zastępują tej kontroli |
| FINAL-QUEUE | Powtórzenie 6 historycznych nieudanych zadań | **NIEWYKONANE**; nie deklaruje się ich naprawy |
| FINAL-SERVICES | Produkcyjne usługi po pracach | **ZATRZYMANE**; bez wznowienia zapisów do bazy przy nierozstrzygniętej niestabilności środowiska |

Aktualizacja aplikacji i wymienione scenariusze mają dowody sukcesu. Niewykonane lub przerwane kontrole nie są zaliczone; wznowienie pracy produkcyjnej i dalszej walidacji wymaga osobnego rozwiązania problemu stabilności środowiska.
