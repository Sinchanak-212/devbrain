# Current source 202627: backend, attestation, UX handoff

Updated after root observed backend session **5384 actual EXIT0** and the Windows evidence finalizer completed. Backend1557 is passed; canonical attestation is materialized but NOT RUN by this agent. Root alone owns Linux launches and account-usage monitoring. At either known Codex remaining allowance ≤5%, save the master handoff, stop work and follow the user's shutdown instruction. An unavailable five-hour allowance is unknown, not evidence of spare capacity. After interruption or shutdown, preserve the run as interrupted; never resume it or manufacture an exit0.

Current completed backend context SHA: `1c101b5e4f9c56226d7bf4a3a979e2f5b34f4c4cdae7d33349048a3bece36133`; final report SHA: `d9515cf5eb9ee4904039b5b8967ec845e690bd4986807e75d2e6dc7e266cb241`; receipt SHA: `44fea7c912bda9bf128d96f80797b557217f531fcafda30181c59e00e3bc20af`. Actual1557/1557, no failure/error/skip/missing/duplicate, scope quiet32.8302864s and outer35s, restored sleep. Finalizer actual Windows EXIT0, chunk383399. **Do not rerun the finalizer or cancel this completed backend.**

Standalone Prepare also completed actual Windows EXIT0, chunk8f0737. New admitted context `080-standalone-length-repair-attestation-envelope-20261108.json` SHA `a6fb57d0030905b52129bba6065fadcfa9882982ef5d542d09d7b5a5f77040b5`, admission SHA `edec8102fb23b12145e6e8e705cc1f7a353a06b0a5fc0f95c1e6f1bc6b37fb35`, actual backend session5384. The prepared seed remains unchanged. **Do not rerun Prepare**; root may launch the already-admitted observer after serial admission. Record any later observer status separately; no attestation PASS is claimed by this snapshot.

Current source: `app080-20261108T202627Z`, freeze `1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14`,198 files/209 frozen inputs,59 pins; actual preparation receipt `4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e`. Qualified Linux launcher: `/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T202627Z/venv/bin/python`. Frozen38 helper bytes are unchanged. Candidate V7 context SHA `cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6`.

Completed current-source evidence (never pool prior generations):

- Guard604 root76710 actualEXIT0; context `080-guards-queue-budget-active-context-20261108.json` SHA `0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d`; receipt `c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82`; final report `e3c5362952f7d56f5dc7f5d9e45678752bf8304060c961baee8fe49c372e63b5`.
- ENTIRE6 copy root55674 actualEXIT0; context `080-queue-copy-length-repair-active-context-20261108.json` SHA `7285aa2a59c5c27356954df208d03e3dbfbb7c210e35978d384b9628cd63f96b`; receipt `612fe7ff7b542dc687d8f76a3f890fdd474631dfd5f5694a7db51c6a459f4644`; final report `19338e5db7779609154bdd0633e3dcdcc99ca9b7d25f824116302e85ff4e411b`. Sixth status `completed_with_omissions` with two skipped duplicate records remains explicit.

All evidence filenames below are under `C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence` unless the command gives a physical qualification path. Historical contexts, candidates, FAIL reports and raw receipts remain unchanged.

## 1. Backend1557: wait for actual root5384 exit, then review

Run `fullbackend-length-repair080-20261108T204439Z-b2a1ac34`; active context `080-fullbackend-length-repair-active-context-20261108.json`. Prepared context SHA was `ab7a9c3073c9d9bf79a8a4f8bb14795b1ed9ef4a529df1da3a207ae34b43b831`; running context legitimately changes. Input freeze SHA `a5f46fa5a9b2f3261efc4f8b301f572ca9f21155ade95f12c9bc1a6714b20fbf`, spec SHA `7a8c3c16e7ec3238e19e95edc637819f3e2597017cf5d03e422f6cde58138e45`. Whole tests,1557 expected, no selection or skips, TMPDIR=/tmp, timeout7200.

