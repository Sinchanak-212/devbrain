# DevBrain 0.8.0 — checkpoint do nowej sesji

Zapis roboczy: 2026-11-08. To NIE jest odbiór stabilnego wydania.

## Najnowsza aktualizacja — odczytać przed starszym opisem procesu

- Najnowszy pełny checkpoint:080-handoff-checkpoint-after-canonical1557-20261108.json. Starszy plik080-handoff-live-checkpoint-20261108.json zachowano jako historię.
- Backend1557 actual5384 EXIT0 finalPASS: context1c101b5e… / reportd9515cf5… / receipt44fea7c9… .
- Kanoniczna atestacja1557 actual4727 EXIT0: SHA41642d8f3fc308c157cb801e12a0364a7e39c67df64f188287f1a4513b70dcc7; raport080-full-suite-length-repair-attestation-final-20261108.json SHAa69ed845… . Nie powtarzać.
- Bieżący jedyny workload Linux to **UX377, root exec41294**; context080-ux-length-repair-active-context-20261108.json. Czeka na actualexit i finalną weryfikację metryk/JUnit. Stary opis backendu RUNNING niżej jest historyczny.
- Nowy readonlybaseline v7 actual37492 EXIT0:182/182 exact,0missing/modified/unexpected,1 jawnie niezarządzany podkatalog bez odczytu zawartości. Raport080-source-baseline-v7-early-final-20261108.json SHA002792b82f7d627d1354e5f027ed3de1892bc291fd01651d3d41fe8bdd65868e. Powtórzyć przed apply; dawny64776FAIL zachowano.
- Limit konta **21:09UTC:37% tygodniowego pozostało**,5h niedostępny. Warunek≤5% nieosiągnięty.
- SAFE STOP i komendy:080-length-repair-durable-handoff-20261108.md, SHA18f1d05c9254a3cd5afeb6d33fff10bca738ef31a42303728737eda4fb59b89f. Per-run cancel.json, nadzór do actualexit/cleanup; bez CtrlC do pipes/global kill. Dopiero potem shutdown.exe /s /t0 bez /f.
- UIhandoff:080-ui-length-repair-handoff-ready-for-UX377-20261108.json SHA1b7e623e…; remaininggates:080-release-review-durable-handoff-20261108.md SHA688cde15… . Stare przykłady080-handoff-ui-orchestration-examples.json są NOTRUN/STALE i wymagają nowego contextu.
- Test8h NIE WYSTARTOWAŁ; prywatna produkcja zatrzymana. Backendcontext1c101 i kandydatcdd27 pozostają niezmienne.

## Nowa dyspozycja użytkownika

Monitorować **pozostały limit konta Codex**, tygodniowy i 5-godzinny, przy użyciu `mcp__codex_app__get_usage_limits`.
Wybrać właściwy bucket `codex`, preferować `rateLimitsByLimitId`; pozostało = 100 − usedPercent.
Ostatni odczyt: **39% pozostało w oknie tygodniowym (10080 minut)**. Osobnego okna 5h nie zwrócono; brak danych NIE oznacza 0%.
Sprawdzać okresowo (około 15 minut), przed próbą 8h i przed produkcją.
**Jeśli potwierdzony pozostały limit właściwego okna wyniesie ≤5%: zatrzymać pracę, zapisać aktualny handoff, domknąć własne procesy/nadzór i wyłączyć cały Windows.** Użytkownik upoważnił do tego warunkowo. Teraz progu nie osiągnięto.
Nie kupować/resetować kredytów. Nie publikować accountId, sekretów ani hashy poświadczeń.

## Bieżący stan

- Produkcyjny DevBrain **0.7.2 i prywatna baza pozostają zatrzymane**. Nie wznawiać przed wszystkimi bramkami.
- BIOS4601 / mikrocode0x133; Intel defaults, bez XMP/OC; Windows Zrównoważony. Razer Cortex zamknięty przez użytkownika.
- Runtime a6 został zakwalifikowany; Python3.12.16, Temurin21.0.13+9 z domyślnym C2, tmux3.8,59 przypiętych pakietów. Nie przestawiać systemowych programów.
- Aktualny snapshot: **app080-20261108T202627Z**,198 plików aplikacji/209 całego bundle.
- Freeze: `1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14`.
- Linux source: `/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T202627Z/project/devbrain`.
- Literalny interpreter venv: `/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T202627Z/venv/bin/python` — używać z `-I -B`, nie zastępować bazowym binarium dla testów aplikacji.
- Przygotowanie actual39447 EXIT0, receipt `4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e`,59 pins bez zmian, source198 exact, quiet32.131s, brak nowych native failures.
- Bieżący zapis JSON: [080-handoff-live-checkpoint-20261108.json](./080-handoff-live-checkpoint-20261108.json).
- Bieżący mutable status: [080-current-release-progress.json](./080-current-release-progress.json).

## Co rzeczywiście zaliczono dla tych źródeł

