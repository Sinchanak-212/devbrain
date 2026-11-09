**Bieżący zakres: dokończyć testy przed 8h, zapisać przekazanie i wyłączyć cały PC. Próby 8h NIE URUCHAMIAĆ w tej sesji.**

Stan punktowy: 2026-11-08T21:38:16.241159+00:00. Root wykonuje jedyny workload Linux i jako jedyny może wyłączyć komputer. Wcześniejszy warunek przerwania przy limicie Codex ≤5% nadal obowiązuje. Produkcja 0.7.2 pozostaje zatrzymana; 0.8.0 nie jest jeszcze zakwalifikowane jako stabilne.

Aktualne źródła: app080-20261108T202627Z, freeze `1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14`. Potwierdzone:604 guardy,1557 backend + kanoniczna attestation41642d8f,UX377/28 oraz cała kopia6. UI77868 jest w tym punkcie nadal bez finalnego PASS; native/Copilot/Ollama20/frontend/finalny smoke pozostają NOT_RUN. Historycznych PASS innych źródeł nie łączymy.

NEXT5 ma finalny niezależny ACK. Dopiero po actual UI PASS, actual exit, OAuth sync/release i cleanup root może wykonać Windows-only Stage z dokładnymi czterema parametrami UI, a potem kolejno pięć testów. Stage nie uruchamia żadnego workloadu. Trzy hashe UI muszą pochodzić z ukończonych dowodów, nie z aktywnego procesu.

```powershell
pwsh -NoProfile -File "C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\stage-five-length-final-gates-after-ui-20261108.ps1" -Stage -UiContext "<ACTUAL_CURRENT_UI_CONTEXT>" -UiContextSha256 <ACTUAL_SHA256> -UiReceiptSha256 <ACTUAL_SHA256> -UiFinalReportSha256 <ACTUAL_SHA256>
```

Po pięciu testach zapisać NOWY kompletny proofmanifest i finalny handoff; nie modyfikować przyjętych dawnych kontekstów. 8h v2 jest jedynie przygotowane dla NASTĘPNEJ sesji. Po ponownym uruchomieniu PC trzeba świeżo zweryfikować boot, kwalifikowane binaria/launcher, Balanced/fingerprint, brak nowych błędów native/kernel/dump i brak obcego workloadu. 28800s/900s/32chat+32embedding/GPU5s to jeden ciągły przebieg; wyłączenie lub przerwanie oznacza nowy pełny przebieg, bez sumowania. Zapytania kont pozostają poza pętlą 8h.

V7 ZIP4fb8/updater0a1c/manifestf15a pozostają niezmiennym mechanicznym kandydatem qualified=false. Source-preflight V7 z zamkniętą regułą unmanaged root dist jest nadal NOT_RUN. Historyczne64776 FAIL182equal+unexpected1 pozostaje FAIL; dc89/51f1 dowodzi wyłącznie zakończenia procesu. Przed wdrożeniem potrzebny świeży baseline182, po wdrożeniu cały target198 przed resume.

Produkcja wymaga wszystkich11 proofów (łącznie soak), kwalifikowanego niezależnego backup-python0.7.2 z końcowego aktualnego smoke, nadzorowanego deploy, post-update backup oraz pojedynczych świadomych ponowień6exactID. Te kroki nie są wykonywane w tej sesji przed 8h. Unknown outcome blokuje powtórkę. Zachować konta, modele, profile, przypisania i pamięć.

Dokładne bieżące wskaźniki:

- NEXT5 ready: [080-five-length-final-gate-materializer-ready-context-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-five-length-final-gate-materializer-ready-context-20261108.json>) — `98d1df0b8cea6b857229877ae0ae57711fe9ba804e8794ac4ee147e2a450b1be`
- Pełny bieżący handoff JSON: [080-pre-eight-hour-shutdown-scope-handoff-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-pre-eight-hour-shutdown-scope-handoff-20261108.json>) — `adee688577de3963d2070dd2568120fae75745695e4fdc39b4f84fd34141ab3e`
- Actual proof checkpoint: [080-length-repair-eight-hour-proof-manifest-after-ux-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-length-repair-eight-hour-proof-manifest-after-ux-20261108.json>) — `e494c73a75c42a658fdca6f66a02dfc38e6db43686cb27f9e0e46e2a3d37a4ed`
- 8h v2 ready — NIE uruchamiać teraz: [080-length-repair-eight-hour-materializer-v2-ready-context-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-length-repair-eight-hour-materializer-v2-ready-context-20261108.json>) — `37920616ec8d669ca5c0e713c91929774cef2f30b25f6a489ed8b2a16428c972`
- V7 source-preflight: [080-source-preflight-v7-ready-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-source-preflight-v7-ready-20261108.json>) — `8e057d379b674991459eecfe623b92ae590bb673c9c868d031edf20c06c35b19`
- V7 candidate: [080-final-candidate-build-ready-context-v7-20261108.json](<C:/Users/piotr/OneDrive/Dokumenty/ChatGPT/devbrain/evidence/080-final-candidate-build-ready-context-v7-20261108.json>) — `cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6`

Ten zapis nie uruchomił Stage/Linux/produkcji, nie odczytał poświadczeń i nie zmienił frozen198/frozen38 ani historycznych wyników. Root uzupełni kolejne actual wyniki w nowym końcowym przekazaniu przed wyłączeniem.
