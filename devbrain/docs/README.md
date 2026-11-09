# DevBrain — instalacja i codzienna praca

## Kandydat aktualizacji 0.7.2 do 0.8.0

Pakiety w `releases/candidates/0.8.0/` są kandydatami do walidacji. Samo ich zbudowanie nie oznacza zaliczenia kwalifikacji środowiska, pełnego zestawu testów, wdrożenia ani próby 8 h. Aktualny status sprawdź w raportach `evidence`; wcześniejsze wyniki 0.7.2 nie zastępują testów 0.8.0. Dotychczasowy kandydat jest nieaktualny względem przygotowywanych źródeł. Stan po zmianie BIOS-u wykonanej przez użytkownika jest osobno zapisany w dowodach `080-postbios-*`; aktualizator nie zmienia firmware ani nie restartuje Windows.

Aktualizator obsługuje źródła **0.7.2** zgodne z archiwalnym ZIP-em. Przed jakąkolwiek instalacją można sprawdzić same pliki:

```bash
python3 /sciezka/do/releases/candidates/0.8.0/devbrain-update-0.8.0.py \
  --source-dir ~/src/devbrain --check-only
```

`--check-only` sprawdza wyłącznie pliki, także gdy podano argumenty interpreterów. Nie uruchamia podprocesów, usług ani połączenia z bazą i nie tworzy kopii. Samo zaliczenie tego sprawdzenia nie potwierdza stabilności środowiska.

Po osobnym zaliczeniu wymaganych testów i decyzji o wdrożeniu można wykonać tę samą aktualizację bez `--check-only`, podając uzgodniony interpreter:

```bash
/dokladna/sciezka/do/sprawdzonego/python3.13 /sciezka/do/devbrain-update-0.8.0.py \
  --source-dir ~/src/devbrain \
  --python /dokladna/sciezka/do/sprawdzonego/python3.13 \
  --backup-python /osobny/katalog/backup-072-venv/bin/python \
  --runtime-gate /sciezka/do/zaliczonego/gate.json \
  --data-dir ~/.local/share/devbrain
```

To przykład sposobu użycia, a nie potwierdzenie gotowości obecnego kandydata. Wykonanie wymaga wszystkich czterech argumentów: `--python`, `--backup-python`, `--runtime-gate`, `--data-dir`. Brak zaliczonej kwalifikacji zatrzymuje operację przed odczytem konfiguracji danych i przed poleceniami status/stop/backup. Pełny zestaw testów i wymagany czas obserwacji pozostają odrębnymi warunkami decyzji o wydaniu.

`--backup-python` wskazuje literalny launcher osobnego venv z nieedytowalnym wheelem **0.7.2**, zbudowanym z niezmienionego archiwalnego ZIP-a o przypiętym SHA. Ten venv musi znajdować się poza aktualizowanymi źródłami i katalogiem danych. Aktualizator porównuje bazowy Python i jego SHA z kwalifikacją, sprawdza wersję pakietu, pochodzenie wewnątrz venv, pełny manifest plików pakietu z ZIP-a oraz wersje zależności z jego `uv.lock`. Kontrola `-I` nie otrzymuje katalogu danych. Dopiero po jej zaliczeniu wszystkie dotychczasowe polecenia status/stop/backup wykonuje ten interpreter z jawnym `--data-dir`; stary skrypt `devbrain` z systemowego środowiska nie jest uruchamiany.

Archiwalny silnik 0.7.2 wybiera Javę przez `shutil.which("java")`, bez nowego pola `java_executable`. Dlatego updater i każda komenda smoke dostają własny `PATH` zaczynający się katalogiem `gate.java_executable`, zgodny `JAVA_HOME` i usunięte `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS`, `_JAVA_OPTIONS`. Bez uruchamiania Javy sprawdzane są rzeczywiście odnaleziony plik i jego SHA; inny JDK blokuje polecenie. Nie zmienia to globalnego profilu powłoki. To kontrola wyboru nowego procesu; tożsamość już działającego, współdzielonego silnika jest osobnym warunkiem przygotowania środowiska testowego.

Po kwalifikacji operator może przygotować taki venv przez `uv venv --python <qualified-base> <backup-venv>`, eksport ograniczeń `uv export --directory <immutable-072-source> --locked --no-dev --no-emit-project --format requirements-txt --output-file <constraints>` oraz `uv pip install --python <backup-venv>/bin/python --constraints <constraints> <immutable-072-source>`. Instalacja nie może używać `--editable`; nie należy dodawać nieprzypiętych zależności. Venv pozostaje niezależny od środowiska `uv tool`, które aktualizacja zastępuje.

Aktualizator odmawia nadpisania lokalnych zmian, zatrzymuje hosty interfejsu i usługę wiedzy oraz zapisuje zmieniane źródła i bazę w `~/.local/state/devbrain-updates/`. Sprawdza format, sumę danych i prywatne uprawnienia kopii przed zmianą źródeł. `backup-runtime.json` zapisuje użyty interpreter, pochodzenie pakietu i kwalifikację. Poświadczenia, modele, profile i natywne uprawnienia klientów pozostają poza zakresem aktualizowanych plików; kopia bazy nie zastępuje ich osobnej ochrony. Nie ma automatycznego rollbacku po nieudanej instalacji. Archiwalne paczki 0.7.1 i 0.7.2 pozostają niezmienione.

`--python` jest przekazywane instalatorowi jako `DEVBRAIN_INSTALL_PYTHON`, a jawny katalog danych jako `DEVBRAIN_HOME`. Kwalifikowane Java i tmux trafiają również na początek `PATH`. Potwierdzenie instalacji v2 wiąże payload, katalog danych, oba interpretery i kwalifikację. Identyczne ponowienie sprawdza nowy pakiet w środowisku `uv tool` bez uruchamiania starego skryptu konsolowego i nie powtarza instalacji. Stare potwierdzenie v1 nie wystarcza do pominięcia nowej walidacji. Przy ręcznym użyciu `scripts/install-wsl.sh` można ustawić `DEVBRAIN_INSTALL_PYTHON`; bez tej zmiennej instalator nadal wybiera Python 3.12.

### Walidacja kandydata przez dewelopera

`release-tools/build-devbrain-update-080.py` domyślnie zapisuje tylko `releases/candidates/0.8.0/`; `--output-dir` pozwala wybrać inny podkatalog `releases/candidates/`. Weryfikuje archiwalny ZIP 0.7.2, zgodność wersji i lockfile oraz niezmienność źródeł podczas budowy. Manifest zawiera hashe źródeł, ZIP-a i aktualizatora oraz oznaczenie `candidate`, `qualified: false`.

Test `release-tools/test_devbrain_update080_smoke.py` przyjmuje `--release-dir`, `--root`, `--shared-engine`, `--artifact-root`, `--run-id` oraz dokładne ścieżki `--python`, `--java`, `--tmux` zgodne z zaliczoną kwalifikacją. `--wsl-crash-dir` wskazuje katalog metadanych awarii WSL. Bez `--execute` nie uruchamia pracy; wykonanie wymaga znacznika tego samego zewnętrznego nadzorcy. Test sprawdza sumy przed uruchomieniem, używa odizolowanych katalogów domu, narzędzi i danych oraz unikalnej bazy na silniku należącym do wywołującego. Nie generuje odpowiedzi modeli ani nie korzysta z produkcyjnej bazy.

Bazowy instalator 0.7.2 zawiera na stałe `uv tool install --python 3.12`. Test uruchamia jego niezmienioną kopię, a prywatny pomocnik `bin/uv` zamienia wyłącznie ten selektor na jawnie wybrany interpreter, np. sprawdzony Python 3.13. Pozostałe wywołania są przekazywane do prawdziwego `uv`. Pomocnik jest usuwany przed wykonaniem aktualizatora 0.8.0; aktualizator jest wtedy sprawdzany bez tej podmiany, przez własne `--python`. Raport rejestruje ten zakres testu oraz rzeczywisty `sys._base_executable` obu instalacji. Nie należy opisywać tego wyniku jako instalacji starego 0.7.2 na jego domyślnym Pythonie.

Smoke osobno buduje wheel/venv 0.7.2 do backupu, podmienia dawny skrypt konsolowy na wykrywacz niepożądanego wywołania i wykonuje prawdziwy backup przez aktualizator. Następnie prawdziwe CLI 0.7.2 odtwarza kopię do drugiej, własnej bazy; jej eksport musi odpowiadać kopii, a 0.8.0 musi odczytać te same dane. Test porównuje bajty i uprawnienia kont, profili, modeli i preferencji oraz usuwa obie własne bazy. Ten scenariusz jest przygotowany; dopóki nie powstanie rzeczywisty raport z zewnętrznego nadzorcy, nie jest wynikiem PASS.

Obserwator obejmuje cały test i co najmniej 30 sekund po sprzątaniu (`--cleanup-grace`). Nowy dump, sygnał krytyczny jądra, zmiana boot ID albo niedostępna obserwacja blokują PASS, również przy zerowym kodzie wyjścia poleceń. Timeout i sprzątanie sygnalizują tylko procesy z unikalnym znacznikiem testu i polecenia, przez stabilne uchwyty `pidfd`; odczyt właściciela jest związany z tożsamością procesu przed i po sprawdzeniu znacznika. Nie wysyłają sygnałów do samego numerycznego PID/PGID. Sprzątanie sprawdza odłączone procesy i próbuje usunąć własną bazę po częściowo nieudanej instalacji lub zapisie danych. Nie usuwa baz o innym prefiksie i nie zatrzymuje silnika wywołującego.

