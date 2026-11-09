# DevBrain 0.8.0 — START HERE — USER STOP 2026-11-08 22:42 UTC

## Latest instruction and actual state

The user explicitly stopped all work and requested a full handoff followed by whole-Windows shutdown. No additional tests or staging are authorized in THIS session. Resume work only when the user continues in a new session. The earlier instruction to complete all pre-8h gates was superseded by this immediate STOP.

**The 8-hour test has NEVER STARTED. All pre-8h gates are NOT complete. DevBrain 0.8.0 is NOT qualified, released, deployed, or resumed. Production 0.7.2 and its private database remain stopped.**

No owned Linux qualification workload remains. The last workload, root tool session82992, completed naturally with actual Windows exit0 before cancellation was needed. Its independent cleanup and closing Windows-only audit passed. No cancellation or forced shutdown of a test was performed. All three active subagents stopped and report no owned active Windows/Linux processes.

Current source: app080-20261108T222731Z, freeze:
ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703
198 application files /209 total frozen bundle files.
Expected, NOT YET RUN on this source: backend1561, UX381 across28 modules.
Actual collection remains authoritative.

Workspace:
C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain

Durable qualification root, outside OneDrive:
C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification

Current source:
 /home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T222731Z/project/devbrain
Literal qualified application Python (do not resolve to basePython):
 /home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T222731Z/venv/bin/python

Authoritative source/preparation context:
 evidence/080-app-ux-snapshot-active-context.json
 status prepared_passed, actual prepare session11195 exit0
 preparation receipt4cba08753a5d44463687271f5e695ccddac4d2284ca348b66630f480facde918
 59 package pins identical,198 Linux sources exact, quiet32.2560176s, no new native failure.

## What changed immediately before STOP

Real Windows Terminal photographs exposed an actual responsive-layout bug. SidebarApp.on_resize read self.size.width before Textual8.2.8's internal resize handler updated it. At80x24 More was cropped; at180x55 the24-column sidebar incorrectly retained two action columns and wrapped Connections. Current-event width is required.

Only two application files changed from the previous202627 snapshot:
- devbrain/src/devbrain/terminal_panels.py
  SHA5202c07f1298aa2720ae0612707aba4864f58b31b3a5014f05dc044f30b48cc1
  Import Resize; use event.size.width; overflow-y:auto on sidebar-main.
- devbrain/tests/test_terminal_panels.py
  SHA66df50d81349530c18833fe7b3990bb42d334c4f6a02f5e64cffa776401967a8
  Four new EN/PL × Projects/Project actual resize tests:
 24x33→80x21→24x21→120x33→80x21, current class/row geometry,
 full labels, focused actions revealed by scrolling, Tab to More, no client launch.
 All44 prior assertions and old test byte prefix/AST preserved.
 These four tests HAVE NOT RUN yet. AST/static review is not a runtime PASS.

Proofs:
 evidence/080-sidebar-resize-proposal-20261108.json
 350acb0bffc0ccc9ee793b9bc4d34ff5d8e8dcd64ae42e3cb64397f8b06a8f96
 evidence/080-sidebar-resize-proposal-peer-review-20261108.json
 69fae0b54f8db62cd52e948e06ba2aa4a305a6d774b31a7612a1fcc65ccc817c
 evidence/080-sidebar-resize-applied-preparation-20261108.json
 2fe9c6d15376dfee3e7aeca4085320e8f5b75748238594dfb6172b33bd9de20b

196 other application files, qualified runtimes and38 frozen release helpers are unchanged.

## Current-source completed gates

1. App preparation: actual11195 exit0, details above.
2. Mechanical candidate V8: actual root25627 exit0, NOT application qualification.
 Context evidence/080-final-candidate-build-ready-context-v8-20261108.json
 SHA6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b
 This admitted context is immutable. Do not change its qualified=false or source-final flags.
 Candidate directory:
 qualification\final-candidate-sidebar080-20261108T223128Z\releases\candidates\0.8.0
 ZIP f48276a0d82a15f5f6df13884f56d94f23337459d704ff0ea5f0226f14969e71
 Updater6371e83c278fbb5b953680398434bb2a7f6d2c06e13dda0efb42592311097405
 Manifest8055443f8891eeedb6bb3b7c4d8040053cf69786bf4bf6965fa967197e8b0a89
 Observation758e420c604b3aaaa81adebfdb22c7de8379614056542ae5a2106e0b3ba5d5c9
 Root rehashed213 frozen inputs, all198 manifest entries and every byte hash of198 unique ZIP entries.
 Post-exit observation31.1728835s, closed streams, sleep restored, no errors.
 Candidate.qualified=false is intentional; later production helper requires all11 real proofs.

