# Archiwum: lokalny kokpit przeglądarkowy DevBrain 0.5

Domyślnym interfejsem od 0.6 jest [środowisko terminalowe](TERMINAL.md), uruchamiane przez `devbrain` albo `devbrain tui`. Ten dokument opisuje zachowany interfejs przeglądarkowy, otwierany wyłącznie jawnym poleceniem `devbrain cockpit open`. Nie jest wymagany do pracy w terminalu.

## Uruchomienie i procesy

Po zainstalowaniu DevBrain uruchom z dowolnego katalogu:

```bash
devbrain cockpit open
```

Polecenie uruchamia lokalne usługi i otwiera kokpit w przeglądarce Windows lub Linux. Wymagane są Java 21+, przypięty ArcadeDB oraz **tmux 3.4+ w tej samej dystrybucji WSL**. Na Ubuntu 24.04 tmux zainstalujesz przez `sudo apt install tmux`. Node.js jest potrzebny do rozwijania frontendu, a nie do korzystania z gotowego pakietu.

Jeżeli przeglądarka nie otworzyła się automatycznie, skorzystaj z adresu wypisanego przez polecenie. Adres startowy zawiera jednorazowy, krótko ważny bilet; przeglądarka zamienia go na lokalną sesję i od razu usuwa fragment z paska adresu. Nie publikuj tego adresu. Usługa nasłuchuje wyłącznie na loopback; nie wystawiaj jej na sieć lokalną ani Internet.

```bash
devbrain cockpit open --no-browser
devbrain cockpit status
```

`devbrain tui` uruchamia aktualne środowisko terminalowe opisane w [TERMINAL.md](TERMINAL.md). Polecenia `project`, `run`, `ask`, `plan`, `check`, `memory`, `backup` i `restore` pozostają dostępne.

Samo otwarcie lub przeładowanie strony przywraca widok i dołącza istniejące terminale. **Nowy proces uruchamiasz jawnie wyborem projektu lub przyciskiem „Połącz klientów”.** Domyślne panele to Codex i Claude. Zmiana projektu, ukrycie panelu oraz zamknięcie przeglądarki odłączają widok i zachowują procesy w tle. Po wyłączeniu WSL procesy nie działają; pamięć można odtworzyć przy kolejnym uruchomieniu.

Dla zakończonego procesu dostępne są jawne akcje **Wznów sesję** i **Nowa sesja**. Wznowienie wymaga zweryfikowanego identyfikatora natywnej sesji; przy jego braku kokpit pokaże `native_resume_unavailable`, a nową sesję wybierasz osobno. Otwieranie strony nigdy samo nie wznawia pracy.

Przycisk zatrzymania w panelu lub lista **Sesje** kończy wskazany proces. Przerwanie bieżącej operacji i zatrzymanie całego procesu są oddzielnymi działaniami. Możesz również jawnie zatrzymać kokpit:

```bash
devbrain cockpit stop
devbrain cockpit stop --clients
```

Pierwsze polecenie odłącza kokpit; `--clients` zatrzymuje także jego zarządzane procesy. Baza i lokalna usługa wiedzy mają dotychczasowe polecenia zatrzymania.

## Projekty, profile i logowanie

Lewy panel pokazuje wszystkie zarejestrowane projekty, niezależnie od katalogu, z którego wywołano `devbrain`. Wybierz projekt i właściwy worktree. Codex oraz Claude pracują w tym samym wskazanym katalogu; kokpit nie tworzy samodzielnie osobnych worktree i nie przydziela im automatycznie wspólnego zadania.

**Znajdź projekty** przeszukuje wyłącznie jawnie podane katalogi Ubuntu lub ścieżki Windows dostępne przez `/mnt/...`. Możesz zatrzymać skanowanie. Wykrycie katalogu nie uruchamia klienta ani nie importuje znalezionej pamięci. Projekt rejestrujesz przyciskiem **Dodaj** albo formularzem **Dodaj projekt**. Jeśli katalog zawiera `.memory/devbrain/`, kokpit najpierw oferuje sprawdzenie i wczytanie pamięci, bez rejestrowania nowego identyfikatora projektu. Dotyczy to również ręcznie wpisanej ścieżki. Uszkodzony snapshot pozostaje widoczny jako problem importu; nie jest traktowany jak brak pamięci. Rejestrację z nową tożsamością można wybrać osobno i jawnie.

W **Ustawieniach środowiska** zapiszesz domyślny układ lub układ jednego projektu: jeden Codex, jeden Claude albo kilka paneli obsługiwanych klientów. Profil zawiera nazwę, rodzaj natywnego klienta i opcjonalny identyfikator modelu. Model otrzymuje oryginalny CLI; istniejąca sesja zachowuje własny kontekst i konfigurację. Zmiany profilu stosuje się przy następnym uruchomieniu procesu. Wersja 0.5 obsługuje natywnych klientów; silnik programującego agenta API i automatyczny koordynator nie są częścią tej wersji.

**Stan połączenia / logowanie** pokazuje oddzielnie dostępność programu, deklarowany stan logowania, łączność i znany limit. Samo sprawdzenie stanu nie wysyła płatnego zapytania do modelu. Zalogowany klient może mieć wyczerpany limit; błąd sieci nie oznacza wylogowania.

**Otwórz logowanie** uruchamia oryginalną procedurę Codexa lub Claude’a w osobnym terminalu operacyjnym. Ten terminal, kody urządzenia i informacje uwierzytelnienia nie trafiają do pamięci projektu ani grafu. Po zakończeniu użyj **Sprawdź stan**. Instalację brakującego programu wykonujesz według oficjalnej instrukcji danego klienta w tej samej dystrybucji WSL.

