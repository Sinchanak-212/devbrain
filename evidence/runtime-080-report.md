# Runtime 0.8.0 — bramka zablokowana

Stan historyczny pierwszej serii: 2026-11-07. **Nie zatwierdzać pełnego obciążenia, Ollama20, produkcyjnej bazy ani soak na podstawie tych wyników.** Zmiana runtime w tej serii nie usunęła wszystkich awarii. Dalsze ustalenia programowe i nowa, osobna kwalifikacja są opisane w `runtime-080-software-report.md`. Historyczny gate pozostaje zablokowany.

## Wprowadzone zmiany

- `ArcadeClient` dopuszcza wyłącznie HTTP na 127.0.0.1/localhost/::1, wiąże endpoint i poświadczenia z instancją, odrzuca obce/niejednoznaczne ścieżki i przekierowania. `verify=False` dotyczy wyłącznie tego transportu HTTP. Provider HTTPS nadal używa weryfikowanego kontekstu. Cykl klienta per request i serwerowe sesje transakcji pozostały zachowane.
- `Settings.java_executable` i `DEVBRAIN_JAVA_EXECUTABLE` wybierają absolutną binarkę tylko dla danego środowiska. Błędny jawny wybór nie przechodzi po cichu na PATH. Brak ustawienia zachowuje PATH. Start wymaga poprawnego exit code i Java >=21.
- `engine status` i `doctor` rozróżniają wybraną Javę od binarki istniejącego, zweryfikowanego procesu `/proc/PID/exe`. Doctor pokazuje także binarkę Pythona i wersję OpenSSL.
- Produkcyjna konfiguracja, prywatna baza, update-alternatives, BIOS i sterownik pozostały nietknięte.

## Dowody

| Próba | Wynik | Ograniczenie |
|---|---|---|
| Nowe testy transportu/runtime | 40/40 PASS | Izolowane testy granic, bez sieci i JVM |
| Ubuntu CPython3.12.3/OpenSSL3.0.13 | 20/20 bounded SSL PASS | Nie odtworzyło wcześniejszej awarii |
| Prywatny CPython3.12.16/OpenSSL3.5.9 | 20/20 bounded SSL PASS | Zmieniono jednocześnie interpreter, build/compiler i OpenSSL |
| Pełne test_evaluation + test_native_evaluation | 32/32 PASS,39.17s | Temurin21.0.13+9, rzeczywisty C2, bezC1 |
| Docelowe56, świeża JVM0 | 56/56 PASS,78.46s | Później wykryto fatal procesu potomnego w tej serii; sameJUnit nie są bramką stabilności |
| Docelowe56, świeża JVM1 | 56/56 PASS,81.70s | C2 potwierdzony; maksymalnyHWM497436KiB |
| Docelowe56, świeża JVM2 | Przerwano po wykryciu core | CelowySIGINT koordynatora; własnaJVM i osierocony testowytmux zatrzymane |

Każda seria SSL obejmowała16500operacji: tworzenie SSLContext, CAcertifi, CAsystem, httpxverified oraz ograniczony klientHTTP;100/1000iteracji na1/2wątkach. Limit pojedynczego child120s/512MiB, bez połączeń i modeli. Żadna próba SSL nie zakończyła się fatalem.

Przed właściwymi powtórzeniami zachowano dwa nieudane przebiegi organizacyjne: brak editable instalacji projektu dla child `-I` oraz test starej geometrii oczekujący domyślnego cockpit. Naprawiono instalację prywatnego snapshotu i jawny tryb fixture; nie powtarzano żadnego wykrytego crasha.

## Nowy fatal prywatnego Pythona

Windowszapisał core o11:56:19+01:00: `wsl-crash-1794048979-10985-_home_piotr_.cache_devbrain-runtime-080_runtimes_python_bin_python3.12-11.dmp`. SHA256: `cc35259c3f2d915fa9066d11526b640644bf631bbfa9dd734cf54220ce07118c`.