Raport wewnętrzny nie może potwierdzić pomyślnej finalizacji własnego interpretera po zapisaniu JSON. Po lokalnych sprawdzeniach i sprzątaniu smoke zapisuje `status: upgrade_smoke_completed_pending_attestation`, `external_controller_finalization_required: true` i `controller_exit_verified: false`. Ten stan nie jest pełnym zaliczeniem aktualizacji.

Przygotowane `release-tools/run-supervised-080.ps1` i `supervise-080.py` zapewniają dwa poziomy obserwacji. Windows wymaga istniejącego `gate.json` ze statusem dokładnie `pass`, zgodnych plików Python/Java/tmux i wszystkich zaliczonych kontroli; obecny zablokowany gate uniemożliwia start. Skrypt wymaga PowerShell 7.2+, jawnego `-Execute`, pary odpowiadających sobie katalogów `-ArtifactRoot C:\...` i `-LinuxArtifactRoot /mnt/c/...`, dokładnego `-PythonExecutable`, `-Controller`, `-ControllerArgumentsFile`, `-RunId` oraz `-TimeoutSeconds`. Bez `-Execute` nie uruchamia żadnego procesu ani sondy. Argumenty przechodzą przez `ProcessStartInfo.ArgumentList`, bez interpolacji powłoki.

Plik argumentów JSON zawiera `run_id`, tablicę `argv`, ograniczony słownik `env` i listę względnych ścieżek `required_artifacts`. Opcjonalne `python_launcher` wskazuje literalną ścieżkę do `venv/bin/python`; jej rozwiązany plik i hash muszą odpowiadać bazowemu Pythonowi z gate. Pozwala to zachować pakiety venv przy `-I`. `JAVA_TOOL_OPTIONS` nie należy do dozwolonych nadpisań. Wszystkie tryby wymagają `gate.json`, `controller-report.json` i `supervisor-report.json`. Pełny zestaw testów dodaje `frozen-source.json`, `collection.json`, `pytest.xml`; soak dodaje `final-full-suite.json`. Kontrolery i końcowy attestor wymagają pełnego zestawu właściwego swojemu trybowi.

Windows zapisuje logi bezpośrednio do plików, odnawia atomowy heartbeat co 2 sekundy i niezależnie sprawdza metadane dumpów, boot ID oraz log jądra. Linux wymaga heartbeat młodszego niż 15 sekund, sprawdza rzeczywisty exit kontrolera i usuwa wyłącznie procesy ze znacznikiem tej próby przez zweryfikowane `pidfd`. Każde wymuszone sprzątanie oznacza niezaliczenie. Po zakończeniu nadzorcy Linux Windows obserwuje jeszcze co najmniej 30 sekund i dopiero wtedy zapisuje `receipt.json`, wiążący hashe wszystkich wymaganych artefaktów oraz helperów przed i po próbie. Zmiana pliku, nowa awaria, zmiana boot ID albo brak odczytu wykluczają PASS.

Brak receipt lub awaria nadzorcy nie oznaczają sukcesu. Zabicie samego klienta `wsl.exe` nie jest dowodem zakończenia procesów Linux. Po awarii nadzorcy może być potrzebne osobne, jawne sprzątanie oznaczonych procesów; launcher nie resetuje WSL i nie naprawia środowiska. Przygotowanie tych skryptów i kontrola składni nie są wykonaniem kwalifikacji ani próby 8 h.

Test guardów można skierować na wybranego kandydata przez `DEVBRAIN_TEST_UPDATER_PATH` lub `python release-tools/test_devbrain_update080_guards.py --updater /sciezka/do/kandydata.py`. Sam import nie instaluje aplikacji ani nie uruchamia usług. Testy właściciela procesu używają krótkich, kontrolowanych procesów. Test smoke korzysta z rzeczywistego silnika i jest uruchamiany dopiero po kwalifikacji środowiska; przygotowanie skryptów i kontrola AST/Ruff nie są jego zaliczeniem.

## Aktualizacja 0.7.1 do 0.7.2

W Ubuntu/WSL uruchom dostarczony aktualizator, wskazując swój katalog źródeł:

```bash
python3 /sciezka/do/devbrain-update-0.7.2.py --source-dir ~/src/devbrain --check-only
python3 /sciezka/do/devbrain-update-0.7.2.py --source-dir ~/src/devbrain
devbrain version
devbrain doctor
devbrain
```

Aktualizator weryfikuje pliki wersji 0.7.1, odmawia nadpisania lokalnych zmian oraz przed zapisem tworzy kopię zmienianych źródeł i bazy w `~/.local/state/devbrain-updates/`. Zachowuje modele, profile i poświadczenia. Archiwalna paczka 0.7.1 pozostaje niezmieniona. `--check-only` sprawdza źródła; nie zastępuje sprawdzenia środowiska ani wykonania kopii bazy. Nie ma automatycznego rollbacku nieudanej instalacji.

Wersja 0.7.2 nie zmienia schematu bazy ani formatu pamięci. Naprawia zgodę na zapis poświadczeń Copilota w WSL, odcina niezamierzone ustawienia BYOK i offline, ponownie sprawdza zawartość runtime oraz używa obsługiwanego klucza `approval_policy` w teście natywnego Codexa. Diagnostyka ekstrakcji zapisuje bezpieczny powód i etap błędu persystencji; historycznych błędów nie uznaje automatycznie za naprawione. Zaktualizowano również Vite i Vitest opcjonalnego interfejsu WWW.

## Co uruchamiasz

DevBrain składa się ze środowiska terminalowego tmux/Textual, zarządzanych sesji natywnych klientów, lokalnej usługi wiedzy, **ArcadeDB jako jedynego silnika danych** i połączenia z Ollama. Codex CLI oraz Claude Code zachowują własne interfejsy, narzędzia, logowanie i uprawnienia. `devbrain` oraz `devbrain tui` uruchamiają ten sam terminalowy workspace; [instrukcja paneli i skrótów](TERMINAL.md).

ArcadeDB ma licencję Apache 2.0. DevBrain zarządza przypiętą wersją `26.11.1`, uruchamianą natywnie na Java 21+. Dokumenty i relacje grafowe, indeks pełnotekstowy oraz wektory `LSM_VECTOR`/HNSW korzystają z jednego silnika i jego transakcji. Docker nie jest wymagany.

Agent wiedzy ma osobny kontekst roboczy. Sam wyszukuje materiały, sprawdza źródła i przechodzi po grafie. Jego trwała wiedza nie zależy od zachowania jednej rozmowy: pochodzi z zapisanych rekordów i snapshotów.

Domyślne modele to `qwen3.5:9b` i `qwen3-embedding:0.6b`. Agent wiedzy ma kontekst 16384 tokenów, limit ośmiu kroków i 60 sekund na analizę. Odpowiedź jest domyślnie ograniczona do około 1200 tokenów. Zakończenie limitu daje wynik częściowy, a brak modelu jawny status `unavailable`.

## Przygotowanie Windows i WSL2

W PowerShellu z uprawnieniami administratora zainstaluj WSL2 Ubuntu, jeśli jeszcze go nie masz:

```powershell
wsl --install -d Ubuntu
wsl --update
```

Po wymaganym przez Windows restarcie utwórz użytkownika Ubuntu. Sterownik NVIDIA instalujesz **w Windowsie**. W WSL sprawdź dostęp do GPU:

```bash
nvidia-smi
```