3. Fresh604 guards: PASSED604/604,12 modules,38 unchanged helpers.
 Root82992 actual Windows exit0 observed22:38:56UTC.
 A Windows-only closing audit, NOT another test run, then exited0.
 Context evidence/080-guards-queue-budget-active-context-20261108.json
 SHA9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6
 Final report evidence/080-guards-sidebar-resize-final-20261108.json
 SHAad4a0f638bef723c4e8c918e2daeb4f71eac60e238d32ea454586ca53d326e8f
 Receipt9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84
 Run guards-sidebar-resize080-20261108T223449Z
 Freeze7e3a840ac8b6d230cc9831bdd9a28a0e7ae604ee02d34481650915ca09513f5d
 Specd6a45e2f81b67a3a973462db01f9d11825c44fdc1c81f96dd72b30a649aadbae
 Exact owned scope devbrain-q-a41f6b02987a4aafba73bac9b3e067b6.scope,
 dev:inode25:2961, empty confirmed33.1447639s +outer36s.
 Cleanuptrue, forcedfalse, nativefalse, no new dumps/kernel fatals/errors,
 sleep restored. Initial/final boot bothd3506988-9d2d-4b08-a339-84e4dbf100ca.
 Closed Windows qualification child count0; Balanced active at final root probe.

## Prior results: preserve, never pool as current-source acceptance

Source202627 /freeze1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14 passed:
 complete backend1557, canonical full-suite attestation, UX377 with P95
27.118ms at80 and118.708ms at180, maximum loop129.522ms, and an entire
fresh six-job replay ON A COPY with no duplicates and each attempt+1.
The sixth completed_with_omissions(skipped2), not all proposed records written.
These are historical after the two-file UI change. New current1561/381/copy/UI/NEXT5 must run.

Historical proof contexts/reports:
 evidence/080-fullbackend-length-repair-active-context-20261108.json
 evidence/080-full-suite-length-repair-attestation-final-20261108.json
 evidence/080-ux-length-repair-active-context-20261108.json
 evidence/080-queue-copy-length-repair-final-20261108.json

Last genuine UI old source202627:
 root14823 actual0; eight mechanical observations passed (five agent tasks +three sizes).
 Overall VISUAL FAILED; do not admit NEXT5 from its raw mechanical PASS.
 evidence/080-interactive-length-repair-rerun-final-20261108.json
 SHA82113271f187304850db1d335a592d623a0b434880c68eafea1190780bf61ddc
 Strict owned cleanup passed: scope32.9084869+outer36s, JVM143 after
 graceful request/actual exit, all viewers actual exits, OAuth phase sync +
 final cache sync/release passed. Raw pending flags/PASS preserved.
 Three actual OS PNGs, personally viewed by root:
120x36 c512d1077e15ee1d297ef4251449d0dabc492137505218ae25cf0b351fc39bcf
80x24 27b911e4e6f5562fc97fc09b8d11e6084fdc0d81359c596f490c2bc881a826df
180x55 b37e21cb55a699e10a7f703bdd7d9c3393dd613bf8e1d98d6933a1b99feb41a3
 Root visual file finalSHAd5c72205c42ceea3e0f04b5a8fa5af8cedc415dee017ac44bd6505d14f6915a0,
 visual_acceptance_passed=false. Photographs are genuine Windows Terminal
PrintWindow captures; ANSI/SVG/headless frames are not OS screenshots.

An earlier UI trial77868 failed its operator deadline. A mistakenly started
interactive Codex exited1 after2.37s; cause UNKNOWN. Its complete scoped
safe-next proof0e27f5d2926068e011b8ca12d911e2c82ef974cd0cdba6a54ebc578e5b708d41
is preserved. The later clean UI used only Claude and does not resolve Codex.
Do NOT label the old Codex exit as geometry/CPR/TERM/auth/usage cause.
The runner explicitly sets TERM=xterm-256color and launch preserves it;
tmux3.8 handles CPR internally. Native account regression uses noninteractive
codex exec, so it is not sufficient proof of interactive Codex startup.

Older source160614 passed native Codex→Claude→Codex, GitHub-account Copilot,
20 Ollama cases(score1.0, two expected unknown/partial cases), frontend10+8.
They remain historical, not substitutes for current-source gates.

## Exact next-session work, in order

1. Read this file, machine checkpoint and the three agent handoffs below.
 Inspect current workspace/durable frozen paths, do not rely on tool-store
 variables from this chat. No Git push/public release was done or requested.
 Preserve all old FAIL/PASS and immutable snapshots. Do not reset/delete
 another worker's changes; source was initially untracked.