WSLCaptureCrash wskazujePID10985/signal11; kernel log używaPID18767. IP0x1614ff1, odczyt spodNULL. Zapisane ctime w dmesg pokazuje11:56:36; nie zakładamy identyczności zegarów do sekundy. BootID `19058685-ffde-45e1-a471-b0912f9b4bd8`.

Nagłówek core: prywatny Python `-I -m devbrain…`. Natywny stos zawiera `_PyEval_EvalFrameDefault → PyEval_EvalCode → builtin_exec → PyImport_ImportModuleLevelObject`. GDB zgłasza także `Loadable section .dynstr outside of ELF segments` i `core file may not match specified executable file`; dlatego dokładną symbolizację należy traktować ostrożnie. Kernel niezależnie potwierdzaSIGSEGV iIP. Binarne pliki Pythona i Javy porównano z członkami oficjalnie zweryfikowanych archiwów: oba identyczne bajtowo.

Stare core także odczytano bez argumentów,locals,zmiennychśrodowiska i zrzutów pamięci. SIGSEGVUbuntuPython zawiera `pthread_rwlock_unlock → CRYPTO_THREAD_unlock → EVP_KEYMGMT_is_a → OSSL_DECODER_from_bio/data`. StarySIGABRT zawiera `abort`/ramkilibc i kończy się ostrzeżeniem o uszkodzonym stosie przylibcrypto. To dowody miejsc awarii, nie rozstrzygnięcie jej źródła. `dpkg -V` dla systemowegoPythona/OpenSSL/libc/JRE nie wykazało zmienionych plików.

## Decyzja

Kandydat pozostaje **niezakwalifikowany do wdrożenia**. Zapis `runtime-080-gate.json` ma `status=blocked`, `root_cause_established=false`, `production_or_soak_authorized=false`. JDKC2 nie uległ awarii podczas tych ograniczonych prób, ale całe środowisko nadal ma potwierdzony fatal nowego Pythona. PASS podC1 ani PASS nadrzędnego pytest nie zastępuje obserwacji procesów potomnych.

Użytkownik następnie wykluczył zmiany BIOS/firmware. Nie wykonano ani nie zaplanowano restartu Windows ani zmian ustawień CPU/zasilania. Dalsza diagnostyka dotyczy wyłącznie oprogramowania i prywatnych runtime. Nie stwierdzono usterki CPU, DIMM ani BIOS.

Warunki odblokowania kolejnych etapów: zero nowych core/SIGSEGV/SIGABRT/OOM/panic i nieoczekiwanych zgonów child,3kompletne świeże przebiegi56 zC2, pełne32evaluation, pełny aktualny suite oraz kontrolowany teardown. Dopiero potem osobno zatwierdzony monitoring8h; Ollama20, produkcyjnyUI i naprawa6historycznychjobs wymagają własnych bramek danych i funkcjonalności.

## Pliki i źródła

Artefakty wtym katalogu: `runtime-080-gate.json`, `runtime-080-unit.xml`, `runtime-080-ssl-*.json`, `runtime-080-evaluation-0-pytest.xml`, `runtime-080-final-c2-final-*-pytest.xml`, `runtime-080-final-java-tests.json`, `runtime-080-candidate-fatal.json`, `runtime-080-native-*.txt`, `runtime-080-dmesg-crashes.txt`. Pełne C2compilelogs pozostają w `/home/piotr/.cache/devbrain-runtime-080/c2-final/evidence/`; manifest snapshotu i wyjściajcmd zapisano obokJUnit. Powtarzalny helper: `release-tools/diagnose-runtime-080.py`.

Oficjalne źródła: [Python3.12.16](https://www.python.org/downloads/release/python-31216/), [HTTPXSSL](https://www.python-httpx.org/advanced/ssl/), [Adoptiumarchive verification](https://adoptium.net/installation/archives). Dokładne URLarchiwów i oficjalneSHA są w `runtime-080-archives.json`; runtimecache jest prywatny i nie zmienia systemowych pakietów.
