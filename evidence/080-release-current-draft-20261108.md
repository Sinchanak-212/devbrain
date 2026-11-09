**DRAFT — DevBrain 0.8.0: bieżąca kwalifikacja, 2026-11-08**

Stan zapisany 2026-11-08T20:54:30.006098+00:00. To raport przygotowania i wyników cząstkowych; wydanie nie jest jeszcze zakwalifikowane ani wdrożone. Produkcyjna baza i usługi pozostają zatrzymane. Jedynym aktywnym obciążeniem Linux jest pełny backend, sesja root **5384**.

| Bieżący artefakt | Dokładne powiązanie |
|---|---|
| Źródła | `app080-20261108T202627Z`, 198 plików aplikacji / 209 zamrożonych wejść |
| SHA zamrożenia | `1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14` |
| Przygotowanie środowiska | actual EXIT0; receipt `4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e`; 59 identycznych przypiętych pakietów |
| V7: kontekst wykonanej budowy | `cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6`; mechaniczny kandydat, `qualified=false` |
| ZIP 0.8.0 | `4fb8b1203dfce52eb5bfd094b2649899316e09ada64cbd2dc14e1bb8de071508` |
| Aktualizator 0.8.0 | `0a1cf86a23a4a0c8e0b664837e4974387cdb5e9001e011c52af179765f6c9dec` |
| Manifest kandydata | `f15ac4aa5640545455dacbf70333282c4d154a3b37647f29cb70db2f7f1df44d` |

Środowisko: prywatny Python 3.12.16, Temurin 21.0.13+9 z domyślnym C2, tmux 3.8, ArcadeDB 26.11.1. Dokładne ścieżki i SHA trzech binariów wiąże runtime gate `a6bd365cea68986ed6795990272c766679bbd29fd9407e904a12c2956bcdf7fb`. Kwalifikowany profil Windows Balanced ma fingerprint `6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1`; BIOS 4601, mikrokod 0x133, zgodnie z zapisanym kontekstem post-BIOS. Nie wolno odziedziczyć ustawień JVM wymuszających C1. Raport nie przypisuje wcześniejszych awarii jednej nieudowodnionej przyczynie.

| Bramka bieżących źródeł | Stan i kryterium |
|---|---|
| Tooling guards | **PASS 604/604**, 12 modułów / 38 helperów, 0 failures/errors/skips/duplicates/missing. Root 76710 actual EXIT0; kontekst `0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d`, receipt `c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82`. Pusty własny scope 32.833 s + obserwacja zewnętrzna 35 s; bez forced cleanup/native/boot/power delta, blokada uśpienia zwolniona. |
| Pełna kopia sześciu zadań | **Raw PASS, finalny raport QR pending**. Root 55674 actual EXIT0; import/extract po 3, świeża izolowana kopia oryginalnego backupu, całe sześć od początku. Receipt `612fe7ff7b542dc687d8f76a3f890fdd474631dfd5f5694a7db51c6a459f4644`; cleanup true, forced false, scope 32.696 s + outer 36 s. Kryteria: wszystkie sześć zakończone, kontrola duplikatów i niezwiązanych zadań, bez zmian produkcji. |
| Pełny backend | **RUNNING**, root 5384; wymagane 1557 przypadków w jednej pełnej kolekcji, exact nodeids JUnit, 0 pominięć/błędów, zgodny xunit1 i cleanup. Nie przypisano PASS. |
| UX | **PENDING**: pełne 377 przypadków / 28 modułów, bez selektorów i pominięć; latency i nodeids w JUnit. |
| Interaktywny interfejs | **PENDING**: 5 zadań + 3 rzeczywiste geometrie TTY, osobne PNG okien Windows. Operator **agent**, nie człowiek; nie nazywać tego badaniem użytkownika. |
| Codex → Claude → Codex | **PENDING**: dokładnie 3 nowe rzeczywiste procesy, odczyt pamięci, packet ACK i unieważnienie wcześniejszych ACK. `real_native_compaction_tested=false`: zdarzenie precompact jest syntetyczne; brak dowodu rzeczywistej kompakcji CLI. |
| Copilot | **PENDING**: rzeczywiste autoryzowane konto, zapis/odczyt pamięci w izolowanym projekcie; prywatna baza produkcyjna nie jest otwierana. |
| Recall Ollama | **PENDING**: wszystkie 20 scenariuszy wykonane, oryginalny scorer ≥90% i wszystkie krytyczne; monitor zakończony. Celowe odpowiedzi `partial` dla odmowy/izolacji ocenia oryginalny scorer — nie udawać 20 odpowiedzi `complete`. |
| Frontend | **PENDING**: świeże npm ci, unit/build/Playwright, oba audyty, manifest źródeł i assets; własny scratch/serwer, CI=1, GPU off, bez mutacji web_static. |
| Upgrade smoke 0.7.2 → 0.8.0 | **PENDING**: aktualny V7, kwalifikowany osobny wheelvenv 0.7.2, rzeczywisty backup/restore, dokładne dane/wektory i właściwy reset journalu, konta/profile/modele/preferences, idempotencja oraz własna JVM i cleanup. |
| Stabilność 8h | **NOT_STARTED**: 28800 s bez przerwy, cykl 900 s, 32 chat + 32 embedding; rzeczywisty TUI, ACK, snapshoty, detach/resume. RAM, VRAM/GPU co 5 s (query ≤3 s, luka ≤15 s), boot/power/native do końca cleanup i zewnętrznego ogona. Zapytania do kont natywnych są poza pętlą 8h. Blokada uśpienia obowiązuje tylko podczas próby. |
| Produkcja | **NOT_APPLIED / NOT_RETRIED / NOT_RESUMED**. Dopiero komplet dowodów, świeże porównanie źródeł, backup, kontrolowane apply, backup po aktualizacji, pojedyncze CAS retry i końcowy zainstalowany TUI/doctor. |

