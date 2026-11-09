#Requires -Version 7.5
param([switch]$Review)
if(-not $Review){'NOT_RUN: read-only failed-probe closure review.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function AuditHash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Need($value,[string]$reason){if(-not $value){throw $reason}}
function ReadAuditMap([string]$p){Get-Content -Raw -LiteralPath $p|ConvertFrom-Json -AsHashtable}
$ptrPath=Join-Path $PSScriptRoot '080-terminal-input-probe-active-pointer-20261109.json'
$ptr=ReadAuditMap $ptrPath
$ctx=$ptr.active_context;$c=ReadAuditMap $ctx;$art=$c.artifact_root
$r=ReadAuditMap (Join-Path $art 'receipt.json');$s=ReadAuditMap (Join-Path $art 'supervisor-report.json');$p=ReadAuditMap (Join-Path $art 'controller-report.json');$x=ReadAuditMap (Join-Path $art 'supervisor-exit.json')
Need ($c.actual_windows_exit_code-eq1-and$c.status-ceq'diagnostic_failed_pending_cleanup_review'-and$ptr.actual_windows_exec_session-eq80360) 'Actual Windows exit mismatch'
Need ($p.status-ceq'failed'-and@($p.errors).Count-eq1-and$p.errors[0]-ceq'actual_renderer_confirmation_timeout'-and$p.arms.Count-eq0) 'Unexpected probe outcome'
Need ($p.cleanup_complete-eq$true-and$p.cleanup_grace_seconds-ge30-and$p.external_viewers_actual_exit_verified-eq$true-and$p.owned_servers_actual_exit_verified-eq$true) 'Controller cleanup missing'
Need ($s.child_returncode-eq1-and$s.controller_exit_verified-eq$true-and$s.cleanup_complete-eq$true-and$s.scope_descendants_stopped-eq$true-and$s.cleanup_grace_seconds-ge30-and$s.forced_cleanup-eq$false-and$s.native_failure-eq$false) 'Supervisor cleanup missing'
Need (($s.errors-join'|')-ceq'RuntimeError: Controller returned a nonzero exit code|Final verification: Unsupported or incomplete controller status') 'Unexpected supervisor failure'
Need (($r.errors-join'|')-ceq'Linux supervisor returned nonzero or crashed.|Final evidence verification: Supervisor did not verify passed.|Actual successful supervisor exit was not verified.|Owned scope emptiness and post-cleanup grace were not verified.') 'Unexpected external failure'
foreach($k in @('remaining_scope_processes','remaining_tagged_processes','new_kernel_fatals','new_wsl_dumps')){Need (@($s[$k]).Count-eq0) 'Supervisor residual/native evidence'}
Need ($r.supervisor_exit_verified-eq$true-and$r.supervisor_returncode-eq1-and$r.windows_proxy_returncode-eq1-and$x.actual_exit_verified-eq$true-and$x.stdio_complete-eq$true) 'Actual supervisor exit missing'
Need ($r.scope_initially_absent-eq$true-and$r.scope_membership_verified-eq$true-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30) 'External scope cleanup observation missing'
Need ($r.native_failure-eq$false-and@($r.new_wsl_dumps).Count-eq0-and@($r.new_kernel_fatals).Count-eq0-and$r.initial_boot_id-ceq$r.final_boot_id-and$r.initial_boot_id-ceq$s.initial_boot_id-and$s.initial_boot_id-ceq$s.final_boot_id) 'Native/boot fault'
Need ($r.scope_unit-ceq$s.scope_unit-and$r.control_group-ceq$s.control_group-and$r.scope_cgroup_identity-ceq$s.scope_cgroup_identity) 'Scope bindings differ'
Need ($r.sleep_inhibition.acquired-eq$true-and$r.sleep_inhibition.restored-eq$true-and$r.power_monitor.changed-eq$false-and$r.power_monitor.sample_count-ge2) 'Power/sleep restoration missing'
$powerSha='6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'
Need ($r.power_profile_start.settings_sha256-ceq$powerSha-and$r.power_profile_end.settings_sha256-ceq$powerSha) 'Power settings changed'
$last=-1;$count=0
foreach($line in [IO.File]::ReadLines((Join-Path $art 'power-samples.jsonl'))){
 $value=$line|ConvertFrom-Json -AsHashtable
 Need ($value.state.active_guid-ceq'381b4222-f694-41f0-9685-ff5bb260df2e'-and$value.state.settings_sha256-ceq$powerSha-and$value.state.setting_count-eq183) 'Power sample changed'
 Need ($value.elapsed_seconds-ge$last-and($last-lt0-or$value.elapsed_seconds-$last-le45)) 'Power gap'
 $last=$value.elapsed_seconds;$count++
}
Need ($count-eq$r.power_monitor.sample_count-and$last-ge$r.power_monitor.scope_empty_elapsed_seconds+30) 'Power post-observation incomplete'
$scope=[IO.File]::ReadAllText((Join-Path $art 'probe-scope.stdout.log'))
Need ($scope.StartsWith("LOAD=not-found`nGROUP=`nPOPULATED=0`nIDENTITY=`n")) 'Final unit/cgroup not absent'
foreach($rel in $r.artifact_sha256.Keys){Need ((AuditHash (Join-Path $art $rel))-ceq$r.artifact_sha256[$rel]) 'Artifact changed'}
foreach($key in $r.input_sha256_start.Keys){Need ($r.input_sha256_start[$key]-ceq$r.input_sha256_end[$key]) 'Observed input changed'}
$f=ReadAuditMap $c.input_freeze
Need ((AuditHash $c.input_freeze)-ceq$c.input_freeze_sha256-and$f.files.Count-eq48) 'Input freeze differs'
foreach($rel in $f.files.Keys){Need ((AuditHash (Join-Path $c.windows_root $rel))-ceq$f.files[$rel]) 'Frozen input changed'}
foreach($key in $r.helper_sha256_start.Keys){Need ($r.helper_sha256_start[$key]-ceq$r.helper_sha256_end[$key]-and$r.helper_sha256_start[$key]-ceq$c.helper_sha256[$key]) 'Helper changed'}
Need ((AuditHash $c.source_freeze)-ceq$c.source_freeze_sha256) 'Source manifest changed'
$source=ReadAuditMap $c.source_freeze
foreach($rel in $source.files.Keys){Need ((AuditHash (Join-Path $c.app_bundle_root $rel))-ceq$source.files[$rel]) 'App source changed'}
Need ((AuditHash $ptr.prepared_context)-ceq$ptr.prepared_context_sha256) 'Historical context changed'
foreach($arm in @('direct','bridge')){
 Need (-not(Test-Path -LiteralPath (Join-Path $art ('external-viewer-'+$arm+'.json')))) 'Unexpected viewer admission'
 Need (-not(Test-Path -LiteralPath (Join-Path $art ('windows-renderer-launch-'+$arm+'.json')))) 'Unexpected Windows renderer launch'
}
$reportPath=Join-Path $PSScriptRoot '080-terminal-input-probe-first-failed-safe-next-20261109.json'
Need (-not(Test-Path -LiteralPath $reportPath)) 'Review exists'
$report=@{
 schema_version=1;scope='devbrain_terminal_probe_failed_run_closure';status='failed_setup_but_owned_cleanup_verified';diagnostic_result='NOT_COMPLETED'
 actual_windows_exec_session=80360;actual_windows_exit_code=1;active_context=$ctx;active_context_sha256=(AuditHash $ctx);prepared_context_sha256=$ptr.prepared_context_sha256
 receipt_sha256=(AuditHash (Join-Path $art 'receipt.json'));controller_sha256=(AuditHash (Join-Path $art 'controller-report.json'));supervisor_sha256=(AuditHash (Join-Path $art 'supervisor-report.json'))
 supervisor_actual_exit_verified=$true;controller_actual_exit_verified=$true;controller_actual_exit_code=1;cause='actual_renderer_confirmation_timeout';completed_arms=0;WT_viewers_admitted=0
 scope_final_load_state='not-found';scope_population=0;scope_cleanup_grace_seconds=$r.scope_cleanup_grace_seconds;external_post_exit_seconds=$r.cleanup_grace_seconds;controller_post_cleanup_seconds=$p.cleanup_grace_seconds;supervisor_post_cleanup_seconds=$s.cleanup_grace_seconds
 sleep_restored=$true;native_failure=$false;boot_changed=$false;power_changed=$false;frozen_files_unchanged=$f.files.Count;app_bundle_files_unchanged=$source.files.Count;source_freeze_sha256=$c.source_freeze_sha256
 original_raw_failed_receipt_retained=$true;raw_receipt_passed=$r.passed;raw_receipt_cleanup_complete=$r.cleanup_complete;raw_receipt_forced_cleanup=$r.forced_cleanup
 raw_receipt_forced_flag_explanation='Canonical Windows wrapper requests exact owned scope stop on every nonzero supervisor exit; raw failure flags retained. Final unit absent and post-cleanup observation verified separately.'
 safe_for_next_owned_diagnostic=$true;application_qualified=$false;release_qualified=$false;model_requests=0;account_operations=0;database_started=$false;production_modified=$false;eight_hour_started=$false
 prior_readonly_audit_attempt=@{chunk='fcab9b';actual_exit_code=1;cause='PowerShell H alias collision before any publication';corrected='Distinct AuditHash function; all checks repeated'}
}
[IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$ptr.status='failed_setup_cleanup_verified';$ptr.active_context_sha256=AuditHash $ctx;$ptr.actual_windows_exit_code=1;$ptr.actual_windows_exec_session=80360;$ptr.closing_report=$reportPath;$ptr.closing_report_sha256=AuditHash $reportPath
[IO.File]::WriteAllText($ptrPath,($ptr|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
@{report=$reportPath;sha256=(AuditHash $reportPath);safe_for_next_owned_diagnostic=$true;actual_session=80360;actual_exit=1;scope_post_seconds=$r.scope_cleanup_grace_seconds;external_post_seconds=$r.cleanup_grace_seconds;source_files=$source.files.Count}|ConvertTo-Json