**Kandydat v7 — zbudowany, mechanicznie sprawdzony, jeszcze NIEQUALIFIED.**
Context `080-final-candidate-build-ready-context-v7-20261108.json` SHA `cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6`.
ZIP `4fb8b1203dfce52eb5bfd094b2649899316e09ada64cbd2dc14e1bb8de071508`;
updater `0a1cf86a23a4a0c8e0b664837e4974387cdb5e9001e011c52af179765f6c9dec`.
Actual41768 EXIT0; wszystkie198 plików ZIP i manifest exact. Nie modyfikować przyjętego contextu ani manifestu qualified:false; końcową kwalifikację zapisuje osobny indeks dowodów.

**604/604 guardy,12 modułów,38 niezmienionych helperów.**
Actual76710 EXIT0.
Context `080-guards-queue-budget-active-context-20261108.json` SHA `0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d`;
receipt `c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82`;
raport `080-guards-length-repair-final-20261108.json` SHA `e3c5362952f7d56f5dc7f5d9e45678752bf8304060c961baee8fe49c372e63b5`.

**Cała świeża kopia sześciu historycznych zadań — PASS, actual55674 EXIT0.**
Context `080-queue-copy-length-repair-active-context-20261108.json` SHA `7285aa2a59c5c27356954df208d03e3dbfbb7c210e35978d384b9628cd63f96b`;
receipt `612fe7ff7b542dc687d8f76a3f890fdd474631dfd5f5694a7db51c6a459f4644`;
raport `080-queue-copy-length-repair-final-20261108.json` SHA `19338e5db7779609154bdd0633e3dcdcc99ca9b7d25f824116302e85ff4e411b`.
Każde zadanie ukończone, dokładnie+1 próba, retry1; unrelated jobs i liczby sources/jobs bez zmian, duplikaty0→0.
Rekordy39→55. Szóste zadanie ma completed_with_omissions:6accepted,4written,2skipped. Publiczny kod przy rejection_count0 wskazuje deduplikację treści; nie twierdzić, że zapisano wszystkie propozycje.
Piąte: initial length1200 → repair stop1275; szóste: length1200 → stop1521.
**To nie są ponowienia produkcyjne.**

## Aktualny proces — wymaga ponownego odczytu, zanim cokolwiek ruszy

**Pełny backend1557 jest RUNNING, root exec session5384.**
Run `fullbackend-length-repair080-20261108T204439Z-b2a1ac34`.
Context `080-fullbackend-length-repair-active-context-20261108.json` (initial SHA `ab7a9c3073c9d9bf79a8a4f8bb14795b1ed9ef4a529df1da3a207ae34b43b831`).
Spec `7a8c3c16e7ec3238e19e95edc637819f3e2597017cf5d03e422f6cde58138e45`;
freeze `a5f46fa5a9b2f3261efc4f8b301f572ca9f21155ade95f12c9bc1a6714b20fbf`.
Pełny katalog testów, bez selektorów i pominięć, TMPDIR=/tmp, C2.
Reader: `read-fullbackend-length-repair-progress-20261108.ps1`, SHA `21c16f09c2078cb1b211103d7b8d9694b9da55540b4df87347f578e9b81486a5`.
Finalizer: `finalize-fullbackend-length-repair-20261108.py`, SHA `6fde419ca33f28487c792172a12609a7693b42703b1fa7085b251c1886fbac8b`.
Finalizacja tylko po actual5384 EXIT0, kompletnym JUnit1557 i receipt/cleanup/power/boot/native proof.
Nie uznawać postępu logu za końcowy werdykt.

Jeżeli komputer został wyłączony w trakcie próby, przerwanego testu NIE wznawiać jako zaliczonego.
Zachować stare artefakty i wykonać świeży pełny przebieg w nowym katalogu.
Jeśli sesja exec nie istnieje, nie zgadywać exit0: sprawdzić trwałe contexty, receipts, tożsamości procesów i cleanup.
Jednocześnie tylko JEDEN własny workload Linux. Windows-only przeglądy i staging mogą działać obok.

## Co jeszcze jest wymagane przed stabilnym0.8.0

1. Dokończyć obecny pełny1557 + dokładny JUnit0fail/error/skip, rzeczywiste zakończenie i obserwacja po cleanup.
2. Wygenerować nową **kanoniczną** attestację full-suite w aktualnym backendzie `artifacts/final-full-suite.json`.
   Przygotowany seed: `080-standalone-length-repair-attestation-prepared-context-20261108.json` SHA `8598f2e8e68cd91f60d609617777ee082133e82346ab95de3dcaaed549b195ce`.
   Prepare wymaga actual session5384 + final context/receiptSHA; root uruchamia niezarejestrowany directCLI pod zatwierdzonym obserwatorem, bez aliasu CONTROLLERS.