2. Fresh host preflight: confirm BIOS4601/microcode0x133, Intel defaults/no
XMP/OC as user reported; Windows Balanced381b4222-f694-41f0-9685-ff5bb260df2e,
183 settings fingerprint6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1,
Razer Cortex remains closed. Recheck actual runtime SHA/59 pins/source198,
new dump/kernel/native events and current boot IDs. Shutdown means new boot;
boot change BETWEEN idle trials is distinct from an in-trial change, which
invalidates that trial. No inferred hardware diagnosis or firmware change.

 Runtime gate A6 unchanged:
 a6bd365cea68986ed6795990272c766679bbd29fd9407e904a12c2956bcdf7fb
 evidence/080-postbios-active-context.json
 Base Python /home/piotr/.cache/devbrain-runtime-080/runtimes/python/bin/python3.12
3.12.16, SHA23bc148d2b48964b621c5561ff2b81c1d9c7b717967a7491efbf12f4304882b5
 static OpenSSL3.5.9
 Java /home/piotr/.cache/devbrain-runtime-080/runtimes/jdk-21.0.13+9/bin/java
21.0.13+9 defaultC2, SHA9cad3f2620d3ef2ed10b26f922af7e773d54fdaa05f615d6d6df014f3fec4155
 tmux /home/piotr/.cache/devbrain-runtime-080/runtimes/tmux-3.8/bin/tmux
 SHAb4338a07981a2d6e008578059050cf91e43e086929630358937a4df365766669
 ArcadeDB /home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1
 Keep system defaults/historical venvs unchanged. DefaultC2 is required;
 C1 does not qualify stability.
 Runtime-only five supervision fixture proof d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c
 remains unchanged runtime-only evidence. Do not retag as newApp acceptance.

3. UX381 FIRST to catch the new layout test failure promptly; all28 modules,
EN/PL/three sizes, P95≤150ms and maxUIloop≤500ms under controlled3s latency.
Stager (not yet Stage/executed):
 evidence/stage-ux-sidebar-resize-604-20261108.ps1
 SHA8a4eb75de06a55e5e40c3db58739d8b90079381c23fa6b6962550b29c861ff5c
 params -Stage -GuardContextSha2569e9d... -GuardReceiptSha2569dca...
 -GuardFinalReportSha256ad4a... -GuardActualWindowsExecSession82992
 -CandidateContextSha2566d6c... (use full hashes above, not abbreviated).
 Peer85ebcc5112c643007c8261db84bb8eb093d3dc26c39b7deb227a54ce3bb264d3.
 Generates fresh context only, never launches Linux. Review/rehash all frozen
 inputs and38 helpers before a separate actual retained serial launch.

4. Fresh ENTIRE six historical jobs on copy only:
 evidence/stage-queue-copy-sidebar-resize-604-20261108.ps1
 SHA85a8c697f814bcd2380e98be0eb5ddd787f921986373d66f3c1a6eb323408152
 params guard context/receipt/report hashes above,
 -AppContextSha256(actual immutable current app context hash),
 -GuardExecSessionId82992. Peer efaf84f94e89999db86d5e011e0cbdaca06c6ad6c2901ba83847abe2531dd70a.
 Immutable original backup, all3imports+3extracts, 120/125/210s budgets,
 exact attempt+1, all unrelated jobs/counters and duplicate checks.
 No partial-run pooling; retain omissions/rejections honestly.
 Private original072 backup is not to be changed or replayed in production.

5. Complete backend expected1561:
 evidence/stage-fullbackend-sidebar-resize-604-20261108.ps1
 SHAde36c4daac4b3589cad3dd9bfa95db7df0a1df34b3756cace6cecd0978e00635
 params guard context/receipt/report hashes. Preserve fullcollection/JUnit/
 exact unique nodeid parity,0F/E/unexpectedskip, qualified defaultC2 andTMPDIR.
 Current1561 finalizer and canonical standalone envelope are NOT CREATED.
 Retarget reviewed previous1557 Windows audit/standalone observer metadata
 with independent review, new actual backend session/path/hashes; do not
 use an unregistered supervisor controller alias or old1557 attestation.
 Qualified literal venv -I -B, bounded120s+kill5s direct attestor and independent
 retained Windows proxy/closed streams/post-exit native+power≥30s required.