PASS oznacza również faktyczne zakończenie kontrolera i supervisora, pusty własny scope, brak wymuszonego sprzątania i co najmniej 30 s obserwacji po zakończeniu. JSON kontrolera ani postęp kropek pytest samodzielnie nie wystarcza. Pięć wcześniejszych fixture'ów nadzoru `d466…` zachowuje wyłącznie zakres niezmienionego kodu nadzoru; nie kwalifikuje nowych źródeł aplikacji.

Dawne wyniki źródeł 192100 (1537 backend) i 160614 (UI/native/Ollama itd.) pozostają historyczne. Nie są sumowane, przepisywane ani podstawiane za bieżące wyniki 202627. Poprzednie błędne kopie kolejki również pozostają FAIL; bieżące sześć wykonano od początku. Aktualna polityka ekstrakcji zachowuje budżet 120 s / outer 125 s / lease 210 s; tylko `done_reason=length` zwiększa limit pojedynczej naprawy do `min(2*initial,3600)`, bez drugiej naprawy i bez zapisu niepoprawnego wyniku.

Porównanie źródeł produkcyjnych: historyczne **64776 FAIL** zachowane — 182/182 oczekiwane pliki identyczne, 0 missing/modified, jeden dodatkowy katalog. To różnica inwentarza, nie awaria natywna; osobny SAFE_NEXT nie zmienia FAIL. Nowa procedura V7 ma publiczny dowód, że dokładny root `dist` jest poza manifestem/wheel package selector i 60 ścieżkami aktualizatora. Zachowuje zwykły własny katalog jako **unmanaged**, bez czytania dzieci; odmawia symlink/reparse/wrong type/kolizji/podmiany, a inne nieznane wpisy nadal blokują. **V7 baseline i target NOT_RUN**: wymagane świeże 182 przed wdrożeniem i całe 198 po nim przed resume. Gotowość `8e057d37…` nie daje zgody na nadpisanie nieznanych zmian.

Końcowy manifest admission nie został jeszcze złożony. Poniższe 11 dokładnych pól pozostaje NULL; znane wyniki wyżej nie zastępują hash-bound końcowego manifestu:

```json
{
  "proofs": {
    "full_suite": null,
    "soak": null,
    "ux": null,
    "frontend": null,
    "recall": null,
    "native": null,
    "copilot": null,
    "interactive": null,
    "queue_copy": null,
    "upgrade_smoke": null,
    "tooling_guards": null
  },
  "canonical_1557_attestation": null,
  "canonical_1557_attestation_sha256": null,
  "eight_hour_receipt": null,
  "eight_hour_receipt_sha256": null,
  "eight_hour_attestation": null,
  "post_update_backup": null,
  "production_deployment_receipt": null
}
```

Kanoniczna attestation 1557 musi powstać jako `ACTUAL_BACKEND_ARTIFACT_ROOT/final-full-suite.json` dopiero po actual PASS i receipt, z oryginalnym kwalifikowanym source root. Aktualne przygotowanie pozostałych bramek: master `c9576982…`, warunkowy 8h materializer `529efc49…` (peer `2c7258a1…`). Żadnego `--execute` dla 8h ani operacji produkcyjnych na podstawie tego DRAFT.
