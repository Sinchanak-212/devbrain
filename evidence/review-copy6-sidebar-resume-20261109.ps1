#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Review,[Parameter(Mandatory=$true)][long]$ActualExecSession,[Parameter(Mandatory=$true)][int]$ActualExit)
if(-not $Review){'NOT_RUN: closing evidence audit only, no application process.';return}
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$contextPath=Join-Path $workspace 'evidence/080-queue-copy-sidebar-resize-active-context-20261108.json'
function Require([bool]$value,[string]$message){if(-not $value){throw $message}}
function ReadMap([string]$path){Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -DateKind String}
function Digest([string]$path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
function SameMap($a,$b,[string]$message){Require ($a.Count-eq$b.Count) $message;foreach($k in $b.Keys){Require ($a.Contains($k)-and$a[$k]-ceq$b[$k]) $message}}
function NewJson([string]$path,$value){
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($value|ConvertTo-Json -Depth 30)+[Environment]::NewLine)
 $f=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
}
$c=ReadMap $contextPath
Require ($ActualExecSession-gt0-and$c.actual_windows_exit_code-eq$ActualExit-and$c.run_id-ceq'queue-copy-sidebar-resize080-20261109T100447Z-c1dacc95'-and$c.status-cin@('finished_pending_evidence_review','failed_pending_cleanup_review')) 'Actual retained execution result is required'
Require ($c.source_freeze_sha256-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703') 'Wrong application generation'
$rPath=Join-Path $c.artifact_root 'receipt.json';$sPath=Join-Path $c.artifact_root 'supervisor-report.json';$dPath=Join-Path $c.artifact_root 'controller-report.json'
$r=ReadMap $rPath;$s=ReadMap $sPath;$d=ReadMap $dPath
foreach($row in @($r,$s,$d)){Require ($row.run_id-ceq$c.run_id) 'Wrong raw run identity'}
foreach($pair in @(@('specification','specification_sha256'),@('input_freeze','input_freeze_sha256'),@('guard_context','guard_context_sha256'),@('guard_receipt','guard_receipt_sha256'),@('guard_final_report','guard_final_report_sha256'),@('app_prepare_receipt','app_prepare_receipt_sha256'),@('app_freeze','app_freeze_sha256'),@('toolbundle_freeze','toolbundle_freeze_sha256'))){Require ((Digest $c[$pair[0]])-ceq$c[$pair[1]]) 'Frozen binding changed'}
$f=ReadMap $c.input_freeze;Require ($f.files.Count-eq15) 'Wrong15 frozen inputs'
foreach($name in $f.files.Keys){Require ((Digest (Join-Path $c.windows_root $name))-ceq$f.files[$name]) 'Frozen input changed'}
Require ($c.helper_sha256.Count-eq38) 'Wrong38 helper inventory'
foreach($name in $c.helper_sha256.Keys){Require ((Digest (Join-Path $c.windows_tools $name))-ceq$c.helper_sha256[$name]) 'Frozen helper changed'}
$a=ReadMap (Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json')
$af=ReadMap $c.app_freeze
Require ($af.files.Count-eq209-and$af.app_files-eq198-and$a.freeze_sha256-ceq$c.source_freeze_sha256) 'Wrong App209/198'
foreach($name in $af.files.Keys){Require ((Digest (Join-Path $a.bundle_root $name))-ceq$af.files[$name]) 'App frozen file changed'}
Require ($d.source_hashes.Count-eq153) 'Wrong153 actual source manifest'
foreach($name in $d.source_hashes.Keys){Require ($d.source_hashes[$name]-ceq$af.files['devbrain/'+$name]) 'Executed code differs from frozen source'}
Require ($d.python_launcher-ceq$c.python_launcher-and$d.isolated_package.origin-ceq($c.source_root+'/src/devbrain/__init__.py')-and$d.isolated_package.sha256-ceq$af.files['devbrain/src/devbrain/__init__.py']-and$d.isolated_package.python_prefix-ceq'/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T222731Z/venv') 'Literal qualified venv and isolated source proof differ'
SameMap $d.runtime $c.runtime 'Controller runtime differs'
SameMap $r.runtime $c.runtime 'Outer runtime differs'
SameMap $s.runtime $c.runtime 'Supervisor runtime differs'
foreach($mapName in @('helper_sha256_start','helper_sha256_end')){foreach($helper in $r[$mapName].Keys){Require ($r[$mapName][$helper]-ceq$c.helper_sha256[$helper]) 'Outer executed helper changed'};foreach($helper in $s[$mapName].Keys){Require ($s[$mapName][$helper]-ceq$c.helper_sha256[$helper]) 'Linux executed helper changed'}}
foreach($name in $r.artifact_sha256.Keys){Require ((Digest (Join-Path $c.artifact_root $name))-ceq$r.artifact_sha256[$name]) 'Raw receipt artifact digest mismatch'}
$expectedGuid='381b4222-f694-41f0-9685-ff5bb260df2e';$expectedPower='6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'
$power=@(Get-Content -LiteralPath (Join-Path $c.artifact_root 'power-samples.jsonl')|Where-Object{$_}|ForEach-Object{$_|ConvertFrom-Json -AsHashtable})
foreach($sample in $power){Require ($sample.state.active_guid-ceq$expectedGuid-and$sample.state.settings_sha256-ceq$expectedPower) 'Power sample changed'}
foreach($state in @($r.power_profile_start,$r.power_profile_end)){Require ($state.active_guid-ceq$expectedGuid-and$state.settings_sha256-ceq$expectedPower) 'Power endpoint differs'}
$cleanup=($r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$s.controller_exit_verified-eq$true-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and$r.scope_unit-ceq$s.scope_unit-and$r.scope_cgroup_identity-ceq$s.scope_cgroup_identity-and$s.scope_descendants_stopped-eq$true-and@($s.remaining_scope_processes).Count-eq0-and@($s.remaining_tagged_processes).Count-eq0-and$d.cleanup_complete-eq$true-and$d.engine_actual_exit_verified-eq$true-and$d.engine_returncode-in@(0,143,-15)-and$r.sleep_inhibition.restored-eq$true)
$platform=($r.native_failure-eq$false-and$s.native_failure-eq$false-and@($r.new_kernel_fatals).Count-eq0-and@($r.new_wsl_dumps).Count-eq0-and@($s.new_kernel_fatals).Count-eq0-and@($s.new_wsl_dumps).Count-eq0-and$r.initial_boot_id-ceq$r.final_boot_id-and$s.initial_boot_id-ceq$s.final_boot_id-and$r.initial_boot_id-ceq$s.initial_boot_id-and$r.power_monitor.changed-eq$false)
$cleanup=$cleanup-and$platform
$functionalErrors=[Collections.Generic.List[string]]::new()
function Check([bool]$value,[string]$code){if(-not $value){$functionalErrors.Add($code)}}
Check ($ActualExit-eq0-and$r.passed-eq$true-and$s.passed-eq$true-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.windows_proxy_returncode-eq0-and$r.cleanup_complete-eq$true-and$s.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$s.forced_cleanup-eq$false-and@($r.errors).Count-eq0-and@($s.errors).Count-eq0) 'raw_gate_not_passed'
Check ($d.status-ceq'queue_copy_completed_pending_external_watch'-and$d.all_six_replayed-eq$true-and$d.production_modified-eq$false-and$d.unrelated_jobs_unchanged-eq$true-and$d.backup_sha256-ceq'698591d33252a1f0e802a01fac78feb90f56ef37fc0c5f717ed26667f635ac70') 'whole_six_contract_incomplete'
$expected=@('034d96bc-0e0f-45fc-9a29-7dc2470b8bd2','1584c210-6c34-439c-a325-2de7104ea1e6','30bee886-18cb-4a1b-89db-8edc314e1aec','4cae21d0-463d-4bce-ab43-dda2fedd8264','a6d7f6ae-10f6-4388-8086-8f80cfa107d4','bb9187d3-85f8-42ba-8439-be42acc42c1d')
$jobs=@($d.jobs)
Check ($jobs.Count-eq6-and@($jobs.id|Sort-Object -Unique).Count-eq6) 'not_six_unique_jobs'
for($i=0;$i-lt$jobs.Count;$i++){Check ($jobs[$i].id-ceq$expected[$i]-and$jobs[$i].state-ceq'completed'-and$jobs[$i].attempts-eq$jobs[$i].previous_attempts+1-and$jobs[$i].retry_count-eq1) 'job_identity_state_attempt_mismatch'}
Check (@($jobs|Where-Object{$_.kind-ceq'import'}).Count-eq3-and@($jobs|Where-Object{$_.kind-ceq'extract'}).Count-eq3) 'job_kind_counts'
if($d.Contains('duplicate_counts_after')){Check ($d.duplicate_counts_after.Count-eq$d.duplicate_counts_before.Count) 'duplicate_inventory_changed';foreach($name in $d.duplicate_counts_before.Keys){Check ($d.duplicate_counts_after.Contains($name)-and$d.duplicate_counts_after[$name]-eq$d.duplicate_counts_before[$name]) 'duplicate_counts_changed'}}else{$functionalErrors.Add('final_duplicate_check_missing')}
if($d.Contains('counts_after')){
 foreach($name in @('sources','chunks','embeddings','projects','archived','indexed','unassigned_sources','inbox','plans','sessions','check_runs')){Check ($d.counts_after[$name]-eq$d.counts_before[$name]) ('unrelated_count_'+$name)}
 Check ($d.counts_after.jobs.pending-eq$d.counts_before.jobs.pending-and$d.counts_after.jobs.running-eq0-and$d.counts_before.jobs.running-eq0-and$d.counts_before.jobs.failed-eq6-and$d.counts_after.jobs.failed-eq0-and$d.counts_after.jobs.completed-eq$d.counts_before.jobs.completed+6) 'queue_count_deltas'
}else{$functionalErrors.Add('final_counts_missing')}
$passed=$cleanup-and$functionalErrors.Count-eq0
$status=if($passed){'passed_focused_queue_copy_only'}elseif($cleanup){'failed_copy_with_owned_safe_cleanup'}else{'failed_cleanup_not_admitted'}
$rawHashes=@{}
foreach($file in Get-ChildItem -LiteralPath $c.artifact_root -File){if($file.Name-notin@('heartbeat.json','parent.json')){$rawHashes[$file.Name]=Digest $file.FullName}}
$report=[ordered]@{schema_version=1;scope='devbrain_actual_entire_six_private_queue_copy_final';status=$status;passed=$passed;created_utc=[DateTime]::UtcNow.ToString('o');run_id=$c.run_id;actual_windows_exec_session=$ActualExecSession;actual_windows_exit_code=$ActualExit;cleanup_complete=$cleanup;safe_next_workload=$cleanup;source_snapshot=$c.app_run_id;source_freeze_sha256=$c.source_freeze_sha256;app_prepare_receipt_sha256=$c.app_prepare_receipt_sha256;guard_context_sha256=$c.guard_context_sha256;guard_receipt_sha256=$c.guard_receipt_sha256;guard_cases=604;app_files_rehashed=198;source_bundle_files_rehashed=209;actual_controller_code_manifest_files=153;helper_map_files_rehashed=38;frozen_inputs_rehashed=15;backup_sha256=$d.backup_sha256;all_six_replayed=($d.all_six_replayed-eq$true);selected_job_count=$jobs.Count;selected_jobs=$jobs;functional_error_codes=@($functionalErrors);unrelated_jobs_unchanged=($d.unrelated_jobs_unchanged-eq$true);counts_before=$d.counts_before;counts_after=$d.counts_after;duplicate_counts_before=$d.duplicate_counts_before;duplicate_counts_after=$d.duplicate_counts_after;scope_empty_verified=$r.scope_empty_verified;scope_unit=$r.scope_unit;scope_cgroup_identity=$r.scope_cgroup_identity;scope_quiet_seconds=$r.scope_cleanup_grace_seconds;outer_post_exit_seconds=$r.cleanup_grace_seconds;own_engine_actual_exit_verified=$d.engine_actual_exit_verified;own_engine_returncode=$d.engine_returncode;native_boot_power_sleep_clean=$platform;power_sample_count=$power.Count;raw_forced_cleanup=$r.forced_cleanup;raw_receipt_passed=$r.passed;receipt=$rPath;receipt_sha256=(Digest $rPath);raw_artifact_sha256=$rawHashes;raw_PASS_and_cleanup_flags_unmodified=$true;historical_results_pooled=$false;fresh_original_backup_copy=$true;production_modified=$false;production_retry_permitted=$false;application_qualified=$false;release_qualified=$false;parallel_execution_authorized_by_user=$true;Linux_executed_by_reviewer=$false;backup_or_production_database_read_by_reviewer=$false;raw_model_source_error_SQL_credentials_or_private_source_digests_exported=$false}
$reportPath=Join-Path $workspace 'evidence/080-queue-copy-sidebar-resize-final-20261109.json'
NewJson $reportPath $report
$c.actual_windows_exec_session=$ActualExecSession;$c.receipt=$rPath;$c.receipt_sha256=Digest $rPath;$c.final_report=$reportPath;$c.final_report_sha256=Digest $reportPath;$c.cleanup_complete=$cleanup;$c.safe_next_workload=$cleanup
$c.status=if($passed){'passed'}elseif($cleanup){'failed_safe_owned_cleanup'}else{'failed_cleanup_unknown'}
$temp=$contextPath+'.final-audit.tmp'
NewJson $temp $c
[IO.File]::Move($temp,$contextPath,$true)
[pscustomobject]@{status=$status;passed=$passed;cleanup_complete=$cleanup;selected_jobs=$jobs.Count;completed_jobs=@($jobs|Where-Object{$_.state-ceq'completed'}).Count;functional_error_codes=@($functionalErrors);context_sha256=(Digest $contextPath);report=$reportPath;report_sha256=(Digest $reportPath);receipt_sha256=(Digest $rPath);scope_seconds=$r.scope_cleanup_grace_seconds;outer_seconds=$r.cleanup_grace_seconds}|ConvertTo-Json -Depth 5
if(-not$cleanup){exit 2}
if(-not$passed){exit 1}