6. Genuine UI five keyboard tasks +real OS pictures80x24/120x36/180x55.
 evidence/stage-interactive-sidebar-resize-agent-dom-604-20261108.ps1
 SHA37e11f8c2b08537b7147f2c131c0ca5b85a17870b1e1a9bcedf4bc121a2abd0c
 conditional current604/backend1561/copy6/UX381 proofs required.
 NOT STAGED; its independent peer is PENDING at STOP.
 Prefer actual native Codex once for these tasks to resolve interactive
 startup coverage. Use real profile/model, explicit one Start work, no
 blind model retries. If it fails, preserve failed lifecycle/exit, inspect
 legitimate terminal promptly and emit only fixed reason classification.
 Only PID/birth-bound whitelisted TERM/COLORTERM/isatty metadata if needed;
 never dump whole environment, credential file, private output or secrets.
 Task2 A→B→A automatically restores same assistant/session; Resume must
 preserve generation/PID/birth/ACK and not issue another Start request.
 Other tasks: find source, change connection/model without unintended
 launch, detach normal client and attach-only menu1 preserving session.
 Agent test, NOT human acceptance. Observe defaultEN/manualPL, focus,
 emptyresults, Unicode, forms, recovery and resize.
 User explicitly authorized PrintWindow ONLY DevBrain windows; no Win32
SendKeys. Native CUA could not see Windows Terminal. Real read-only tmux
 observers must be exact PID/birth/TTY/binary/UID, ignore-size, detached with
 pidfd actual-exit proof. Normal keyboard via real client's relay/-K only.
 Verify all8 official observations +three actual root-viewed OS pictures.
 **Require literal boolean visual_acceptance_passed=true.** Mechanical8/8
 and three photo flags cannot admit a known cropped/wrapped interface.
 Old072 genuine three OS pictures are valid baseline only:
 evidence/080-baseline-visual-final-20261108.json SHA91450d6f6445a8b0c0fe2c7e7f020e245e6dee893a8f35cfa3ef344542d55e45.
 Unicode/Japanese strings are synthetic project data, not EN UI labels.

7. After actual UI+cleanup/visualPASS, current-source real native
Codex→Claude→Codex; GitHub-account Copilot with memory protocol/noAPIkey;
all20 Ollama cases≥90% +all critical facts, without lowered thresholds;
frontend unit/browser/build/audit; updater072→080/backup+restore on copy.
 evidence/stage-five-sidebar-final-gates-after-ui-20261108.ps1
 SHA37293adac1ea634fc9da250c80fd88bebaf0491bc1369c4c997d157818bd0c84
 evidence/080-sidebar-resize-remaining-gate-templates-604-20261108.json
 SHAf4e039f5040cd70f2f3b0aa18699bfacc92e1f445ad2bb81dd685d96b2643dba
 New proofs remain NULL, these templates are NOT completed gates.
 Native compaction scope must remain honest: historical real_native_compaction_tested=false,
 synthetic_precompact_event=true. Account queries stay outside stress loop.
 Smoke outer CLI has no --backup-python; supply qualified isolated072 venv
 to the UPDATER's required --backup-python, not old unsafe runtime.
 Preserve accounts/models/profiles/clientassignments/memory/commanddevbrain.

8. Only after all above: request/confirm a future continuous8h window.
 The user expressly prohibited running8h in the stopped session.
 evidence/stage-final-eight-hour-sidebar-resize-604-20261108.ps1
 SHA3527b2c82c372c4d8764d0ff3a8a4be3e84d6c1e78c503044fe94cc8af9cc5ee
 proof template evidence/080-sidebar-resize-eight-hour-proof-manifest-template-20261108.json
 SHA24df18e40cd6926677382e05301fbb6c7c2ef1ff0894b57fad7e430d4b8d9619
 All current proofs +strictvisualTRUE required; no Stage/no8h run exists.
 Fresh synthetic database,28800 continuous seconds, local embedding/chat
every900s (32each), TUI/memory/snapshots/disconnect/attach/integrity,
GPU/RAM/VRAM/process/boot/native/power watchdog and actual cleanup≥30s.
 Any new crash/timeout/unknown cleanup halts acceptance; never pool
 intervals around shutdown. Preserve all raw fail reports.

9. Only after8h +canonical attestation/all11proofs: production updater,
 backuprestorecheck oncopy, fullsourcebaseline182 before apply and target198
 after apply, installedTUI inspection, individual production queue retries,
 post-update backup/readback and controlled production resume.
 Current production source /home/piotr/src/devbrain,
 data /home/piotr/.local/share/devbrain,
 command /home/piotr/.local/bin/devbrain.
 Frozen deploy helper53eece60c4d177cbfc352c8293f5c5b3cbe3e7ca25d7656f2a10c74d1a9dceb0:
 owned qualified JVM/listener first, never foreign adoption; one-shot private
 O_EXCL/CAS journal, no blind retry of unknown mutations. config CAS merges
 ONLY java_executable/tmux_executable. Six production retries one-by-one,
 exact attempts/duplicates, never scanner/drain.
 Existing readonly source-preflight-v7 supplement47838bbf... is pinned to
 OLD V7 ZIP4fb8; retarget its public metadata to V8 with peer review.
 Rootdist is exact allowed unmanaged directory, never inspect/delete its
 private contents. Early182baselinePASS is point-in-time, must repeat before
 deploy. Updater's60 changed paths are not full198 integrity coverage.
 Do not mutate candidate qualified=false; publish separate proof index.