Read-only progress (FileShare ReadWrite|Delete; never infers qualification), reader SHA `21c16f09c2078cb1b211103d7b8d9694b9da55540b4df87347f578e9b81486a5`:

```powershell
& 'C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\read-fullbackend-length-repair-progress-20261108.ps1'
```

The following is the exact **already completed** Windows-only finalizer command, retained for audit. Its precondition was root's observed session5384 actualEXIT0 and `finished_pending_evidence_review`; a completed JUnit or raw receipt alone was insufficient. Do not execute it again. Finalizer SHA `6fde419ca33f28487c792172a12609a7693b42703b1fa7085b251c1886fbac8b`:

```powershell
$finalizer='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\finalize-fullbackend-length-repair-20261108.py'
if((Get-FileHash -LiteralPath $finalizer -Algorithm SHA256).Hash.ToLowerInvariant() -cne '6fde419ca33f28487c792172a12609a7693b42703b1fa7085b251c1886fbac8b'){throw 'Finalizer changed'}
& 'C:\Users\piotr\AppData\Local\Programs\Python\Python311\python.exe' -I -B $finalizer --finalize --root-session 5384 --root-actual-exit 0
if($LASTEXITCODE -ne 0){throw 'Backend evidence review failed'}
```

This requires full unique1557 JUnit=collection, zero fail/error/skip/missing/duplicate, actual child/supervisor exits, exact scope empty≥30s and outer≥30s, unchanged boot/native/power, sleep restored,14 input hashes/38 helper hashes,153 backend source hashes/198 app/209 freeze and59 prepared pins. Raw controller `final_full_suite_pass=false` and `controller_exit_verified=false` remain unchanged until separate attestation. It writes `080-fullbackend-length-repair-final-20261108.json` and publishes final passed context SHA. Record returned report/context/receipt SHA and Windows actual finalizer exit0; thereafter keep admitted backend context immutable.

## 2. Canonical standalone attestation: future actual proof only

Prepared envelope context `080-standalone-length-repair-attestation-prepared-context-20261108.json` SHA `8598f2e8e68cd91f60d609617777ee082133e82346ab95de3dcaaed549b195ce`; peer report `080-standalone-length-repair-attestation-qr-peer-review-20261108.json` SHA `04601bfc0b70d92d9caf6d2e0358c8fcde54072cf78f4fae12e2edaa34a987cc`.

Materializer SHA `de263bb59d27fa73e63a4f590f99e6169ea6d83375b4425b3c9310b93b4da7a6`; observer SHA `c7e8ca2373c32d22cb0113b902dc8c4fb13b0cdd19f2e69b09e8ab0564690b4f`. The original seed retains NULL session metadata, while the new admission binds actual5384. The following exact materialization command is retained for audit and **has already completed; do not rerun**:

```powershell
$backendPath='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-fullbackend-length-repair-active-context-20261108.json'
$backend=Get-Content -LiteralPath $backendPath -Raw|ConvertFrom-Json
if($backend.status -cne 'passed' -or $backend.actual_windows_exec_session -ne 5384 -or $backend.actual_windows_exit_code -ne 0 -or $backend.cleanup_complete -ne $true){throw 'Actual backend success absent'}
$backendSHA=(Get-FileHash -LiteralPath $backendPath -Algorithm SHA256).Hash.ToLowerInvariant()
$receiptSHA=(Get-FileHash -LiteralPath $backend.receipt -Algorithm SHA256).Hash.ToLowerInvariant()
$envelope='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification\suite-attest-length-envelope-20261108T204733Z-c13c12a5'
$prepare=Join-Path $envelope 'prepare-full-suite-attestation.ps1'
if((Get-FileHash -LiteralPath $prepare -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'de263bb59d27fa73e63a4f590f99e6169ea6d83375b4425b3c9310b93b4da7a6'){throw 'Materializer changed'}
& $prepare -Prepare -BackendActualExecSession 5384 -BackendContextSha256 $backendSHA -BackendReceiptSha256 $receiptSHA
```