Jeśli program nie jest w `PATH`, sprawdź `/usr/lib/wsl/lib/nvidia-smi` i dodaj ten katalog do ścieżki. [Dokumentacja NVIDIA dla WSL](https://docs.nvidia.com/cuda/wsl-user-guide/index.html).

Trzymaj pakiet i bazę w systemie plików WSL, np. `~/src/devbrain` i `~/.local/share/devbrain`. Repozytoria można wskazać jawnie także z innych katalogów. Nie trzeba przydzielać całej pamięci komputera do WSL ani instalować Dockera.

### Java 21

Silnik bazy wymaga Java 21 lub nowszej. W Ubuntu:

```bash
sudo apt update
sudo apt install openjdk-21-jre-headless tmux
java -version
tmux -V
```

Java jest potrzebna do uruchomienia bazy, a nie modeli Ollama. Środowisko terminalowe wymaga również tmux 3.4+ w tej samej dystrybucji WSL. Instalator DevBrain sprawdza zależności; nie instaluje automatycznie pakietów systemowych.

### uv

Zainstaluj `uv` zgodnie z [oficjalną instrukcją](https://docs.astral.sh/uv/getting-started/installation/). W Ubuntu można użyć `pipx`:

```bash
sudo apt update
sudo apt install pipx
pipx install uv
export PATH="$HOME/.local/bin:$PATH"
uv --version
```

`uv` potrafi zapewnić interpreter Python 3.12 na potrzeby izolowanego narzędzia. Zmianę `PATH` można dopisać do pliku konfiguracji używanej powłoki.

### Ollama i klienci kodujący

Zainstaluj Ollama **wewnątrz tej samej dystrybucji WSL**. [Instrukcja Linux](https://docs.ollama.com/linux). Jeżeli wybierasz oficjalny instalator, możesz pobrać go do pliku i przejrzeć przed uruchomieniem:

```bash
curl --fail --location https://ollama.com/install.sh --output /tmp/ollama-install.sh
less /tmp/ollama-install.sh
sh /tmp/ollama-install.sh
```

Następnie sprawdź `ollama --version`. Jeśli serwer nie działa jako usługa, uruchom w osobnym terminalu:

```bash
ollama serve
```

Zainstaluj w WSL [Codex CLI](https://developers.openai.com/codex/cli) i [Claude Code](https://code.claude.com/docs/en/setup), a następnie zaloguj się ich własnymi mechanizmami. Sprawdź:

```bash
codex --version
claude --version
```

DevBrain nie przechwytuje danych logowania i nie uruchamia automatycznego logowania klientów.

## Instalacja DevBrain

Skopiuj dostarczony projekt do np. `~/src/devbrain`. Z tego katalogu:

```bash
bash scripts/install-wsl.sh
```

Skrypt sprawdza Linux/WSL, Java 21+, `uv`, pliki pakietu i lockfile. Instaluje narzędzie w izolowanym środowisku, z zależnościami ograniczonymi przez `uv.lock`. Następnie wykonuje `engine install`: pobiera oficjalną dystrybucję ArcadeDB (około 86 MB), sprawdza opublikowaną sumę SHA-256 i zapisuje runtime w magazynie DevBrain. `init` uruchamia silnik oraz tworzy bazę. Na końcu wykonywane jest `doctor`. Skrypt nie edytuje projektów ani konfiguracji klientów; modele nie są pobierane domyślnie.

Ręczna instalacja pakietu jest również możliwa:

```bash
uv tool install --python 3.12 ~/src/devbrain
devbrain engine install
devbrain init
devbrain engine status
devbrain doctor
```

Katalog pliku wykonywalnego pokazuje `uv tool dir --bin`. Jeśli nie znajduje się w `PATH`, dodaj go do konfiguracji powłoki. Ponowne uruchomienie skryptu aktualizuje instalację tego pakietu.

### Zarządzanie silnikiem

```bash
devbrain engine install
devbrain engine start
devbrain engine status
```

`engine install` jest jawnym krokiem pobrania dystrybucji. Powtórzenie korzysta z już zainstalowanej, przypiętej wersji. `engine start` uruchamia lokalny proces Java z katalogiem danych DevBrain; nie tworzy kontenera. Operacje wymagające magazynu mogą uruchomić już zainstalowany silnik, ale nie pobierają go w tle.

ArcadeDB domyślnie nasłuchuje na `127.0.0.1:2480`. Konto lokalne i losowe hasło są zapisane w konfiguracji z uprawnieniami `0600`; hasło nie trafia do argumentów procesu Java. Nie trzeba kopiować poświadczeń do repozytoriów ani serwerów MCP.

### Pobranie i sprawdzenie modeli

Przy działającym serwerze Ollama:

```bash
devbrain models pull
devbrain models list
devbrain doctor
```

`models pull` jawnie pobiera oba skonfigurowane modele i zapisuje ich identyfikatory w `models.lock.json`. Od 0.3.9 nie ponawia wszystkich nieudanych zadań jako efektu pobierania modeli. Aktualizacja tagu modelu nie jest dowodem równoważności jego odpowiedzi; zapisana lista digestów pozwala sprawdzić używaną wersję.

Można też wykonać instalację i pobranie jednym poleceniem:

```bash
bash scripts/install-wsl.sh --pull-models
```

Ta opcja wymaga już uruchomionej Ollama i pobiera kilka GB. Dostępność modeli zależy od lokalnej wersji Ollama; w razie nierozpoznanego modelu zaktualizuj runtime zgodnie z jego dokumentacją.

## Pierwszy projekt i integracje

```bash
devbrain project add sklep ~/src/sklep
devbrain project list
devbrain install sklep
devbrain
```

Dodanie projektu zapisuje trwały identyfikator, indeksuje kod i szuka dostępnych historii powiązanych z katalogiem projektu. Jawnie dodany worktree pozostaje częścią tego samego projektu:

```bash
devbrain project root sklep ~/src/sklep-worktree
devbrain index sklep
```

`install` sprawdza dostępne możliwości klientów i dodaje konfigurację projektową:

- Codex: `.codex/config.toml`, `.codex/hooks.json` i zarządzany fragment `AGENTS.md`.
- Claude Code: `.mcp.json`, `.claude/settings.local.json` i zarządzany fragment `CLAUDE.md`.

Istniejące treści są zachowywane, a zmieniane pliki otrzymują kopie z nazwą `devbrain-backup`. Brak zainstalowanego klienta lub nieweryfikowalna obsługa hooków pojawia się w wyniku instalacji. Konfiguracja niezwiązanego serwera o nazwie `devbrain` nie jest po cichu zastępowana.

Od 0.3.6 scalanie TOML zachowuje również natywne zgody narzędzi dopisane wewnątrz oznaczonego bloku DevBrain oraz tryb istniejącego pliku. Edytowane są wyłącznie `command`, `args`, `env_vars`, `startup_timeout_sec` i `tool_timeout_sec`; pozostałe opcje i komentarze pozostają zachowane. Jeśli te pięć pól już odpowiada instalacji, plik nie jest przepisywany. Zgody nadal nadajesz w interfejsie Codexa. Zapis nowej trwałej zgody zmienia `.codex/config.toml`, więc kontrola świeżości może wymagać nowego odczytu pakietu i ACK przed ponowieniem operacji.

Przy pierwszym uruchomieniu zatwierdź projekt, serwer MCP i hooki w mechanizmach danego klienta. DevBrain nie omija zaufania ani uprawnień. Launcher i `devbrain run` odmawiają startu starszego lub nieweryfikowalnego klienta, gdy nie można potwierdzić MCP, hooków, przekazania pakietu i powiązania sesji. Sprawdź wynik `devbrain doctor` i zaktualizuj klienta przed ponownym uruchomieniem.

## Codzienna praca

`devbrain` bez argumentów i `devbrain tui` otwierają środowisko w bieżącym terminalu, niezależnie od katalogu roboczego. Od 0.7 profile obejmują także własnego agenta API, lokalną Ollamę i oficjalny SDK Copilot; [konfiguracja połączeń](API.md). Wspólny rejestr projektów, profile klientów, stan logowania, surowe natywne panele, inspektor pamięci i terminalowy graf 3D są opisane w [instrukcji środowiska terminalowego](TERMINAL.md). Używaj Windows Terminal z Unicode/UTF-8 i tmux 3.4+ w Ubuntu. Gotowa instalacja nie wymaga Node.js ani budowania frontendu.

Pełny układ to pięć paneli: boczny wybór projektu i ustawień, Codex, Claude, inspektor oraz graf. Minimalny pełny rozmiar to 140×42, zalecany 180×55. Mniejszy terminal przełącza aktywny panel w widok kompaktowy; zmiana rozmiaru nie kończy ukrytych klientów. Otwarcie workspace przywraca widoki istniejących sesji; uruchomienie nowej pracy albo wznowienie zakończonego klienta wybierasz jawnie w panelu bocznym.

`Ctrl+B`, następnie `p`, `1`, `2`, `i` lub `g` wybiera panel boczny, klientów, inspektor lub graf. `Ctrl+B z` zmienia powiększenie, `Ctrl+B d` odłącza workspace, a `Ctrl+B Ctrl+B` przekazuje prefiks do natywnego klienta. Standardowe klawisze wpisywane w panelu klienta trafiają do jego rzeczywistego CLI. [Pełna tabela skrótów](TERMINAL.md#nawigacja).

```bash
devbrain workspace status
devbrain workspace detach
devbrain workspace takeover
devbrain workspace stop
devbrain workspace stop --clients
```

Odłączenie zachowuje układ i procesy. `workspace stop` kończy zewnętrzny układ terminalowy; `--clients` zatrzymuje dodatkowo wyłącznie identyfikatory klientów przejętych przez ten workspace. Inne uruchomienia nie są automatycznie kończone. Wyłączenie WSL kończy wszystkie procesy w tej dystrybucji, a zapisana pamięć pozostaje. Późniejsze wznowienie jest jawną akcją i zachowuje odczyt pakietu oraz ACK.

Drugi terminal dołącza do istniejącego workspace w trybie podglądu. Steruje jeden terminal; `devbrain workspace takeover` jawnie przejmuje sterowanie i przełącza dotychczasowy terminal w podgląd, zachowując procesy klientów.

Wywołanie bez interaktywnego TTY kończy się czytelnym komunikatem przed tworzeniem konfiguracji lub uruchamianiem usług. Nie otwiera wtedy przeglądarki. Zachowany interfejs WWW 0.5 wymaga jawnego `devbrain cockpit open`; [instrukcja archiwalna](COCKPIT.md).

Alternatywnie:

```bash
devbrain run sklep codex
devbrain run sklep claude
devbrain run sklep codex -- resume
```

Argumenty po `--` trafiają do oryginalnego CLI. Dla Codexa launcher dodaje `--no-daemon` i konfiguruje przekazanie `DEVBRAIN_SESSION_ID` oraz `DEVBRAIN_PACKET_ID` do MCP przez `env_vars`. Claude otrzymuje te same dwie zmienne przez rozwijane przy starcie wpisy `env` w `.mcp.json`. Pliki projektu zawierają nazwy zmiennych, a ich wartości pochodzą z konkretnego procesu launchera. Zweryfikowane uruchomienie obsługuje lokalne procesy; zdalny lub współdzielony serwer klienta jest odrzucany. Launcher nie dodaje trybów pomijających uprawnienia. Kilka terminali może korzystać ze wspólnej pamięci jednocześnie.

Przed startem klienta launcher przygotowuje pakiet konkretnej sesji, epoki i worktree. Pakiet obejmuje cel, ograniczenia, wersje aktywnego planu i zadania, następny krok, blokady, odciski kodu i odnośniki do źródeł. Gotowość dotyczy jawnie uchwyconego stanu i zakresu archiwum. Oczekujący import, nierozpoznany zakres historii albo brak potrzebnego źródła daje `partial`; launcher wtedy zatrzymuje start. Brak wcześniejszej historii w nowym projekcie jest jawny i nie blokuje pustego projektu.

Od 0.3.4 importer obsługuje techniczne metadane `world_state` i `token_usage_record` Codexa 0.166. Przed sprawdzeniem archiwum może ponownie rozpoznać wpisy tych dwóch typów zachowane przez wcześniejszy parser. Kontroluje skrót, pochodzenie oraz przypisanie do projektu; aktualizuje wyłącznie interpretację i rolę wpisu. Surowe źródło, jego ID, URI, skrót i kursor importu pozostają zachowane. Metadane techniczne nie trafiają do ekstrakcji decyzji użytkownika. Nieobsługiwany format, niepoprawna struktura i konflikt projektu nadal blokują pełną gotowość.

Od 0.3.7 to samo ponowne rozpoznawanie obejmuje 11 obserwowanych typów Claude Code 2.1.318: `mode`, `permission-mode`, `session-owner`, `atis-latch`, `attachment`, `api-request-shape`, `api-request`, `last-prompt`, `cost-state`, `ai-title` i `tools-used`. Parser sprawdza wymagane pola i ich typy; zawartość obiektów załączników oraz żądań pozostaje niezmienionymi danymi źródłowymi. Wpisy te są pomocniczymi metadanymi, a nie decyzjami użytkownika, i nie uruchamiają ekstrakcji. Surowa treść pozostaje zarchiwizowana i wyszukiwalna. Aktualizacja wcześniej nieznanych wpisów zachowuje ich identyfikatory, URI, skróty, fragmenty i kursor, wraz z audytem poprzedniej klasyfikacji. Nieobsługiwane lub niepoprawne warianty nadal pozostają nieznane.

Od 0.3.5 zakres archiwum jest ustalany dla konkretnego wznowienia i zachowywany podczas ponawiania odczytu. Nowa, bieżąca rozmowa klienta pozostaje archiwizowana w tle; jej dopisywane wywołania narzędzi nie przesuwają wymagań tego samego pakietu. Zdarzenia zakończenia tury lub sesji zachowują kolejne zakresy dla następnego wznowienia. Niedokończony wpis z już wymaganej historii nadal blokuje gotowość do czasu pełnego zarchiwizowania. Hook startowy żąda dokładnego pakietu przez `packet_id`; taki odczyt nie odświeża ani nie zastępuje pakietu. Zmiana kodu lub istotnego stanu nadal unieważnia stare ACK, a kompresja, wyczyszczenie i wznowienie rozmowy zachowują kontrolę epoki.

Od 0.3.8 pierwsza próba odczytu bez ustalonego rozmiaru i generacji pliku może zostać rozliczona przez późniejszy poprawny odczyt tej samej natywnej sesji. Wymagane są trwałe zdarzenia wiążące klienta, projekt i ścieżkę oraz pełne sprawdzenie surowych źródeł dla późniejszego, ustalonego zakresu. Pierwotny błąd i dowody jego rozliczenia pozostają w audycie; stare pakiety, zdarzenia i kursory nie są usuwane. Taki mechanizm nie usuwa znanych wymagań dotyczących rozmiaru, generacji, prefiksu, ogona lub wcześniejszego dowodu. Brak powiązania, brak późniejszego zakresu albo niepełne czy sprzeczne źródła nadal dają `partial`.

Istniejący projekt z kodem wymaga repozytorium Git i pierwszego commita, aby odcisk wersji kodu mógł być sprawdzony. Nieznany stan kodu zatrzymuje start w trybie strict; przygotuj repozytorium i sprawdź wynik `devbrain session prepare PROJEKT codex`. Pusty nowy katalog jest obsługiwany jako jawny brak wcześniejszego kodu.

Model odczytuje `resume_context` i sam wywołuje `ack_resume` z dokładnym identyfikatorem, hashem pakietu oraz identyfikatorami i wersjami planu i zadania. Samo dostarczenie kontekstu przez HTTP nie jest ACK. Zapisy DevBrain z powiązanej sesji są blokowane do ACK; istotna zmiana stanu, wznowienie lub kompresja unieważnia wcześniejsze potwierdzenie. Ręczne polecenia administracyjne uruchomione poza powiązaną sesją pozostają dostępne do naprawy stanu.

ACK dowodzi odbioru i odczytania wskazanych wersji, nie zrozumienia przez model. Natywne operacje plikowe i narzędzia klientów nadal podlegają ich własnym kontrolom. Hooki są dodatkową ochroną przepływu, a nie pełną blokadą każdego możliwego narzędzia. Końcowy hook zapisuje zdarzenie do kolejki plikowej; nie czeka na bazę ani GPU. Archiwizacja, indeksowanie i ekstrakcja są osobnymi etapami.

```bash
devbrain ask sklep "Dlaczego zmieniliśmy logowanie i które testy je obejmują?"
devbrain context sklep
devbrain status --project sklep
devbrain records sklep
devbrain records sklep --history
devbrain source ID_ZRODLA
```

Status rozróżnia źródła zarchiwizowane, zindeksowane i opracowane przez model. W kolejce widać zadania oczekujące, wykonywane, ukończone i błędne. Historia nieudanej próby importu nie określa sama aktualnej kompletności archiwum. Od 0.3.9 diagnostyka pokazuje zakres i pochodzenie dowodu; gdy brakuje takich danych dla starszego zadania, kompletność pozostaje nieznana. Odczyt statusu nie przesuwa zakresu wznowienia ani nie tworzy nowego dowodu.

Odczyt pomocy, `status` oraz `jobs list/show` korzysta z istniejącej konfiguracji i nie uruchamia usługi. Przy wyłączonej usłudze diagnostyka zgłasza niedostępność. Uruchom środowisko zwykłym `devbrain` lub `devbrain run PROJEKT KLIENT`, jeśli chcesz rozpocząć pracę.

```bash
devbrain jobs list sklep --state failed
devbrain jobs show sklep ID_ZADANIA_KOLEJKI
devbrain jobs retry sklep ID_ZADANIA_KOLEJKI --expected-attempts LICZBA_PROB_Z_ODCZYTU
```

Ponowienie dotyczy jednego zadania w wskazanym projekcie i sprawdza jego stan `failed` oraz liczbę wcześniejszych prób. Konflikt wymaga ponownego odczytu; zadanie wykonywane lub ukończone nie jest ponawiane tą operacją. Audyt zachowuje poprzedni błąd i dane próby. Operacja z powiązanej sesji nadal wymaga aktualnego ACK. `devbrain retry-jobs` pozostaje jawną administracyjną operacją ponowienia wszystkich nieudanych zadań; nie jest wykonywane przez pobieranie modeli.

Od 0.3.10 istnieje osobny, jawny wyjątek dla ekstrakcji zakończonej z pominięciem wszystkich propozycji: `completed_with_omissions`, dodatnia liczba kandydatów, zero zaakceptowanych i zapisanych rekordów, wszystkie kandydatury pominięte oraz kod `proposal_rejected`. Wyłącznie z flagą `--include-omissions` można ponowić takie zadanie z bieżącym `--expected-attempts`. Poprawnie ukończone zadanie, pusty wynik, pominięcie duplikatów lub częściowy zapis nie kwalifikują się. Historia i ID zadania pozostają zachowane.

```bash
devbrain jobs retry sklep ID_ZADANIA_KOLEJKI --expected-attempts BIEZACA_LICZBA_PROB --include-omissions
```

Odpowiedź `ask` i zadania ekstrakcji otrzymują ograniczoną diagnostykę etapu, kategorii błędu i wyniku poprawy formatu. Powód zakończenia generowania i liczniki tokenów są podawane, gdy runtime je raportuje; nieobecne dane pozostają nieznane. Zwykła diagnostyka nie zapisuje pełnych promptów ani odpowiedzi modelu. Błąd parsowania JSON bez powodu zakończenia nie dowodzi wyczerpania limitu tokenów.

Od 0.3.9 pojedyncza korekta `ask` korzysta z ograniczonego zestawu odczytanych dowodów zamiast ponownie przesyłać całą historię narzędzi. Wymagania dotyczące dosłownych cytatów, zakresu projektu/worktree i świeżości pozostają w mocy. Ekstrakcja korzysta ze schematu JSON i może jednokrotnie poprawić format w tym samym limicie 30 sekund oraz dotychczasowym budżecie tokenów. Pełna walidacja poprzedza atomowy zapis zaakceptowanych propozycji i powiązań. Nieudana poprawa pozostawia zadanie `failed`; oryginalne źródła, fragmenty i kursory pozostają zachowane.

Od 0.3.10 ekstrakcja otrzymuje wyłącznie badane źródło; wcześniejsze rekordy są sprawdzane podczas atomowego zapisu w celu deduplikacji. Schemat generowania zawiera ograniczony zbiór dokładnych fragmentów widocznego tekstu, z których model wybiera cytat. Model ignorujący schemat nadal podlega niezależnemu sprawdzeniu dosłownej obecności cytatu. Krótkie źródło otrzymuje jeden pełny fragment; dłuższy widoczny tekst jest dzielony na nakładające się fragmenty. Brak trwałych faktów może prawidłowo dać pustą listę rekordów.

`diagnostics.rejection_counts` osobno zlicza `blank_content`, `blank_evidence`, `quote_absent_source` i `reserved_metadata`. Liczniki mogą się nakładać. Zachowano kod zbiorczy `proposal_rejected`; raport nie zawiera odrzuconych treści ani cytatów. Stan `completed` z `completed_with_omissions` pozostaje informacją o zakończeniu przetwarzania, a nie potwierdzeniem zapisania ustaleń.

### RAG, graf i aktualność

Hybrid RAG łączy natywny indeks pełnotekstowy ArcadeDB z wektorowym indeksem `LSM_VECTOR`/HNSW. GraphRAG przechodzi po źródłowych zależnościach plików, symboli, zadań i decyzji zapisanych jako graf ArcadeDB. Agent może wykonać kilka kolejnych wyszukiwań i odczytów, aby połączyć materiał w odpowiedź. Filtry projektu i aktualności obowiązują również wyniki wyszukiwania wektorowego.

Parsery Python/JavaScript/TypeScript wyprowadzają deklaracje, importy i statycznie rozpoznawalne wywołania. Dynamiczne wywołanie lub nieznany moduł nie stają się udowodnioną zależnością tylko dlatego, że model tak przypuszcza. Inne języki są indeksowane tekstowo.

Snapshoty zawierają wersję indeksowanej treści i informacje o Git, jeśli są dostępne. Agent sprawdza świeżość kodu przed przedstawieniem go jako aktualnego. Zmiana kodu odświeża indeks; stare snapshoty pozostają odczytywalnymi źródłami historii.

## Zadania, plany i ukończenie

| Pole | Przykłady | Znaczenie |
| --- | --- | --- |
| `status` | `proposed`, `confirmed`, `disputed`, `superseded` | Pewność ustalenia |
| `metadata.state` | `todo`, `in_progress`, `needs_test`, `needs_review`, `done`, `blocked` | Postęp zadania |
| Odczyt weryfikacji | `fresh`, `stale`, `reported`, `unknown` | Aktualność dowodów testowych |

### Cały plan w jednej transakcji

Przykładowy `plan.json`:

```json
{
  "plan": {
    "title": "Logowanie",
    "goal": "Sprawdzić logowanie i obsługę błędnego hasła",
    "constraints": ["Zachować sesje po stronie serwera"]
  },
  "steps": [
    {"key": "implement", "content": "Dodać walidację hasła"},
    {
      "key": "test",
      "content": "Sprawdzić poprawne i błędne hasło",
      "depends_on": ["implement"],
      "metadata": {"requires_test": true, "required_profiles": ["unit"]}
    }
  ]
}
```

```bash
devbrain plan save sklep ./plan.json --idempotency-key login-plan-1 --activate
devbrain plan list sklep
devbrain plan next sklep
devbrain plan activate sklep ID_PLANU --worktree ~/src/sklep-worktree
devbrain task list sklep
devbrain task update sklep ID_ZADANIA in_progress
```

Zapis przydziela stabilne identyfikatory, sprawdza cały finalny graf zależności i zatwierdza nagłówek oraz wszystkie kroki atomowo. Ten sam klucz żądania z tą samą treścią odtwarza pierwotny wynik; użycie klucza do innej treści jest konfliktem. Edycja istniejącego planu wymaga jego `expected_version` oraz oczekiwanych wersji zmienianych kroków w `task_versions` (w JSON lub przez `--expected-version` i `--task-versions PLIK`). Klucz żądania podajesz jawnie przez `--idempotency-key`. Usunięte kroki pozostają w historii. Nowych kroków nie można zadeklarować jako gotowych lub zweryfikowanych samym zapisem planu.

Aktywny plan jest przypisany do pary projekt/worktree. Następny krok wybierany jest deterministycznie spośród kroków planu z uwzględnieniem zależności i stanu. `needs_test` i `needs_review` pozostają pracą do wykonania; blokady są jawne. Równoległa aktualizacja zadania sprawdza wersję zadania i planu.

Dawne `metadata.plan_id` jest tekstową etykietą grupy. Nowe plany korzystają z `metadata.plan_ref` i `step_key`. Przejęcie grupy jest jawną operacją:

```bash
devbrain plan adopt sklep logowanie --idempotency-key adopt-login-1 --title "Logowanie" --activate
```

### Nazwane profile sprawdzeń

Zapisz w repozytorium `.devbrain/checks.toml`:

```toml
[checks.unit]
argv = ["uv", "run", "pytest", "tests/unit"]
cwd = "."
timeout_seconds = 600
output_limit_bytes = 10485760
extra_inputs = []
```

`argv` jest listą wykonywaną bez powłoki. `cwd` pozostaje wewnątrz zarejestrowanego worktree. `extra_inputs` może jawnie uwzględnić ignorowane pliki wejściowe lub wzorce względem tego katalogu. Limity czasu i wyjścia kończą proces jako nieudany; logi i ich snapshoty trafiają poza repozytorium.

```bash
devbrain check run sklep unit --task ID_ZADANIA
devbrain check list sklep --task ID_ZADANIA
```

Polecenie uruchamia się w **bieżącym worktree**, z uprawnieniami użytkownika. Nie tworzy izolowanego, niezmiennego checkoutu. TUI i MCP pokazują wyniki, a wykonanie wymaga jawnego polecenia CLI z nazwą profilu. Nie ma narzędzia MCP do dowolnego polecenia.

Niezmienny wynik wiąże profil, semantyczną definicję zadania oraz odciski kodu przed i po wykonaniu. Odcisk uwzględnia treść plików śledzonych i nieignorowanych nieśledzonych, tryby, usunięcia i cele dowiązań; nie obowiązuje limit indeksowania RAG 2 MiB. Niepełne lub niestabilne wejścia dają `unknown` albo wynik niekwalifikujący się jako świeży. Porównanie przed/po jest najlepszym dostępnym sprawdzeniem bieżącego katalogu; nie wykryje każdej przejściowej zmiany cofniętej podczas testu ani nie zastąpi śledzenia zewnętrznych usług i środowiska.

Przed sprawdzeniem skonfiguruj `.gitignore` dla generowanych cache i wyników, np. `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.coverage` i `htmlcov/`, jeżeli projekt jeszcze ich nie ignoruje. Nowy nieignorowany plik powstały podczas testu zmienia odcisk i może dać nieświeży wynik mimo kodu wyjścia 0. Pliki już śledzone przez Git nadal wchodzą do odcisku. Rzeczywiste ignorowane wejścia testu zadeklaruj przez `extra_inputs`.

Kod wyjścia 0 potwierdza powodzenie skonfigurowanego polecenia. Nie dowodzi spełnienia wszystkich kryteriów, pokrycia testami ani wykonania review. Nowe ukończenie zadania wymagającego testów potrzebuje świeżych wyników wszystkich wymaganych profili; review i akceptacja mają oddzielne wymagania dowodowe.

Flaga `acceptance_passed` z odnośnikami `acceptance_source_ids` dokumentuje ocenę kryteriów zadania. Nie jest dowodem akceptacji człowieka. W pilotażu jeden checkpoint może stanowić źródło zarówno review, jak i oceny wszystkich kryteriów, jeśli faktycznie zawiera obie oceny. Zmiana postępu kroku zwiększa wersję planu, lecz sama nie zmienia semantycznej definicji zadania; świeżość wyników ustala `check_status`.

Po zmianie kodu, profilu lub treści zadania wynik może być `stale`. Dawny postęp `done` zostaje w historii i nie otwiera automatycznie wszystkich zadań na nowo. Dawne flagi `test_passed` i źródłowe deklaracje pozostają `reported`/legacy; migracja nie tworzy z nich wyników runnera. Model nie może wytworzyć maszynowego wyniku przez `remember` albo `checkpoint`.

### Wywołania MCP

Oba klienty otrzymują `ask`, `remember`, `checkpoint`, `save_plan`, `next_task`, `resume_context`, `ack_resume` i odczytowe `check_status`. Aktualizacja kroku zarządzanego planu przekazuje rzeczywiste wersje:

```json
{
  "project": "ID_PROJEKTU",
  "record": {
    "id": "ID_ZADANIA",
    "expected_version": 2,
    "expected_plan_version": 3,
    "metadata": {"state": "needs_test"}
  },
  "sources": ["ID_ISTNIEJACEGO_ZRODLA"]
}
```

Źródła muszą należeć do tego samego projektu. Konflikt wymaga ponownego odczytu, a nie nadpisania nowszej pracy. Powiązana sesja musi wcześniej potwierdzić aktualny pakiet. `save_plan` przyjmuje ten sam nagłówek, kroki, klucz idempotencji i wersje co API zapisu planu. `checkpoint` pozostaje zapisem stanu z celem, wynikami i następnym krokiem:

```bash
devbrain checkpoint sklep ./punkt-kontynuacji.json
devbrain remember sklep "Używamy sesji po stronie serwera" --kind decision --confirmed
```

## Import historii i zakres indeksowania

```bash
devbrain import ~/eksport/sesja.jsonl --project sklep --client codex
devbrain import ~/eksport/claude.jsonl --project sklep --client claude
devbrain import ~/eksport/nieprzypisana.jsonl
```

Import śledzi postęp w pliku. Powtórzenie polecenia nie powinno powielać zdarzeń. Niekompletny końcowy wiersz czeka na dalszy zapis. Nierozpoznany format w przypisanym projekcie zostaje zarchiwizowany w surowej postaci z ostrzeżeniem; taki zakres blokuje gotowość wznowienia. Dane bez jednoznacznego przypisania pozostają w skrzynce importu. Automatyczne wykrywanie historii przypisuje wyłącznie sesje powiązane z katalogami projektu.

Skaner projektu odczytuje tekst UTF-8 do **2 MiB na plik**, respektuje zagnieżdżone `.gitignore`, pomija pliki binarne, zależności, katalogi budowania, dowiązania oraz m.in. `.env`, `.env.*`, klucze i pliki baz danych. Historia rozmów jest archiwizowana ze źródłową treścią; zawiera to, co zostało zapisane przez klienta. Wygenerowane odpowiedzi agenta wiedzy nie są używane jako nowe, niezależne dowody.

## Aktualizacja 0.7.0 do 0.7.1

Aktualizator `devbrain-update-0.7.1.py` obsługuje wyłącznie źródłową instalację **0.7.0**. Poprawka naprawia błąd wyświetlania grafu oraz dodaje oświetlony renderer ASCII 3D, z perspektywą i zasłanianiem dalszych powierzchni przez bliższe. Graf nadal przedstawia rzeczywistą pamięć. Zakończ bieżącą pracę modeli przed aktualizacją.

Zapisz aktualizator na Pulpicie Windows. W zwykłym terminalu Ubuntu wykonaj podgląd, a następnie aktualizację:

```bash
/usr/bin/python3 /mnt/c/Users/piotr/OneDrive/Desktop/devbrain-update-0.7.1.py --source-dir "$HOME/src/devbrain" --check-only
/usr/bin/python3 /mnt/c/Users/piotr/OneDrive/Desktop/devbrain-update-0.7.1.py --source-dir "$HOME/src/devbrain" --open
```

`--check-only` nie zmienia plików ani danych. Aktualizator odrzuca lokalne zmiany i usunięcia plików objętych poprawką. Przed zapisem zatrzymuje dotychczasowe widoki i usługę, zachowując procesy natywnych klientów, oraz wykonuje kopię źródeł i bazy w `$XDG_STATE_HOME/devbrain-updates/` albo `~/.local/state/devbrain-updates/`. Ponowne zastosowanie ukończonej, identycznej aktualizacji nie przepisuje plików i nie restartuje usług. `--open` wymaga interaktywnego terminala.

Dane, modele, profile, klucze API, poświadczenia i natywne uprawnienia Codexa i Claude’a pozostają zachowane. Aktualizacja nie wykonuje płatnych zapytań, nie pobiera modeli i nie przygotowuje runtime Copilota. Schemat bazy pozostaje **4**, format profili **2**, administracyjnego backupu **5**, a przenośnej pamięci **1**; nie ma nowej migracji bazy.

Po aktualizacji `devbrain version` powinno pokazać `0.7.1`. Uruchom `devbrain`, przejdź do grafu przez `Ctrl+B`, potem `g`, i użyj `Ctrl+B`, potem `z`, aby powiększyć panel. [Sterowanie grafem](TERMINAL.md#graf-3d-w-terminalu).

Wersję 0.6.0 najpierw zaktualizuj do 0.7.0 poniższym pakietem. Instalacje 0.4/0.5 wymagają wcześniej pakietu 0.6.

## Aktualizacja 0.6 do 0.7

Aktualizator `devbrain-update-0.7.0.py` obsługuje wyłącznie źródłową instalację **0.6.0**. Starszą wersję 0.4/0.5 najpierw zaktualizuj istniejącym pakietem 0.6. Zakończ bieżącą pracę modeli przed aktualizacją. Nie trzeba ponownie pobierać wag modeli, odtwarzać bazy ani ponownie przyznawać uprawnień natywnym klientom.

Zapisz pobrany aktualizator na Pulpicie Windows pod wskazaną nazwą. W zwykłym terminalu Ubuntu sprawdź zakres, a następnie wykonaj aktualizację:

```bash
/usr/bin/python3 /mnt/c/Users/piotr/OneDrive/Desktop/devbrain-update-0.7.0.py --source-dir "$HOME/src/devbrain" --check-only
/usr/bin/python3 /mnt/c/Users/piotr/OneDrive/Desktop/devbrain-update-0.7.0.py --source-dir "$HOME/src/devbrain" --open
```

`--check-only` nie zmienia plików ani danych. Aktualizator odrzuca lokalne zmiany i usunięcia plików objętych poprawką. Przed zapisem zatrzymuje dotychczasowe widoki i usługę, zachowując procesy natywnych klientów, oraz wykonuje kopię źródeł i bazy w `$XDG_STATE_HOME/devbrain-updates/` albo `~/.local/state/devbrain-updates/`. Ponowne zastosowanie ukończonej, identycznej aktualizacji nie przepisuje plików i nie restartuje usług. `--open` wymaga interaktywnego terminala.

Po aktualizacji:

```bash
devbrain version
devbrain
```

ArcadeDB pozostaje w schemacie **4**, administracyjny backup w formacie **5**, a pamięć projektu w formacie **1**. Nie ma nowej migracji bazy. Ustawienia profili w formacie 1 są odczytywane bez zapisu; pierwsza zmiana ustawień tworzy prywatną kopię i zapisuje format 2. Istniejące profile, układy i dane pozostają zachowane.

Instalacja dodaje biblioteki nowego silnika, ale nie wykonuje płatnych zapytań, nie pobiera modeli Ollamy i nie przygotowuje runtime Copilota. Konfigurację wykonujesz w **Profile** i **Loguj**. [Ollama, API i Copilot — pełna instrukcja](API.md).

## Archiwum: aktualizacja 0.4 i 0.5 do 0.6

Pakiet aktualizacji 0.6 obsługuje źródłowe instalacje 0.4.0 i 0.5.0. Nie wymaga ponownego pobierania już dostępnych modeli, odtwarzania magazynu ani ponownego nadawania dotychczasowych uprawnień Codexa i Claude’a. Ustawienia i dane pozostają w lokalnym katalogu DevBrain.

Magazyn 0.4 używa schematu 3. Przy pierwszym otwarciu przechodzi istniejącą addytywną migrację do schematu 4 z kopią `backups/before-schema-3-to-4-*.devbrain.json.gz`, dodającą dziennik zatwierdzonych zmian. Wersja schematu zapisywana jest po zakończeniu migracji. Magazyn 0.5 już ma schemat 4; sam terminalowy interfejs 0.6 nie dodaje kolejnego schematu ani nowego silnika danych.

Administracyjny eksport ma format 5 i obsługuje kopie w formatach 2–4 po sprawdzeniu ich oryginalnych sum. Historyczne deklaracje testów pozostają deklaracjami. Nie wykonuj administracyjnego odtworzenia przy aktywnych klientach. Projektowy snapshot `.memory/devbrain/` ma osobny format 1; `memory import` zachowuje inne projekty, a administracyjne `restore` zastępuje cały magazyn.

## Przenośna pamięć projektu

Snapshot w `.memory/devbrain/` zawiera wyłącznie pamięć wybranego projektu: pełne zapisane rozmowy i źródła, rekordy wraz z rewizjami, decyzje, plany i ich historię, zadania z postępem, checkpointy, logiczne relacje oraz historyczne dowody testów. Uwzględnia również źródła użyte przez wcześniejsze wersje ustaleń. Zachowuje identyfikatory, statusy `proposed`/`confirmed` i dokładne sumy źródeł.

Nie zawiera wag modeli, embeddingów, konfiguracji komputera, plików uwierzytelnienia, kluczy z konfiguracji, aktywnych sesji, pakietów/ACK, kursorów importu ani działających zadań technicznych. Rozmowy i surowe źródła mogą jednak zawierać dane prywatne lub wpisane w rozmowę sekrety — nie są automatycznie anonimizowane. Zobacz zakres przed umieszczeniem snapshotu w repozytorium.

### Zapis i automat

```bash
devbrain memory snapshot sklep --preview
devbrain memory snapshot sklep
devbrain memory snapshot sklep --worktree ~/src/sklep-drugi-worktree
devbrain memory auto sklep --enable --interval-minutes 15
devbrain memory status sklep
devbrain memory auto sklep --disable
```

Podgląd pokazuje projekt, miejsce zapisu, liczby obiektów, rozmiar i stan przetwarzania. Snapshot odzwierciedla spójny stan już zapisany w bazie; zaległe importy, indeksowanie i ekstrakcja są nadal widoczne. Zapis nie czeka na model ani nie deklaruje, że brakująca historia została zarchiwizowana.

Automat jest domyślnie wyłączony i włączasz go oddzielnie dla projektu. Jego konfiguracja pozostaje na bieżącym komputerze. Działa w usłudze DevBrain, także po zamknięciu TUI; po wyłączeniu WSL nie działa. Domyślnie sprawdza zmiany co 15 minut i pomija niezmienioną zawartość. Po wznowieniu nie tworzy serii zaległych kopii.

Zapis najpierw publikuje obiekty, a następnie kompletny manifest z sumami kontrolnymi. Zachowywanych jest pięć ostatnich snapshotów; identyczne obiekty są współdzielone. Przerwanie zapisu pozostawia poprzedni poprawny manifest. Zewnętrzna zmiana plików snapshotu zatrzymuje automatyczne nadpisywanie i wymaga wyjaśnienia stanu lub importu.

W panelu pamięci terminalowego workspace wybierz projekt/worktree, obejrzyj podgląd i jawnie zapisz snapshot. Widok pokazuje zakres, ostatni zapis, automat i błędy. Włączanie automatu jest osobną akcją. Te same operacje można wykonać powyższymi poleceniami CLI.

### Git i drugi komputer

DevBrain nie wykonuje commitów ani nie wysyła plików. Po podglądzie świadomie dodaj cały zarządzany katalog do wybranego repozytorium, np.:

```bash
git -C ~/src/sklep add .memory/devbrain
```

Następnie wykonaj własny commit i push. Jeśli `.gitignore` pomija `.memory/`, zmień regułę dla plików, które rzeczywiście chcesz przenieść. Retencja snapshotów nie usuwa ich z wcześniejszej historii Git. Zapis plików `.memory/devbrain/` nie zmienia manifestu kodu DevBrain i nie jest indeksowany jako nowa wiedza. Commit zmieniający Git HEAD nadal konserwatywnie unieważnia poprzednie sprawdzenia i pakiety — również gdy zawiera tylko snapshot.

Na drugim komputerze zainstaluj DevBrain z ArcadeDB/Java, sklonuj repozytorium i jawnie wskaż katalog docelowy:

```bash
devbrain memory inspect ~/src/sklep/.memory/devbrain
devbrain memory import ~/src/sklep/.memory/devbrain --root ~/src/sklep --dry-run
devbrain memory import ~/src/sklep/.memory/devbrain --root ~/src/sklep
```

`inspect` przyjmuje katalog pakietu albo `manifest.json` i nie uruchamia bazy, usługi ani modeli. `--dry-run` sprawdza możliwość importu bez zmiany danych. Pomoc i `memory status` nie inicjalizują konfiguracji ani usług. Jeżeli lokalna nazwa jest już zajęta przez inny projekt, jawnie wybierz inną przez `--name sklep-przeniesiony`.

Import w terminalowym panelu pamięci działa także przed zarejestrowaniem pierwszego projektu. Podaj ścieżkę snapshotu oraz katalog docelowy, sprawdź podgląd i możliwość importu, a następnie jawnie wczytaj pamięć. Zmiana ścieżki, katalogu lub nazwy wymaga ponownego sprawdzenia. Samo wykrycie snapshotu nie uruchamia importu. Dla sklonowanego projektu z `.memory/devbrain/` zacznij od importu, aby zachować jego tożsamość.

Import sprawdza format, kompletność obiektów, sumy źródeł i powiązania, następnie zapisuje jeden projekt w transakcji. Zachowuje jego stabilną tożsamość; nie dopasowuje po samej nazwie ani adresie Git. Inne projekty pozostają bez zmian. Ponowny import tego samego stanu niczego nie powiela. Kontynuacja zgodnej historii jest obsługiwana, ale rozbieżne edycje z dwóch komputerów kończą się raportem konfliktu bez częściowego nadpisania. Automatyczne scalanie nie jest częścią tej wersji.

Źródłowe ścieżki pozostają informacją o pochodzeniu, a wybrany katalog otrzymuje lokalne powiązanie. Dane pozostałych dawnych worktree są historyczne do czasu powiązania. Wyszukiwanie tekstowe i relacje pamięci są odtwarzane z zapisanych źródeł; aktualny kod i embeddingi indeksują się lokalnie. Eksport i import nie wymagają dostępnej Ollama.

Historyczne `done` i źródła review pozostają zapisane. Importowany udany test jest dowodem historycznym, a nie lokalnym `fresh`, nawet przy identycznym kodzie i ścieżce. Uruchom lokalnie wymagany profil przez `devbrain check run`. Zaloguj klientów ich własnymi mechanizmami i skonfiguruj integracje dla nowego katalogu przez `devbrain install`. Nowa sesja wymaga normalnego odczytu pakietu i ACK; żadna operacja z plików pamięci nie jest automatycznie wykonywana.

### Automatyczny test jakości pamięci

```bash
devbrain eval memory
```

Polecenie jawnie korzysta z rzeczywistej Ollama. W dwóch tymczasowych bazach i różnych katalogach uruchamia produkcyjną ekstrakcję trzech jednoznacznych źródeł: faktu, decyzji i zadania. Wymaga zapisania wszystkich oczekiwanych ustaleń z poprawnymi dowodami; poprawne technicznie `[]` nie zalicza tego scenariusza. Następnie przenosi snapshot i sprawdza trzy odpowiedzi nowego agenta wraz z cytowaniami oraz brak ujawnienia danych innego projektu.

Raport podaje etapy, identyfikatory modeli, czasy i wynik; test sprząta wyłącznie własne izolowane bazy. Nie uruchamia Codexa ani Claude’a i nie zużywa ich limitów. Kody wyjścia: `0` — sukces, `1` — wykonany test nie przeszedł, `3` — wymagane modele są niedostępne. Regresje w `pytest` korzystają z kontrolowanych adapterów; taki wynik nie zastępuje pomiaru z rzeczywistym modelem.

## Dane, eksport, kopie i odtworzenie

Domyślnie wszystko znajduje się w `~/.local/share/devbrain`. Alternatywny magazyn wybierz globalną opcją przed poleceniem:

```bash
devbrain --data-dir ~/inna-pamiec engine install
```

Możesz też ustawić `DEVBRAIN_HOME`. `config.json` zawiera konfigurację, lokalny token usługi oraz ustawienia połączenia ArcadeDB; plik ma uprawnienia `0600`. `models.lock.json` zapisuje identyfikatory modeli, a `service.log` log usługi wiedzy. Runtime bazy jest w `runtime/arcadedb-26.11.1`, dane w `arcade/databases`, a log startu w `arcade/engine.log`.

Domyślne adresy to: usługa wiedzy `127.0.0.1:8765`, ArcadeDB `127.0.0.1:2480`, Ollama `127.0.0.1:11434`. Osobny magazyn wymaga własnej konfiguracji portu silnika lub jawnego połączenia z istniejącą lokalną instancją. Ustawienia `arcade_url`, `arcade_user`, `arcade_password` i `arcade_database` znajdują się w chronionym pliku konfiguracji; nie należy wypisywać ich zawartości do logów.

```bash
devbrain export ~/sklep-pamiec.json --project sklep
devbrain export ~/sklep-pamiec.md --project sklep --markdown
devbrain backup ~/devbrain-backups/reczna.devbrain.json.gz
```

Backup `.devbrain.json.gz` jest przenośnym, skompresowanym eksportem źródeł i stanu wykonanym w transakcji ArcadeDB. Obejmuje rekordy i ich wersje, graf, dane indeksów, kolejkę i kursory importu. Nie zawiera poświadczeń konfiguracji ani wag modeli. Indeksy natywnego silnika są odtwarzane z zapisanych danych. Podczas pracy usługi automatyczny backup jest wykonywany co dobę; zachowywane jest siedem ostatnich kopii. Po przerwie zaległa kopia jest wykonywana przy wznowieniu skanera. Dodatkową kopię możesz zapisać do wskazanego katalogu Windows lub na inny nośnik.

Przed odtworzeniem zakończ aktywne sesje klientów i zatrzymaj usługę:

```bash
devbrain stop
devbrain doctor
devbrain engine start
devbrain restore ~/devbrain-backups/reczna.devbrain.json.gz
devbrain
```

W wyniku `doctor` sprawdź, że **usługa wiedzy** już nie działa. Silnik ArcadeDB musi działać podczas odtworzenia. `restore` weryfikuje format kopii i przywraca dane w silniku; po przeniesieniu na inny komputer nadal potrzebujesz zainstalowanego ArcadeDB, modeli i poprawnie przypisanych katalogów projektów. Do zakończenia całego środowiska po zamknięciu sesji klientów użyj:

```bash
devbrain stop
devbrain engine stop
```

`engine stop` zatrzymuje tylko proces zarządzany dla tego katalogu danych. Polecenia zatrzymania nie usuwają bazy.

Jawne usunięcie projektu:

```bash
devbrain forget sklep --delete-project
```

Usunięcie nie zmienia istniejących backupów. Archiwum nie ma automatycznej daty wygaśnięcia.

## Diagnostyka i pomiary

Po zmianie modelu embeddingowego usługa wykrywa nowy digest i kolejkuje brakujące wektory bez zmiany źródeł. Możesz też jawnie odbudować wektory projektu; wymaga to działającej Ollama i zainstalowanego modelu embeddingowego:

```bash
devbrain rebuild-vectors sklep
devbrain jobs list sklep --state failed
```

Indeksowanie ręcznych notatek, checkpointów i dowodów weryfikacji działa również niezależnie od modelu. Wektory powstają później w kolejce GPU. Błędy importu i skanowania są widoczne w statusie usługi.

```bash
devbrain doctor
devbrain status --project sklep
devbrain benchmark sklep "Gdzie walidujemy sesję użytkownika?"
```

`doctor` sprawdza CLI, MCP/hooki, lokalny ArcadeDB, Ollama, modele i dostępność informacji GPU. `devbrain engine status` podaje stan zainstalowanego runtime i połączenia z silnikiem. `benchmark` porównuje pierwszą odpowiedź z powtórzeniem przez cache i pokazuje informacje `nvidia-smi`; nie zastępuje sprawdzenia poprawności odpowiedzi.

### Ewaluacja przypominania

```bash
devbrain eval run
devbrain eval run --clients
```

Dwadzieścia scenariuszy uruchamia rzeczywistego lokalnego agenta Ollama z BM25, indeksem wektorowym i kanonicznymi kartami źródłowymi. Obejmują decyzje bieżące i historyczne, identyfikatory, wersje, stany zadań, zależności, kryteria, ograniczenia, pochodzenie i odmowę zgadywania. Tymczasowe repozytorium Git/worktree i osobna losowa baza ArcadeDB chronią projekty użytkownika. Dane syntetyczne są usuwane po pomiarze, a raport JSON pozostaje w `evaluations` katalogu danych.

Warunek zaliczenia to co najmniej 90% trafnych faktów i brak błędu krytycznego w identyfikatorach, wersjach, statusach, pochodzeniu i izolacji. Brak modeli daje `not_run`; samo udane sprawdzenie bazy nie daje zaliczenia pamięci. Raport zawiera opóźnienia, rzeczywisty rozmiar wiadomości lokalnego modelu i liczniki tokenów, jeżeli Ollama je zwraca. Nieznany licznik jest `null`, nie zerem.

Wersja 0.3.1 pozwala modelowi jednokrotnie poprawić odpowiedź odrzuconą za format lub cytowania, w ramach tego samego limitu czasu i kontekstu. Próba poprawy korzysta ze schematu JSON i odczytanych źródeł; wynik przechodzi ponownie sprawdzenie cytatów i aktualności. Nieaktualny dowód nie staje się świeży przez poprawienie formatu. Raport syntetycznej ewaluacji zachowuje ograniczoną diagnostykę surowych odpowiedzi modelu i błędów transportu, aby można było rozpoznać przyczynę odrzucenia. Nie zawiera pełnej historii rozmów projektów użytkownika.

Wersja 0.3.2 dodaje opcjonalne `answer_schema` w API i narzędziu MCP `ask`; CLI przyjmuje `--answer-schema PLIK_JSON`. Kontrakt określa klucze i typy danych, a nie ich poprawne wartości. Obsługiwany jest ograniczony podzbiór JSON Schema: obiekty, tablice, typy proste, wymagane pola oraz proste ograniczenia długości i zakresu. Odnośniki do innych schematów i wyrażenia regularne są odrzucane. Pole `answer` w publicznym wyniku pozostaje napisem; dane strukturalne są sprawdzane i serializowane jako JSON. Niezgodna odpowiedź po jednej próbie korekty pozostaje wynikiem `partial`.

Ewaluacja 0.3.2 używa tego samego kontraktu wywołującego co publiczne API, bez przekazywania oczekiwanych wartości jako ograniczeń schematu. Raport oznacza ten tryb jako `typed_caller_contract`; wynik mierzy przypominanie z określoną strukturą odpowiedzi. Nie jest to pomiar wszystkich możliwych pytań swobodnych. Oczekiwane fakty, kryteria cytowania, izolacja i próg zaliczenia pozostają bez zmian.

Jawne `--clients` dodatkowo uruchamia trzy osobne procesy: Codex → świeży Claude → świeży Codex. Klient odczytuje prawdziwy pakiet sesji i sam wykonuje ACK przez minimalny MCP fixture. Pomiędzy etapami zmieniany jest rzeczywisty stan kroku i epoka po kompresji; stare ACK musi stracić ważność. Klient nie otrzymuje narzędzi zapisu projektu. Codex używa sandboxu `read-only`, Claude ma wyłączone narzędzia wbudowane i listę odczytowych narzędzi MCP oraz ACK. Operacje sterujące dotyczą wyłącznie tymczasowej bazy.

Opcja wymaga zainstalowanych CLI ze wspieranym logowaniem interaktywnym i zużywa istniejące limity konta. Nie konfiguruje płatnego API ani zastępczego dostawcy; zmienne kluczy API nie są przekazywane do procesu. Brak klienta, logowania, obsługiwanych opcji lub dostępnego limitu jest `not_run`. Dokładny rozmiar kontekstu klienta jest nieznany, jeśli jego protokół go nie ujawnia. Wynik tych fixture nie jest dowodem idealnego przypominania dla dowolnego projektu.

Kontrolery kwalifikacyjne 0.8 `release-tools/validate-native-account080.py` i `validate-copilot-account080.py` są przygotowane; ich bieżący wynik to **`not_run`**, nie zaliczony test kont. Uruchamia się je wyłącznie po `gate.json` ze statusem `pass`, przez `run-supervised-080.ps1`, z literalnym interpreterem osobnego venv 0.8 w `python_launcher` pliku argumentów. Sam kod wyjścia kontrolera nie zastępuje końcowego `receipt.json` po obserwacji jego wyjścia i pustego cgroup.

Minimalne argumenty kontrolera (wartości to ścieżki operatora; nie uruchamiać bez zewnętrznego nadzoru):

```text
validate-native-account080.py --execute --run-id ID --artifact-root /mnt/c/.../ID
  --source-root /home/piotr/.../frozen-devbrain --private-root /home/piotr/.cache/live080
  --arcade-dist /home/piotr/.../arcade --codex-bin /pełna/ścieżka/codex
  --claude-bin /pełna/ścieżka/claude --codex-auth /home/piotr/.codex/auth.json
  --claude-auth /home/piotr/.claude/.credentials.json

validate-copilot-account080.py --execute --run-id ID --artifact-root /mnt/c/.../ID
  --source-root /home/piotr/.../frozen-devbrain --private-root /home/piotr/.cache/live080
  --arcade-dist /home/piotr/.../arcade --auth-home /home/piotr/.local/share/devbrain
```

`--private-root` musi być istniejącym katalogiem Linux należącym do użytkownika z prawami 0700. Native kopiuje wyłącznie dwa pliki OAuth do nowego prywatnego HOME, bez globalnych MCP, ustawień, hooków i historii. Odświeżone kopie zostają tam; nigdy nie są przepisywane do oryginałów. Copilot używa istniejącego magazynu konta wyłącznie przez adapter SDK, który może naturalnie odświeżyć własny cache OAuth. Nie kopiuje całego runtime i nie otwiera produkcyjnego Store. Oba testy tworzą własny silnik i syntetyczne dane, nie uruchamiają Ollamy, potwierdzają wyjście JVM przez pidfd oraz obserwują zakończenie własnych dzieci. Raporty wymagane przez nadzór: wspólne `gate.json`, `controller-report.json`, `supervisor-report.json` oraz odpowiednio `native-results.json` albo `copilot-results.json`. Raporty nie zawierają tokenów ani surowych odpowiedzi logowania. Native wymaga dokładnie trzech zaliczonych procesów i ACK; zdarzenie PreCompact jest syntetyczne, nie jest testem rzeczywistej kompakcji klienta.

Od 0.3.3 test Codexa uruchamia osobny proces bez wspólnego demona i konfiguracji użytkownika, zachowując zapisane logowanie i sandbox `read-only`. Tymczasowa konfiguracja dopuszcza dokładnie `memory`, `read_source`, `resume_context` i `ack_resume` serwera `devbrain_eval`. Dwie ostatnie operacje mogą zapisywać stan testowej sesji; zgoda dotyczy wyłącznie jej losowej bazy i nie zmienia globalnych ustawień Codexa.

Przy wyczerpanym limicie Claude’a można jawnie pominąć go bez wywoływania klienta:

```bash
devbrain eval run --clients --skip-claude
```

To częściowy test Codex → Codex, oznaczony `codex_only_partial`; pominięta faza ma status `not_run`. Zaliczenie obu sesji Codexa nie stanowi zaliczenia przekazania przez Claude’a ani jego kompresji rozmowy. Jawny błąd limitu konta jest odróżniany od błędu kontekstu lub nieznanego błędu procesu. Gdy wcześniejszy wymagany etap jest zablokowany lub niezaliczony, kolejne procesy klientów nie są uruchamiane.

| Objaw | Co sprawdzić |
| --- | --- |
| `unavailable` w `ask` | `ollama serve`, obecność modeli, `devbrain doctor` i `service.log` |
| Źródła są zapisane, kolejka rośnie | Dostępność modelu i stan zadań; archiwum działa niezależnie od GPU |
| Zadania `failed` | Przyczynę przez `jobs show`; po usunięciu przyczyny ponów wybrane zadanie przez `jobs retry` |
| MCP niewidoczne | Ponowne `devbrain install PROJEKT`, wynik wykrycia klienta i jego zgody/zaufanie |
| Usługa nie startuje | Czy port 8765 jest zajęty, log oraz czy nie działa inny magazyn na tym samym porcie |
| ArcadeDB nie startuje | Java 21+, `devbrain engine status`, port 2480 oraz `arcade/engine.log` |
| Niepełny graf | Obsługę języka, błędy składni i nierozwiązywalne statycznie wywołania |
| Konflikt wersji rekordu | Odczyt najnowszego rekordu i ponowną aktualizację z właściwą wersją |

Rzeczywistej inferencji Ollama ani modeli Codexa/Claude’a nie uruchamiano w środowisku implementacyjnym. Testy używają kontrolowanych odpowiedzi i adapterów klientów; pomiary przypominania oraz wydajności na RTX 4080 Super wykonujesz na docelowym komputerze. Nie ma obietnicy nieskończonego kontekstu, idealnego przypominania ani stałego czasu odpowiedzi. Fragmenty pobrane przez Codexa/Claude’a zajmują ich kontekst i podlegają zasadom działania tych klientów.

## Praca nad pakietem

```bash
cd ~/src/devbrain
uv sync --locked --extra dev
uv run pytest
uv run ruff check src tests
uv run devbrain --help
```

Testy trwałości, transakcji, pełnotekstowego wyszukiwania, grafu i wektorów działają na rzeczywistym, przypiętym silniku ArcadeDB. Sesja pytest wymaga Java 21 i przygotowuje izolowaną instancję na lokalnym porcie; pierwsze przygotowanie pobiera dystrybucję silnika. Odpowiedzi Ollama i sesje kodujących klientów są kontrolowane przez adaptery testowe. Testy nie uruchamiają faktycznego programowania i nie zastępują pomiaru GPU.

Do wielokrotnego uruchamiania można przygotować osobny, izolowany silnik testowy i podać `DEVBRAIN_TEST_ARCADE_HOME`. Fixture używa oddzielnej przestrzeni nazw baz i sprząta utworzone bazy testowe. Nie wskazuj w tej zmiennej katalogu produkcyjnej pamięci.