3. UX377/28 na tych samych źródłach. Context `080-ux-length-repair-active-context-20261108.json` SHA `af91a75594ee9bbfe20d1e0bab4c73ae2eaa09ffce45ddd6643c2c3b7486a204`, WindowsStage actual72076EXIT0, peer `83f289f4…`; jeszcze NOTRUN.
4. Rzeczywiste TUI:5 zadań agenta +3 geometrie80×24/120×36/180×55, EN/PL/Focus, formularze, Unicode, fokus, rozłączenia, P95≤150ms i pętla≤500ms.
   Nowy UI stager `stage-interactive-length-repair-agent-604-20261108.ps1` SHA `992ef717655b1c901e556034a32af781a092ae47fb8367523e3a70038b78bf29`;
   master `080-interactive-length-repair-agent-templates-20261108.json` SHA `5f7a9ffe5467eaa2f203986a7385fe60243da249dd6e3b023792f0b72f0c45a4`.
   Wymaga actual1557+377+copy6; jeszcze NOTSTAGED. To test AGENTA, nie człowieka.
   Trzy świeże zrzuty prawdziwego Windows Terminalu przez jawnie zatwierdzony PrintWindow, root ogląda PNG.
   Obsługa klawiaturą tylko przez normalnego klienta tmux `send-keys -K -c tty`; nie pane injection ani omijanie readonly/control.
   Baseline0.7.2 ma już3 prawdziwe PrintWindow PNG i23 artifactSHA; `080-baseline-visual-final-20261108.json` SHA `91450d6f6445a8b0c0fe2c7e7f020e245e6dee893a8f35cfa3ef344542d55e45`. Nie powtarzać.
5. Świeże realne Codex→Claude→Codex, Copilot kontem GitHub/bez APIkey/pamięć, pełne20Ollama≥90%+wszystkie fakty krytyczne, frontend10+8/build/audit0.
6. Aktualizator0.7.2→0.8.0, backup i rzeczywiste odtworzenie NA KOPII. Wymagany kwalifikowany072venv jako --backup-python przekazany updaterowi przez smoke; nie uruchamiać starego runtime.
7. **NIEPRZERWANE8GODZIN — JESZCZE NIGDY NIE WYSTARTOWAŁY.** 28800s, co900s32 chat+32embedding lokalne, TUI/pamięć/snapshoty/rozłączenia, monitoring RAM/VRAM/GPU/process/boot/native/power aż po cleanup. Zapytania kontowe poza pętlą. Wszystkie8 aktualnych bramek i canonical1557 muszą być rzeczywiście zaliczone przed Stage/Start. Po przerwaniu przez shutdown start OD ZERA, nigdy suma części.
8. Produkcja dopiero po wszystkich11 proofach: aktualizacja, backup, pełna kontrola zainstalowanego TUI, osobne produkcyjne ponowienia6 zadań pojedynczo z kontrolą prób/duplikatów i trwałym journalem. Nie powtarzać operacji o nieznanym wyniku.
9. Finalny raport i kwalifikacja lokalnego wydania; nie deklarować gwarancji braku wszystkich przyszłych błędów.

## Ważne ograniczenia i pozostałe artefakty

Nowy źródłowy preflight v7 jest dodatkowy i **NOTRUN**.
Ready `080-source-preflight-v7-ready-20261108.json` SHA `8e057d379b674991459eecfe623b92ae590bb673c9c868d031edf20c06c35b19`.
Stary readonly baseline actual64776FAIL:182 oczekiwane pliki exact,0missing/modified,1extra (normalny root build-outputdir). RawFAIL zostaje.
Cleanup dc89+QR51f1 pozwoliły na następną próbę; nie jest to awaria runtime.
Publiczny audyt wykazał, że dokładny rootdist jest niezarządzanym wyjściem kompilacji; nowy checker pomija tylko rzeczywisty ownednormaldir, bez listingu dzieci, z nofollow/identity/collision guards. Inne extra pozostają błędem. Nie usunięto/zmieniono prywatnego katalogu.
Nowy baseline072 należy wykonać, powtórzyć tuż przed apply, a pełny target198 po apply/przed wznowieniem. To sprawdzenie punktowe; brak równoległych edycji podczas apply.

Historyczne PASS dla160614 i192100 są wyłącznie historyczne; nie sumować ich jako odbioru nowych źródeł.
Bieżący kod zawiera naprawy:120/125/210 budżety, walidację Task.state przed transakcją+1repair, length-only repair max3600.
Pierwsza próba length1200, jedyny repair max2×initial; ordinary417 i ASK bez zmian. Drugi length odrzucany przed parsowaniem i commitem.

Nie wykonywać BIOS/firmware/system-default zmian, nie usuwać historycznych dowodów, nie commit/push/publikować na GitHub bez polecenia.
Zachować wszystkie niezacommitowane pliki użytkownika.
Nie eksportować sekretów, principal/accountId, hashy poświadczeń, pamięci procesów, prywatnych źródeł/modeloutput/SQL.