## Terminale i potwierdzenie pamięci

Panele zawierają rzeczywiste interfejsy Codex CLI i Claude Code. Dialogi uprawnień, zaufanie projektu, MCP i hooki pozostają natywne. DevBrain nie włącza trybów pomijających zgody.

Jeden widok steruje daną sesją. Kolejne karty mogą ją oglądać; **Przejmij sterowanie** jawnie przenosi kontrolę. Rozmiar panelu zmienia rozmiar terminala. Ponowne połączenie odtwarza bieżący ekran i ograniczoną historię terminala; pełnym archiwum rozmów pozostaje pamięć źródłowa, nie bufor przeglądarki.

Znaczek ACK pokazuje stan rzeczywiście zweryfikowany przez usługę:

- **ACK wymagany** — klient nie potwierdził aktualnego pakietu.
- **ACK potwierdzony** — serwer ma poprawne potwierdzenie dokładnego pakietu.
- **Pakiet partial / unavailable** — nie ma gotowego pakietu do potwierdzenia.

Dołączenie terminala i wyświetlenie kontekstu nie są ACK. ACK potwierdza odbiór oraz odczyt identyfikatorów i wersji, a nie rozumienie przez model. Zmiana kodu przez drugi panel może wymagać nowego odczytu i ACK. W obu panelach nadal obowiązują istniejące kontrole aktualności i wersji pamięci.

Automatyczne przejęcie schowka przez sekwencje terminala OSC 52 jest wyłączone. Zaznaczanie i kopiowanie tekstu gestem użytkownika pozostaje dostępne.

## Inspektor, graf i snapshoty

Dolny lewy panel pokazuje ustalenia, źródła, plany/zadania, zapisane testy, kolejkę i snapshoty. Zakładka **Kolejka** pokazuje oczekujące operacje, błędy importu lub ekstrakcji oraz szczegóły prób; sam podgląd nie ponawia zadań. Możesz odczytać pełną treść i kolejne fragmenty dużego źródła, obejrzeć surowy zapis oraz metadane i historię wersji. Widok testów jest tylko odczytem; nie uruchamia ani nie odzyskuje sprawdzeń.

**Potwierdź** i **Zakwestionuj** zmieniają pewność ustalenia z kontrolą aktualnej wersji. Zakwestionowanie wymaga uzasadnienia. Dla zarządzanego kroku kontrolowana jest również wersja planu. Zmiana pewności nie kończy zadania i nie tworzy dowodu świeżych testów. Przy konflikcie odczytaj nowy stan przed ponowną świadomą oceną.

**Nieprzypisane wpisy** są widoczne globalnie w osobnym widoku. Nie są dołączane do wybranego projektu ani przenoszone między projektami przez sam odczyt.

Graf pokazuje rzeczywiste źródła, wiadomości, rekordy, plany i powiązania. W dużym zbiorze stosuje grupowanie oraz ograniczony widok do 2000 węzłów i 5000 relacji; grupy można rozwijać, przeglądać ich kolejne strony oraz wybierać z pełnej listy grup. Pełne dane pozostają dostępne przez inspektor i stronicowane listy. Kliknięcie węzła otwiera jego dane lub źródło. Przycisk globu przełącza między projektem a całą lokalną pamięcią. Pamięć różnych projektów pozostaje rozdzielona.

Scenę możesz obracać, przybliżać i zatrzymywać. Układ sił oblicza osobny Web Worker; aktualizacje zachowują identyfikatory węzłów i kamerę. Ustawienie systemowe ograniczania ruchu wyłącza automatyczny ruch, a przy niedostępnym WebGL dostępny jest widok listy.

Zakładka **Snapshot** udostępnia podgląd i zapis `.memory/devbrain/`, stan oraz opt-in automatu. Globalny przycisk **Wczytaj pamięć** działa także bez zarejestrowanego projektu: jawny katalog docelowy, sprawdzenie importu, następnie wczytanie. Wykrycie snapshotu niczego nie importuje. [Zasady pamięci przenośnej, konfliktów i historycznych testów](README.md#przenośna-pamięć-projektu).

Gdy usługa pamięci jest niedostępna, inspektor i graf pokażą problem; istniejące terminale mogą nadal działać. Ich wejście/wyjście nie czeka na GPU ani zapytania modelu wiedzy.

## Rozwijanie i sprawdzanie interfejsu

Frontend React/TypeScript jest w katalogu `frontend`. Zależności są przypięte przez `package-lock.json`, a produkcyjne zasoby są dołączone do pakietu Python. Nie ma zewnętrznych CDN ani zdalnych fontów.

```bash
cd frontend
npm ci
npm run test
npm run test:browser
npm run build
```

Testy jednostkowe sprawdzają m.in. jednorazowy bilet, CSRF, kodowanie terminala, prawdziwość oznaczeń ACK, wersje ocen i odrzucanie opóźnionych danych innego projektu. Testy Playwright korzystają z jawnych fixture’ów kontraktowych i lokalnego Chromium (`CHROMIUM_PATH` może wskazać inny plik wykonywalny). Nie uruchamiają płatnych klientów. Budowanie zapisuje gotowe zasoby w `src/devbrain/web_static/`; test integracyjny HTTP/WebSocket/tmux z rzeczywistym backendem jest oddzielną weryfikacją transportu.