## Launch, cleanup, authentication and quota rules

One owned Linux application/test workload at a time. Retain exec session ID
and actual terminal exit; a zero test count before cleanup is insufficient.
Require exact scope UUID/dev:inode, actual descendants stopped/empty≥30s,
late native/power/boot checks, completed streams and restored sleep.
Source/runtime/input/helper hashes before/after, no globally killing PIDs.
Normal JVM143 with graceful request/actual proof is not an unexpected crash.
Do not export process memory, OAuth files/hashes/principals/accountIDs,
tokens, passwords, private SQL/source contents or whole terminal output.

Saved generic serial launcher:
 evidence/080-handoff-serial-launch-template.ps1
 SHA138f73d4ec967128f0117158832cdd28b0ac159c30cf260750c5ae006d716ed8
 Read before reuse; requires prepared_not_run. UX stager historically emits
prepared_not_run_pending_root_serial_handoff; explicitly admit that exact
fresh status in a new reviewed wrapper for UX, never fake a passed flag.
Rehash ALL input-freeze files relative to windows_root (not windows_tools),
as well as38 helpers. Check every exec exit before dependent commands.
Do not run old consumed contexts or old literal sessionIDs again.

PowerShell7.6.9 actual executable at STOP:
 C:\Program Files\WindowsApps\OpenAI.CodexPrimaryRuntime.v26-1104-2876-0_26.1104.2876.0_x64__3k8sg7r9htsxt\dependencies\native\powershell\pwsh.exe
Do not assume pwsh.exe is on PATH; prior barepath failure occurred before
stager execution and did not mutate anything.

OAuth: Codex official auth.lock +same user/account +durable CAS/powerloss
journal, conflict with newer auth stops sync. Claude uses original secure
credential storage while isolating settings/hooks; never copy whole account
directory. Required final sync/release only after actual CLI cleanup.
User already approved local private credential storage; do not ask again.
No automatic account login or repeat of model request with unknown outcome.

Usage monitoring is Codex ACCOUNT weekly/5h, NOT context.
Latest22:39:46UTC:20% weekly remaining,5h unavailable (not0). STOP reason is
USER, not quota. First-party tool mcp__codex_app__get_usage_limits; sanitize
before saving, never output accountId. If applicable observed remaining≤5%,
stop owned work, durably save and cleanup then Windows shutdown.
For future supervised cancellation, exact current per-run artifacts/cancel.json
with matching heartbeat run_id/nonce while Windows observer stays alive.
Do not use Ctrl-C to pipe, kill-all, PID-only signals, or completed82992.
Full frozen cancellation contract and graceful-owned SAFE_STOP:
 evidence/080-length-repair-durable-handoff-20261108.md
 SHA18f1d05c9254a3cd5afeb6d33fff10bca738ef31a42303728737eda4fb59b89f
Its backend5384 example is HISTORICAL COMPLETED, never execute against it.

Agent handoffs at STOP (all active processesNONE):
 evidence/080-test-suite-sidebar-stop-handoff-20261108.json
 SHA7671c35d57c781518c28eb36db2b92f6d497b5ab88e7f0f651c27e69047a7c03
 evidence/080-queue-review-user-stop-handoff-20261108T224043Z.json
 SHA37c5d79706a38432d741112c2a9678cac9ddae153c0aaecf95f5c8a4456affdf
 evidence/080-release-review-stop-sidebar-handoff-20261108.json
 SHAfeab4262b85d95ffcb237af15a1338a798f93b109d322d469a6bec0173540472
 evidence/080-release-review-stop-sidebar-handoff-final-addendum-20261108.json
 SHA0ac5e13bf9946e9ded8dda18559ffa8d914047e1686d36038e36dc4ec95fa167

No newtests/Stage/model requests after user STOP. Root next operation after
durable handoff/manifest/closure is user-authorized Windows shutdown.exe /s /t 0,
without/f. A successful shutdown request is not proof of physical poweroff;
a closed app/host cannot be observed after the tool connection disappears.

