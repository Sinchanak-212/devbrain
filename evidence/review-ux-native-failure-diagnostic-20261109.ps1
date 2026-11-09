# Windows-only strict closing review of fresh-source collect-all UX diagnostics.
$ErrorActionPreference='Stop'
function Need([bool]$ok,[string]$why){if(-not$ok){throw $why}}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read([string]$p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -AsHashtable -DateKind String}
function Match($a,$b,[string]$why){Need ($a.Count-eq$b.Count) $why;foreach($k in $b.Keys){Need ($a.Contains($k)-and$a[$k]-ceq$b[$k]) $why}}
$cp='evidence/080-ux-native-failure-diagnostic-context-20261109.json';$c=Read $cp
Need ($c.run_id-ceq'ux-uxfailure080-20261109T121905Z-1e5eb045'-and$c.actual_windows_exit_code-eq0-and$c.status-ceq'finished_pending_diagnostic_evidence_review') 'Actual UX exit not recorded'
$inventoryPath='evidence/080-ux-native-failure-diagnostic-final-inventory-20261109.json'
Need ((Sha $inventoryPath)-ceq'f9ea14b78aecf5c871413a55136984bf772c6d25d8bc50a70452352a0ae0cbc2') 'Inventory changed'
$i=Read $inventoryPath
Need ($i.status-ceq'diagnostic_pass_not_release_qualified'-and$i.actual_windows_exec_session-eq69901-and$i.actual_windows_exit_code-eq0-and$i.observed_cases-eq425-and$i.counts.passed-eq425-and$i.whole_modules-eq28-and$i.collection_junit_exact_parity-eq$true-and$i.safe_next_owned_workload_only-eq$true-and@($i.verification_findings).Count-eq0-and@($i.failed_or_skipped_cases).Count-eq0-and$i.latency_contract_passed-eq$true-and$i.six_en_pl_headless_frames_complete-eq$true) 'Full diagnostic contract incomplete'
$a=$c.artifact_root;$rp=Join-Path $a receipt.json;$r=Read $rp;$s=Read (Join-Path $a supervisor-report.json);$d=Read (Join-Path $a controller-report.json);$x=Read (Join-Path $a supervisor-exit.json)
Need ($r.passed-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.windows_proxy_returncode-eq0-and$r.native_failure-eq$false) 'Windows qualification/cleanup missing'
Need ($x.actual_exit_verified-eq$true-and$x.windows_proxy_returncode-eq0-and$x.stdio_complete-eq$true) 'Actual proxy exit missing'
Need ($s.passed-eq$true-and$s.child_returncode-eq0-and$s.cleanup_complete-eq$true-and$s.controller_exit_verified-eq$true-and$s.forced_cleanup-eq$false-and$s.scope_descendants_stopped-eq$true-and@($s.remaining_scope_processes).Count-eq0-and@($s.remaining_tagged_processes).Count-eq0) 'Actual supervisor/controller closure incomplete'
Need ($d.cleanup_complete-eq$true-and$d.forced_cleanup-eq$false-and$d.engine.actual_exit_verified-eq$true-and$d.engine.cleanup_complete-eq$true-and$d.engine.graceful_shutdown_requested-eq$true-and$d.engine.forced_cleanup-eq$false-and$d.engine.returncode-in@(0,143,-15)) 'Owned JVM closure incomplete'
foreach($v in @($r,$s)){foreach($k in @('errors','new_wsl_dumps','new_kernel_fatals')){Need ($v.Contains($k)-and@($v[$k]).Count-eq0) 'New fault/error'}}
Need ((Sha $c.app_context)-ceq'387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92') 'Fresh App context changed';$app=Read $c.app_context
Need ((Sha $app.freeze_manifest)-ceq'9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9') 'Fresh source freeze changed'
$af=Read $app.freeze_manifest;Need ($af.files.Count-eq209-and$af.app_files-eq198) 'Fresh App inventory differs'
foreach($rel in $af.files.Keys){Need ((Sha (Join-Path $app.bundle_root $rel))-ceq$af.files[$rel]) 'Fresh209 bundle changed'}
$globalPath='evidence/080-app-ux-snapshot-active-context.json';Need ((Sha $globalPath)-ceq'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c') 'Global App context changed';$old=Read $globalPath;$oldFreeze=Read $old.freeze_manifest
Need ((Sha $old.freeze_manifest)-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703') 'Historical source freeze changed'
foreach($rel in $oldFreeze.files.Keys){Need ((Sha (Join-Path $old.bundle_root $rel))-ceq$oldFreeze.files[$rel]) 'Old209 bundle changed';if($rel.StartsWith('devbrain/')){Need ((Sha (Join-Path (Get-Location) $rel))-ceq$oldFreeze.files[$rel]) 'Working App198 changed'}}
$g=Read $c.guard_context;$same=0
foreach($n in $g.helper_sha256.Keys){Need ((Sha (Join-Path $g.windows_tools $n))-ceq$g.helper_sha256[$n]) 'Canonical helper changed';Need ((Sha (Join-Path $c.windows_tools $n))-ceq$c.helper_sha256[$n]) 'Private helper changed';if($g.helper_sha256[$n]-ceq$c.helper_sha256[$n]){$same++}}
Need ($same-eq37-and$c.helper_sha256.Count-eq38-and$c.helper_sha256['run-regressions-080.py']-ceq'f8bbfbfee3a465f1b521a005a04c6441154186acda20a7102adc747a10737218') 'Private instrumentation differs'
Match $r.runtime $app.runtime 'Runtime binaries changed'
Match $r.helper_sha256_start $r.helper_sha256_end 'Observed helpers changed'
Match $r.input_sha256_start $r.input_sha256_end 'Observed inputs changed'
$all=@{};foreach($f in Get-ChildItem -LiteralPath $a -File){$all[$f.Name]=Sha $f.FullName}
foreach($n in $r.artifact_sha256.Keys){Need ($all[$n]-ceq$r.artifact_sha256[$n]) 'Receipt artifact changed'}
$report=@{
 schema_version=1;scope='fresh_prototype_complete_UX_diagnostic_closing_review';status='diagnostic_pass_not_release_qualified';run_id=$c.run_id
 actual_windows_exec_session=69901;actual_windows_exit_code=0;actual_exit_chunk='08b20a';initial_exec_chunk='ddd39c';cleanup_complete=$true;safe_next_owned_workload_only=$true
 inventory=(Join-Path (Get-Location) $inventoryPath);inventory_sha256=(Sha $inventoryPath);receipt=$rp;receipt_sha256=(Sha $rp)
 source_freeze_sha256=$app.freeze_sha256;app_context_sha256=$c.app_context_sha256;app_files=198;bundle_files_rehashed=209;old_bundle_files_rehashed=209;working_App_files_rehashed=198;canonical_helpers_rehashed=38;private_helpers_rehashed=38;unchanged_private_helpers=37
 actual_test_count=425;actual_module_count=28;collection_junit_exact_parity=$true;failed=0;errors=0;skipped=0;latency=$i.latency;six_EN_PL_headless_frames=$i.headless_frames_not_os_photos
 latency_original_thresholds_passed=$true;full_frame_contract_passed=$true;frames_are_OS_photos=$false;scope_unit=$r.scope_unit;scope_identity=$r.scope_cgroup_identity;scope_quiet_seconds=$r.scope_cleanup_grace_seconds;outer_quiet_seconds=$r.cleanup_grace_seconds
 actual_controller_exit_verified=$true;actual_supervisor_exit_verified=$true;actual_proxy_exit_verified=$true;stdio_complete=$true;engine=$d.engine
 native_failure=$false;new_kernel_fatals=@();new_wsl_dumps=@();initial_boot_id=$r.initial_boot_id;final_boot_id=$r.final_boot_id;in_run_boot_unchanged=$i.boot_stable
 power_samples=$i.power_samples;power_unchanged=$i.power_observations_verified;sleep_restored=$i.sleep_restored;forced_cleanup=$false
 raw_artifact_sha256=$all;raw_receipt_passed=$r.passed;diagnostic_only=$true;formal_helper_map_qualified=$false;pytest_maxfail=0
 source_final=$false;application_qualified=$false;release_qualified=$false;current_backend_qualification_claimed=$false;current_UI_qualification_claimed=$false;eight_hour_started=$false
 accounts_models_or_private_production_database_used=$false;global_App_context_or_historical_snapshots_modified=$false;created_utc=[DateTime]::UtcNow.ToString('o')
}
$out=Join-Path (Get-Location) 'evidence/080-ux-native-failure-diagnostic-closing-review-20261109.json'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($report|ConvertTo-Json -Depth 20));$stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
$c.status='diagnostic_pass_not_release_qualified';$c.actual_windows_exec_session=69901;$c.cleanup_complete=$true;$c.actual_test_count=425;$c.actual_nodeid_count=425;$c.actual_module_count=28
$c.receipt=$rp;$c.receipt_sha256=$report.receipt_sha256;$c.final_inventory=Join-Path (Get-Location) $inventoryPath;$c.final_inventory_sha256=$report.inventory_sha256;$c.final_report=$out;$c.final_report_sha256=Sha $out;$c.safe_next_owned_workload_only=$true
[IO.File]::WriteAllText((Join-Path (Get-Location) $cp),($c|ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{context_sha256=(Sha $cp);final_report_sha256=$c.final_report_sha256;inventory_sha256=$c.final_inventory_sha256;receipt_sha256=$c.receipt_sha256;status=$c.status;tests=425;modules=28;scope_quiet=$r.scope_cleanup_grace_seconds;outer_quiet=$r.cleanup_grace_seconds;boot=$r.final_boot_id;latency=$i.latency}|ConvertTo-Json -Depth 5