Capture actual Windows Prepare exit0 and returned admission SHA. It checks the supplied positive session against the hash-bound passed context and seals the admission; it launches no process. Publish a **new** admitted envelope context with these actual values while preserving the prepared context. After root's serial admission review, invoke the observer in an owned Windows exec session and wait for its actual exit:

```powershell
$observer=Join-Path $envelope 'run-full-suite-attestation.ps1'
if((Get-FileHash -LiteralPath $observer -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'c7e8ca2373c32d22cb0113b902dc8c4fb13b0cdd19f2e69b09e8ab0564690b4f'){throw 'Observer changed'}
& $observer -Execute
```

This is the direct qualified venv `-I -B` attestor, not a supervisor-controller alias. Exact12 attestor/16 bounded argv; timeout120s+kill5s; retained Windows proxy actual exit, completed streams, boot/kernel/dump/power≥30s tail, sleep restoration required. Nonzero/timeout stays FAIL and needs exact PID/birth cleanup proof before another workload.

Canonical output only:
`C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification\fullbackend-length-repair080-20261108T204439Z-b2a1ac34\artifacts\final-full-suite.json`.

After actual observer exit0, verify output1557/source/runtime/raw receipt SHA and observation cleanup/30s proof, then record their real hashes in a new final envelope/report. Never substitute an old1537 attestation.

## 3. Fresh UX377, then actual UI observations

Prepared UX context `080-ux-length-repair-active-context-20261108.json` SHA `af91a75594ee9bbfe20d1e0bab4c73ae2eaa09ffce45ddd6643c2c3b7486a204`; run `ux-length-repair080-20261108T204650Z-5bc27ae5`; spec SHA `0831d6c12c851c36e3edd6e6858e182b010c35b2f909e6d79f99b0257c30d169`;16-input freeze SHA `9655dcfa2a2342fc4b2c3c077cce4c881de2b27371fad599d8b4dc8b53ccfd82`. Peer report SHA `83f289f47d2e6dc076e3b8bc60921c84d84c1f3a510f7d47990cfceb07dbb918`.

After backend/attestor actual cleanup and root's standard frozen-input/source/runtime/power serial admission, rehash16 inputs+38 helpers and use the prepared context values. The equivalent exact wrapper invocation is below; record the new Windows exec-session ID, update running context only at launch, and wait for actual exit (1800s timeout,30s cleanup):

```powershell
$uxPath='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-ux-length-repair-active-context-20261108.json'
if((Get-FileHash -LiteralPath $uxPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'af91a75594ee9bbfe20d1e0bab4c73ae2eaa09ffce45ddd6643c2c3b7486a204'){throw 'Prepared UX context changed; review recorded status first'}
$ux=Get-Content -LiteralPath $uxPath -Raw|ConvertFrom-Json
& (Join-Path $ux.windows_tools 'run-supervised-080.ps1') -Execute -ArtifactRoot $ux.artifact_root -LinuxArtifactRoot $ux.linux_artifact_root -PythonExecutable $ux.base_python -Controller $ux.controller -ControllerArgumentsFile $ux.specification -RunId $ux.run_id -TimeoutSeconds 1800 -CleanupGraceSeconds 30 -WslCrashDirectory 'C:\Users\piotr\AppData\Local\Temp\wsl-crashes'
```

Final UX review requires actual root exit0, raw receipt/supervisor/controller exit0,377 unique JUnit nodeids exactly matching full28-module collection, no failures/errors/skips/missing/duplicates, all raw artifact/16 input/38 helper/current source hashes, exact scope empty≥30s and outer≥30s, clean boot/native/power and restored sleep. Preserve raw pending controller flags and publish a new report/final context only after these checks. Tests passing before cleanup is not a passed run.

Actual UI5tasks+3 OS observations remains pending. QR owns `stage-interactive-length-repair-agent-604-20261108.ps1` SHA `992ef717655b1c901e556034a32af781a092ae47fb8367523e3a70038b78bf29`, gated on **current** backend1557, ENTIRE6 copy and UX377 passed contexts. Operator=agent, human_reported=false; Claude selection must return automatically on A→B→A with the same session. The old UI reports cannot qualify this source. Native/Copilot/Ollama20/frontend/smoke/continuous8h and production actions remain pending their own exact current-source gates.

