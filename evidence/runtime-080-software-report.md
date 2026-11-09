# Software runtime qualification — blocked

2026-11-07, Europe/Warsaw. This is a new qualification, separate from the historical Python 3.12 gate. The selected software candidate is CPython 3.13.18 with the classic GIL, Temurin 21.0.13+9 with normal C2, and private tmux 3.8. Production configuration and its database are unchanged. The user excluded BIOS/firmware changes. No Windows restart or power/CPU changes were performed or scheduled.

## Concrete tmux defect and correction

Three independently recorded system tmux 3.4 cores (PIDs 1171, 747, 98183) have the same symbolized chain: `options_tree_RB_MINMAX → options_free → window_destroy → window_remove_ref → notify_callback → cmdq_next`. Their source line references match the installed Ubuntu build ID. This matches the upstream zoomed-window destruction/notification defect [PR3860](https://github.com/tmux/tmux/pull/3860).

The current official tmux 3.8 tarball, SHA256 `e79c699c7e949dccd0a4a125e17b8d1261e311b16979dbc8eb34542f3966d82e`, also contains the later upstream [b25af0 fix](https://github.com/tmux/tmux/commit/b25af0a08ca7077fab88ec814cc8fcb57016a648) for [PR5591](https://github.com/tmux/tmux/pull/5591). Its `window_destroy` resets layout state directly instead of calling `window_unzoom`. An earlier suspicion based only on release/commit dates was withdrawn after inspecting the actual SHA-pinned archive. The private build uses unmodified upstream source, with dependencies extracted under the private cache rather than installed globally.

Three fresh tmux servers each completed 21 zoomed-window destructions (63 total) and clean shutdown. No new core appeared, including the cleanup observation period. This validates that bounded tmux scenario; it does not establish overall host stability.

`Settings.tmux_executable`, environment override `DEVBRAIN_TMUX_EXECUTABLE`, and shared `resolve_tmux` now select a canonical executable. Invalid explicit choices fail without fallback. NativeRuntime, native attachment and doctor use that selection. The parent owns the corresponding WorkspaceManager/graph integration. Transport/runtime regression tests: **51/51 PASS**.

## New Python fatal

Candidate prerequisites passed: 20 bounded SSL cases (16,500 context/CA/httpx operations), 32 fresh import/eval/minimal-Textual children, and the tmux teardown cases above. Both `Py_GIL_DISABLED=0` and `sys._is_gil_enabled()=true` were recorded before and after imports.

The next qualification planned 3×56 previously problematic cases plus both evaluation modules (32 cases), serially with one private JVM. It stopped in the first run: 25 completed pytest dots, followed by the first terminal workspace fixture. **These dots are not a complete JUnit result and are not counted as qualified passes.**

At approximately 12:24:12 local time, a sidebar Python child aborted. Core: `wsl-crash-1794050652-106645-_home_piotr_.cache_devbrain-runtime-080_python313_runtime_python_bin_python3.13-6.dmp`, 17,833,984 bytes, SHA256 `6e3e73f1ea05ab572fb93e0906532fd7fbb8861ccf93eca9412fee7092179c39`. The watcher stopped the parent, then terminated it after the graceful timeout. The private JVM was stopped and the owned orphan tmux server and its children were cleaned up. No owned live PID remains.

The native stack is `pthread_kill → raise → abort → fatal_error_exit → fatal_error → _Py_FatalErrorFunc → _PyEval_EvalFrameDefault.cold`. Static disassembly of the exact archive-matching binary identifies the fatal reason as **Executing a cache.** This is interpreter bytecode dispatch, not SSL, malloc shutdown or buffered stdout finalization.

Restricted core metadata (filenames/function names only, no locals, globals, arguments or environment) identifies `textual.css.tokenizer.Expect.__init__ → re.compile → re._compiler.compile → re._parser.parse/_parse_sub/_parse → Tokenizer.match`. The top Python code object is the standard-library `re/_parser.py`, function `Tokenizer.match`, first line255, 34 code units. Its saved instruction pointer is outside its bytecode array; offsets were checked against this runtime's installed classic-GIL headers. GDB also warns about the BOLT ELF layout and a possible executable mismatch, so this metadata is evidence to narrow reproduction, not an independently proven root cause. The executable itself is byte-identical to the verified archive.

Read-only cache checks found correct Python magic/timestamp headers and all cached code objects equal to fresh compilation of the source for `re/_parser.py`, `re/_compiler.py`, `re/__init__.py`, and Textual's `css/tokenizer.py`. The three standard-library sources match the verified Python archive. No stale/corrupted on-disk bytecode was established.

All11 actual instructions/arguments of `Tokenizer.match` from the core also match fresh source compilation after CPython's normal specialization-to-base-opcode mapping. The saved instruction-pointer anomaly remains, with the GDB/BOLT unwinding caveat above.

## Bounded import-only diagnostic

The authorized follow-up completed exactly15 fresh children: five imports of `textual.css.tokenize` using existing cache, five with a new private `-X pycache_prefix` per child, then five imports of `devbrain.terminal_panels`. All15 reached the explicit `import_complete` marker and exited0 in3.19s. A further30s observation after cleanup found no new core. This did not reproduce the earlier fatal and does not qualify the application or the runtime gate.

Each child used `-I -X faulthandler -X importtime`, a512MiB address-space ceiling and55s CPU ceiling; the coordinator allowed60s for the entire workload, one child at a time. ASLR remained2 with personality00000000. No new OS seccomp sandbox was added; Python guards refused internet socket constructors, SSL contexts and child-process creation. No app.run, database, JVM, tmux, model or GPU operation occurred.

Import-time evidence matched against installed extension paths shows no third-party native extension during `textual.css.tokenize`. `devbrain.terminal_panels` additionally imports `tree_sitter._binding` through Textual's TextArea. Neither imports Pydantic/cryptography on this path. The fatal core's shared-library list has no site-packages extension; the failure happens earlier in CSS regex initialization.

The official PBS3.13 build configuration confirms Clang23.1.3, PGO, full LTO, BOLT and experimental JIT compiled in with default off. A private GCC build of the same CPython version without PGO/LTO/BOLT tests the compiler/build family as a new hypothesis; it would not individually identify BOLT. Keeping exactly the same OpenSSL requires a separate private3.5.9 build because the installed PBS runtime embeds its crypto libraries.

## Independent Perl failure before compilation

The parent subsequently authorized that private source-build comparison, with no system installation. Official Python3.13.18 source SHA256 `abb0102e6d4ae027509bcb82327d9dd85515b44a3ba8ad538cfc5e9847029f68` and OpenSSL3.5.9 source SHA256 `603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a` were verified. Private dependency headers came from `apt-get download` using signed Ubuntu package metadata; four applicable InRelease signatures passed explicit gpgv verification. Nothing was installed with apt or sudo.

**The source-build series stopped at its first native fatal, before gcc/make or the candidate Python ran.** System `/usr/bin/perl` received SIGSEGV while executing OpenSSL's `Configure`. The stage lasted1.65s and peaked at65,130,496 bytes inside a verified2GiB MemoryMax scope with swap disabled. Thus this was not a measured memory-limit exhaustion. No retry or later import trial ran.

Core: `wsl-crash-1794051625-107923-_usr_bin_perl-11.dmp`, timestamp12:40:26 local, 23,687,168 bytes. The restricted native stack is `Perl_sv_set_undef → unknown internal Perl frame → Perl_runops_standard → perl_run → main`. Mapped libraries are libc/libm/libcrypt/loader and standard Perl Cwd, Glob, Fcntl, POSIX, IO, Socket, HiRes, List::Util, Encode, Storable and Langinfo modules. There is no Python, JVM or newly built OpenSSL library in this process.

Perl ELF build ID: `39edac644c02bf3dcf99215562a9643cb7a33511`; installed `perl`, `perl-base`, `libperl5.38t64` version5.38.2-3.2ubuntu0.6. `dpkg -V` for those packages returned0 with no changed-file output. The core/binary SHA values and version evidence are in `runtime-080-perl-configure-fatal.json`; full stage parameters/logs are in `runtime-080-gcc-build-report.json` and its adjacent logs. The build scope and owned processes are gone, boot ID unchanged;30s post-cleanup observation completed.

This is an independent failing program, beyond the original Python/Java cases, but it does not by itself identify a CPU, RAM, OS or compiler root cause. All build/reproduction/test activity stopped after evidence collection.

## Interpretation and next gate

The tmux software defect has a specific upstream fix and a clean targeted result. Python remains unresolved. [CPython#144282](https://github.com/python/cpython/issues/144282) intentionally constructs invalid bytecode and does not explain ordinary imports. [CPython#156351](https://github.com/python/cpython/issues/156351) concerns free-threaded generators and does not match this classic-GIL build. A superficially similar [WSL#41019 report](https://github.com/microsoft/WSL/issues/41019) later withdrew its kernel-regression claim after contradictory A/B results. That external report does not diagnose this computer.

The machine-readable `runtime-080-software-gate.json` is **blocked**, with `root_cause_established=false` and `production_or_soak_authorized=false`. No repetition of the failed full series, GPU evaluation, production database operation or eight-hour soak followed. The next proposed diagnostic isolates only Textual CSS tokenizer imports and compares existing bytecode with fresh private `-X pycache_prefix` directories, under a strict child/time/memory bound and first-fatal stop.
