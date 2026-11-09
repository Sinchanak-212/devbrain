# Windows-only closing review for the fresh diagnostic environment. No Linux calls.
$ErrorActionPreference='Stop'
function Need([bool]$ok,[string]$why){if(-not$ok){throw $why}}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read([string]$p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -AsHashtable -DateKind String}
function Match($a,$b,[string]$why){Need ($a.Count-eq$b.Count) $why;foreach($k in $b.Keys){Need ($a.Contains($k)-and$a[$k]-ceq$b[$k]) $why}}
$cp='evidence/080-app-native-failure-diagnostic-prepared-context-20261109.json';$c=Read $cp
Need ($c.run_id-ceq'app-uxfailure080-20261109T120522Z-f12a3079'-and$c.actual_windows_exec_session-eq43687) 'Wrong actual prepare'
Need ((Sha $c.root_reviewed_context)-ceq'8a88e1389dcb53ca87fdd688af7682ae1265f70dc72689f95a7793d190bf9908') 'Reviewed preparation context changed'
$a=Join-Path $c.artifact_root prepare;$rp=Join-Path $a receipt.json
$r=Read $rp;$d=Read (Join-Path $a controller-report.json);$w=Read (Join-Path $a workload-report.json)
foreach($v in @($r,$d)){Need ($v.run_id-ceq$c.run_id-and$v.phase-ceq'prepare') 'Run/phase binding differs'}
Need ($r.passed-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.controller_exit_verified-eq$true-and$r.proxy_exit_code-eq0-and$r.runtime_verified_after_cleanup-eq$true-and$r.cleanup_grace_seconds-ge30) 'Prepare/actual cleanup failed'
foreach($v in @($r,$d)){foreach($k in @('errors','new_kernel_fatals','new_wsl_dumps')){Need ($v.Contains($k)-and@($v[$k]).Count-eq0) 'Prepare has faults'}}
Need ($d.status-ceq'controller_passed_pending_external_watch'-and$d.worker_returncode-eq0-and$d.control_group.EndsWith('/'+$r.unit)-and$d.memory_max-ceq'4294967296'-and$d.memory_swap_max-ceq'0') 'Actual worker/scope proof differs'
Need ($w.status-ceq'workload_passed_pending_external_watch'-and$w.phase-ceq'prepare'-and$w.diagnostic_only-eq$true) 'Workload prepare incomplete'
Need ((Sha (Join-Path $a controller-report.json))-ceq$r.controller_report_sha256-and(Sha (Join-Path $a workload-report.json))-ceq$r.workload_report_sha256-and$d.workload_sha256-ceq$r.workload_report_sha256) 'Report binding differs'
$bm=Join-Path $c.artifact_root bundle-manifest.json;Need ((Sha $bm)-ceq$r.bundle_manifest_sha256) 'Bundle receipt binding differs'
Need ((Sha $c.freeze_manifest)-ceq'9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9') 'Source freeze changed'
$af=Read $c.freeze_manifest;$manifest=Read $bm;Match $manifest.files $af.files 'Prepare ran a different209bundle'
Need ($af.files.Count-eq209-and$af.app_files-eq198) 'Wrong source inventory'
$expected=@{}
foreach($rel in $af.files.Keys){$p=Join-Path $c.bundle_root $rel;Need ((Sha $p)-ceq$af.files[$rel]) 'Bundle mutated';if($rel.StartsWith('devbrain/')){$expected[$rel.Substring(9)]=$af.files[$rel]}}
Need ($expected.Count-eq198) 'Wrong Linux App count';Match $w.source_manifest $expected 'Linux source not exact Windows source'
Need ((Sha $c.input_freeze)-ceq'073aba9e264c65d598dff07ad614674663c917c9ec6665cda919aec42bb7f343') 'Inputs freeze changed';$i=Read $c.input_freeze
Need ($i.files.Count-eq12) 'Wrong input count';foreach($rel in $i.files.Keys){Need ((Sha (Join-Path $c.windows_root $rel))-ceq$i.files[$rel]) 'Input changed'}
foreach($n in $c.canonical_regression_helper_sha256.Keys){Need ((Sha (Join-Path $c.canonical_regression_windows_tools $n))-ceq$c.canonical_regression_helper_sha256[$n]) 'Canonical38 changed'}
Need ($c.canonical_regression_helper_sha256.Count-eq38) 'Canonical helper count differs'
$old=Read $c.previous_app_context;Need ((Sha $c.previous_app_context)-ceq' d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'.Trim()) 'Global App context changed'
$oldFreeze=Read $old.freeze_manifest;Need ((Sha $old.freeze_manifest)-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703') 'Historical freeze changed'
foreach($rel in $oldFreeze.files.Keys){Need ((Sha (Join-Path $old.bundle_root $rel))-ceq$oldFreeze.files[$rel]) 'Historical bundle changed';if($rel.StartsWith('devbrain/')){Need ((Sha (Join-Path (Get-Location) $rel))-ceq$oldFreeze.files[$rel]) 'Working App changed'}}
$oldReceipt=Read $old.setup_receipt;foreach($v in @($d.runtime,$d.runtime_end,$w.runtime,$w.runtime_end,$r.runtime)){Match $v $oldReceipt.runtime 'Qualified runtime differs'}
$identity=Read (Join-Path $a installed-identity.json)
Need ($identity.origin-ceq($c.source_root+'/src/devbrain/__init__.py')-and$identity.prefix-ceq($c.linux_root+'/venv')-and$identity.base-ceq$r.runtime.python_executable) 'Installed identity differs'
$oldIdentity=Read (Join-Path $old.artifact_root 'prepare/installed-identity.json')
$pk=@{};$oldpk=@{}
foreach($pair in $identity.packages){Need (-not$pk.Contains($pair[0])) 'Duplicate installed distribution';$pk[$pair[0]]=$pair[1]}
foreach($pair in $oldIdentity.packages){$oldpk[$pair[0]]=$pair[1]}
Need ($pk.Count-eq59) 'Qualified package inventory not59';Match $pk $oldpk 'Pinned installed distribution versions differ'
$dependencyLines=@(Get-Content -LiteralPath (Join-Path $c.bundle_root requirements.txt)|Where-Object{$_.Trim()-and-not$_.Trim().StartsWith('#')})
Need ($dependencyLines.Count-eq58-and(Sha (Join-Path $c.bundle_root requirements.txt))-ceq'da5edd5506fe2ed399445d193aaec9f3ebe021acac4510f888f4474258646d6a') 'Dependency pins differ'
Need ($r.initial_boot_id-ceq$r.final_boot_id-and$d.initial_boot_id-ceq$r.initial_boot_id-and$d.final_boot_id-ceq$r.initial_boot_id) 'In-run boot changed'
Need ($r.sleep_inhibition.acquired-eq$true-and$r.sleep_inhibition.restored-eq$true) 'Sleep inhibition not restored'
Need ($r.power_profile_start.active_guid-ceq'381b4222-f694-41f0-9685-ff5bb260df2e'-and$r.power_profile_start.settings_sha256-ceq'6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'-and$r.power_profile_start.setting_count-eq183) 'Power baseline not qualified Balanced'
Match $r.power_profile_start $r.power_profile_end 'Power changed'
$points=@(Get-Content -LiteralPath (Join-Path $a power-samples.jsonl)|ForEach-Object{$_|ConvertFrom-Json -AsHashtable})
Need ($points.Count-eq$r.power_monitor.sample_count-and$points.Count-ge2) 'Power samples missing'
foreach($point in $points){Match $point.state $r.power_profile_start 'Sample power changed'}
Need ($r.power_monitor.maximum_observed_gap_seconds-le45-and$points[-1].elapsed_seconds-ge($r.cleanup_confirmed_elapsed_seconds+30)) 'Power tail incomplete'
Need ((Sha (Join-Path $a power-samples.jsonl))-ceq$r.power_samples_sha256) 'Power samples changed'
$probe=Get-Content -LiteralPath (Join-Path $a probe.out.log) -Raw
Need ($probe.StartsWith('BOOT='+$r.final_boot_id+[char]10+'LOAD=not-found'+[char]10+'GROUP='+[char]10+'POPULATED=0'+[char]10)) 'Final scope/boot probe not empty'
foreach($n in @('probe.err.log','controller.err.log')){Need ((Get-Item -LiteralPath (Join-Path $a $n)).Length-eq0) 'Probe/controller stderr nonempty'}
Need ((Sha (Join-Path $c.artifact_root global-crash-baseline.json))-ceq$r.global_crash_baseline_sha256-and(Sha (Join-Path $c.artifact_root global-kernel-baseline.json))-ceq$r.global_kernel_baseline_sha256) 'Crash/kernel baseline binding differs'
$all=@{};foreach($file in Get-ChildItem -LiteralPath $c.artifact_root -Recurse -File){$all[$file.FullName.Substring($c.artifact_root.Length+1).Replace('\','/')]=Sha $file.FullName}
$report=@{
 schema_version=1;scope='isolated_diagnostic_App_prepare_closing_review';status='prepared_passed_diagnostic_only';run_id=$c.run_id
 actual_windows_exec_session=43687;actual_windows_exit_code=0;actual_exit_chunk='c412ae';initial_exec_chunk='d068a4'
 passed=$true;preparation_passed=$true;cleanup_complete=$true;safe_next_owned_scope_only=$true;next_launch_requires_root_GO=$true
 receipt=$rp;receipt_sha256=(Sha $rp);setup_workload_sha256=$r.workload_report_sha256;controller_report_sha256=$r.controller_report_sha256
 runtime=$r.runtime;runtime_verified_after_cleanup=$true;qualified_package_pin_count=59;pinned_dependency_lines=58;pins_unchanged=$true;linux_source_matches_freeze=$true
 source_freeze_sha256=$c.freeze_sha256;app_files=198;bundle_files=209;frozen_inputs=12;canonical_helpers_unchanged=38;working_App198_and_old_bundle209_unchanged=$true;global_App_context_unchanged=$true
 source_root=$c.source_root;python_launcher=$c.python_launcher;installed_identity=$identity
 actual_controller_exit_verified=$r.controller_exit_verified;actual_worker_returncode=0;scope_unit=$r.unit;scope_empty_verified=$true;final_scope_load='not-found';final_scope_populated=0
 cleanup_grace_seconds=$r.cleanup_grace_seconds;forced_cleanup=$false;native_failure=$false;new_kernel_fatals=@();new_wsl_dumps=@()
 initial_boot_id=$r.initial_boot_id;final_boot_id=$r.final_boot_id;in_run_boot_unchanged=$true;between_closed_trials_WSL_auto_idle_allowed_by_root=$true;old_HostGO_boot_not_reused=$true
 power_unchanged=$true;power_samples=$points.Count;maximum_observed_power_gap_seconds=$r.power_monitor.maximum_observed_gap_seconds;sleep_inhibition_restored=$true
 raw_artifact_sha256=$all;application_qualified=$false;release_qualified=$false;source_final=$false;eight_hour_started=$false;models_auth_or_private_database_started=$false
 created_utc=[DateTime]::UtcNow.ToString('o')
}
$outPath=Join-Path (Get-Location) 'evidence/080-app-native-failure-diagnostic-prepare-final-20261109.json'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($report|ConvertTo-Json -Depth 20))
$stream=[IO.File]::Open($outPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
$c.status='prepared_passed_diagnostic_only';$c.runtime_prepared=$true;$c.actual_windows_exit_code=0;$c.cleanup_complete=$true;$c.cleanup_grace_seconds=$r.cleanup_grace_seconds;$c.native_failure=$false
$c.setup_receipt=$rp;$c.setup_receipt_sha256=$report.receipt_sha256;$c.setup_workload_sha256=$report.setup_workload_sha256
$c.qualified_package_pin_count=59;$c.pinned_dependency_lines=58;$c.pins_unchanged=$true;$c.linux_source_matches_freeze=$true;$c.actual_source_files=198
$c.source_freeze_sha256=$c.freeze_sha256;$c.final_report=$outPath;$c.final_report_sha256=Sha $outPath;$c.prepared_boot_id=$r.final_boot_id;$c.finished_utc=$r.finished_utc
[IO.File]::WriteAllText((Join-Path (Get-Location) $cp),($c|ConvertTo-Json -Depth 35),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{status=$c.status;actual_windows_exec_session=43687;actual_exit=0;context_sha256=(Sha $cp);receipt_sha256=$c.setup_receipt_sha256;final_report_sha256=$c.final_report_sha256
 source_freeze_sha256=$c.freeze_sha256;cleanup_seconds=$r.cleanup_grace_seconds;boot=$r.final_boot_id;packages=59;dependency_pins=58;Linux_source=198;power_samples=$points.Count;next_GO_required=$true}|ConvertTo-Json -Depth 4