## Conditional SAFE STOP at verified quota ≤5% (NOT EXECUTED)

The current frozen supervisor provides an explicit **per-run `artifacts/cancel.json`** channel. `supervise-080.py` SHA `865f3b19b3140218da9b080dc517f5eefb724718d96317a88ac37942128a910f`, `ParentControl.check()` lines378–395 checks cancellation before heartbeat; its running loop calls this every approximately0.2s. The exception enters `ScopeOwnership.stop()` (lines235–257): verified UUID cgroup/dev:inode, UID/birth/process identity, pidfd_open, repeated ownership check, SIGTERM first (3s), then SIGKILL if necessary (3s). It actually waits for the controller. Any forced cleanup remains a failure.

`run-supervised-080.ps1` SHA `721109e2295099fcc4dea6e1a1bc55e773e577e2de673931c33a7e4bb7812c74` remains alive, keeps heartbeat and independent monitoring, observes the real supervisor/proxy exit, completes stdout/stderr, and watches its exact cgroup until empty≥30s plus late boot/kernel/dump/power observations. If its emergency scope stop is needed, the script checks expected group and dev:inode before `systemctl --user stop`; it never adopts an unrelated unit. Its nested finally restores sleep inhibition. On cancellation, raw receipt PASS is **not expected**; controller/supervisor/receipt errors must remain intact. Supervisor's inner grace can end immediately on the persistent cancellation file; the external observer's actual≥30s tail is therefore mandatory for SAFE_STOP.

The example below is bound only to backend5384, which is now completed and must NOT be cancelled. It documents the frozen cancellation contract for future supervised runs; before applying it to another run, root must bind and review that run's actual context, ID, source/spec hashes, artifact root and retained tool session. It is not a command for the standalone attestor. The standalone observer has no cancel-file control and is already bounded to120s plus kill5s and cleanup/tail: stop new work, save the handoff and wait for its actual completion before shutdown; a timeout/nonzero retains its exact cleanup-admission requirement.

Procedure for an admitted active instance of this exact backend only:

1. Root records timestamp and first-party five-hour/weekly metric that actually demonstrates≤5%, flushes the master handoff/checkpoint, records current root exec-session5384 and current run paths. Do not turn an unavailable metric into zero. Do not start another workload.
2. Keep the existing Windows wrapper alive. Use the following **conditional** single-run control request. The initial NaN intentionally refuses execution until the verified numeric metric is supplied. It imports only three exact frozen function definitions via AST; it never executes the wrapper body, sends terminal Ctrl-C, opens Linux, or signals a numeric PID. The nonce is copied from the matching heartbeat without printing it.

```powershell
$knownRemainingPercent=[double]::NaN # Replace only with the just-verified first-party remaining percentage.
if([double]::IsNaN($knownRemainingPercent) -or $knownRemainingPercent -lt 0 -or $knownRemainingPercent -gt 5){throw 'Quota STOP condition is not established'}
$stopContextPath='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain\evidence\080-fullbackend-length-repair-active-context-20261108.json'
$stopContext=Get-Content -LiteralPath $stopContextPath -Raw|ConvertFrom-Json
if($stopContext.run_id -cne 'fullbackend-length-repair080-20261108T204439Z-b2a1ac34' -or $stopContext.source_freeze_sha256 -cne '1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14' -or $stopContext.specification_sha256 -cne '7a8c3c16e7ec3238e19e95edc637819f3e2597017cf5d03e422f6cde58138e45'){throw 'Wrong active run'}
$stopRoot='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification\fullbackend-length-repair080-20261108T204439Z-b2a1ac34\artifacts'
if([IO.Path]::GetFullPath($stopContext.artifact_root) -cne $stopRoot){throw 'Artifact root mismatch'}
if($stopContext.status -cne 'running' -or $null -ne $stopContext.actual_windows_exit_code){throw 'This run is no longer an active cancellation target'}
$stopWrapper=Join-Path $stopContext.windows_tools 'run-supervised-080.ps1'
if((Get-FileHash -LiteralPath $stopWrapper -Algorithm SHA256).Hash.ToLowerInvariant() -cne '721109e2295099fcc4dea6e1a1bc55e773e577e2de673931c33a7e4bb7812c74'){throw 'Frozen wrapper mismatch'}
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($stopWrapper,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Frozen wrapper parse error'}
foreach($name in @('Assert-PlainPath','Read-Json','Write-AtomicJson')){
 $defs=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true))
 if($defs.Count -ne 1){throw 'Frozen function inventory mismatch'}
 . ([scriptblock]::Create($defs[0].Extent.Text))
}
$null=Assert-PlainPath $stopRoot
if(Test-Path -LiteralPath (Join-Path $stopRoot 'supervisor-exit.json')){throw 'Supervisor already exited; wait for existing external tail instead of cancelling'}
$heartbeat=Read-Json (Join-Path $stopRoot 'heartbeat.json')
if($heartbeat.run_id -cne $stopContext.run_id -or $heartbeat.nonce -isnot [string] -or $heartbeat.nonce -cnotmatch '^[0-9a-f]{32}$'){throw 'Current control identity not verified'}
$cancelPath=Assert-PlainPath (Join-Path $stopRoot 'cancel.json')
if(Test-Path -LiteralPath $cancelPath){throw 'Cancellation already requested; preserve it and observe existing cleanup'}
$null=Write-AtomicJson $cancelPath @{run_id=$stopContext.run_id;nonce=$heartbeat.nonce;reason='operator_quota_stop';requested_utc=[DateTimeOffset]::UtcNow.ToString('o')}
```

3. Root polls **the existing tool session5384** using empty `write_stdin` (plain pipes; no Ctrl-C bytes) until actual Windows exit. Expect nonzero after cancellation; do not kill the wrapper or its WSL proxy to accelerate the tail. Keep the currently advancing heartbeat untouched. Preserve `cancel.json`, `supervisor-exit.json`, logs, raw reports, scope probes and power JSONL.
4. Record a separate **ABORTED/FAIL + scoped SAFE_STOP** audit, never PASS: actual wrapper/proxy/controller exits, scope unit/group/dev:inode matching the existing observer, empty scope and tagged lists, external empty≥30s and late native observation≥30s, boot/dump/fatal state unchanged, final power state matching the gate, and `sleep_inhibition.restored=true`. Raw `receipt.cleanup_complete=false` or `forced_cleanup=true` can accompany an intentional cancellation; do not rewrite them. The safe-stop audit must cite the independent scope probes/supervisor exits and clearly distinguish safety from failed qualification. The supervisor's cancelled inner grace is not a full quiet-window proof.
5. Flush updated master handoff with exact hashes, actual exits and any incomplete evidence. Only after safe cleanup has been proved and the verified quota condition remains recorded, the root performs the user-authorized **whole Windows shutdown**, not a WSL-only shutdown: `shutdown.exe /s /t 0`. No `/f`, no kill-all, no deletion of evidence. If the process finishes naturally before the request, preserve its actual result and tail, then save/stop/shutdown under the same quota condition.

If the Windows observer becomes unresponsive or disappears, cancellation alone is not a cleanup proof. Do not improvise PID-only killing. The already-tested parent-loss contract (runtime fixture report `d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c`) requires a **retained exact own Windows Process handle bound to PID+CreationTime+command**, a continuous foreground WSL hold established before parent loss, UUID cgroup group+dev:inode, descendant pidfds/actual exits and external empty≥30s plus power/native/restore proof. It is not authorization to run the fixture launcher against this backend, and its old PASS cannot stand in for new cleanup. If these actual proofs cannot be obtained, preserve `ABORTED / cleanup_unknown`, never report SAFE_NEXT or successful qualification, and surface the precise missing proof to the root shutdown owner. No additional qualification workload may begin. An interrupted continuous8h trial must restart fresh from zero in a later authorized run.
