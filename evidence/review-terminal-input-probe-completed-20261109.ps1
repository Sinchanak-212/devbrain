#Requires -Version 7.5
param([switch]$Review)
if(-not $Review){'NOT_RUN: read-only closure of the second terminal diagnostic.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function AuditHash([string]$p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Need($value,[string]$reason){if(-not $value){throw $reason}}
function ReadAuditMap([string]$p){Get-Content -Raw -LiteralPath $p|ConvertFrom-Json -AsHashtable}
$ptrPath=Join-Path $PSScriptRoot '080-terminal-input-probe-active-pointer-v2-20261109.json'
$ptr=ReadAuditMap $ptrPath;$ctx=$ptr.active_context;$c=ReadAuditMap $ctx;$art=$c.artifact_root
Need ($ptr.actual_windows_exec_session-eq76368-and$c.actual_windows_exit_code-eq0-and$c.status-ceq'diagnostic_finished_pending_evidence_review') 'Actual final Windows exit is required'
$r=ReadAuditMap (Join-Path $art 'receipt.json');$s=ReadAuditMap (Join-Path $art 'supervisor-report.json');$p=ReadAuditMap (Join-Path $art 'controller-report.json')
Need ($r.passed-eq$true-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.windows_proxy_returncode-eq0) 'External closure did not pass'
Need ($r.scope_initially_absent-eq$true-and$r.scope_membership_verified-eq$true-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and$r.sleep_inhibition.restored-eq$true-and$r.power_monitor.changed-eq$false) 'External scope/power cleanup incomplete'
Need ($s.passed-eq$true-and$s.cleanup_complete-eq$true-and$s.controller_exit_verified-eq$true-and$s.forced_cleanup-eq$false-and$s.native_failure-eq$false-and$s.scope_descendants_stopped-eq$true-and$s.cleanup_grace_seconds-ge30-and$s.child_returncode-eq0) 'Linux supervision incomplete'
foreach($map in @($r,$s)){foreach($k in @('errors','new_wsl_dumps','new_kernel_fatals')){Need (@($map[$k]).Count-eq0) 'Native failure or observer error'}}
foreach($k in @('remaining_scope_processes','remaining_tagged_processes')){Need (@($s[$k]).Count-eq0) 'Process remains'}
Need ($r.initial_boot_id-ceq$r.final_boot_id-and$s.initial_boot_id-ceq$s.final_boot_id-and$r.initial_boot_id-ceq$s.initial_boot_id-and$r.scope_unit-ceq$s.scope_unit-and$r.scope_cgroup_identity-ceq$s.scope_cgroup_identity-and$r.control_group-ceq$s.control_group) 'Boot/scope bindings differ'
Need ($p.status-ceq'terminal_probe_completed_pending_external_watch'-and$p.cleanup_complete-eq$true-and$p.cleanup_grace_seconds-ge30-and$p.forced_cleanup-eq$false-and@($p.errors).Count-eq0-and$p.arms.Count-eq2-and$p.workload_criteria_passed-eq$true-and$p.external_viewers_actual_exit_verified-eq$true-and$p.owned_servers_actual_exit_verified-eq$true) 'Controller comparison incomplete'
Need ($p.account_requests-eq0-and$p.local_model_inference-eq$false-and$p.database_started-eq$false-and$p.actual_Codex_process_started-eq$false-and$p.production_modified-eq$false-and$p.terminal_input_stability_qualified-eq$false-and$p.exact_crossterm_parser-eq$false-and$p.causal_conclusion-ceq'not_established') 'Diagnostic scope changed'
foreach($rel in $r.artifact_sha256.Keys){Need ((AuditHash (Join-Path $art $rel))-ceq$r.artifact_sha256[$rel]) 'Artifact changed'}
foreach($key in $r.input_sha256_start.Keys){Need ($r.input_sha256_start[$key]-ceq$r.input_sha256_end[$key]) 'Observed input changed'}
foreach($key in $r.helper_sha256_start.Keys){Need ($r.helper_sha256_start[$key]-ceq$r.helper_sha256_end[$key]-and$r.helper_sha256_start[$key]-ceq$c.helper_sha256[$key]) 'Helper changed'}
foreach($key in $c.runtime.Keys){Need ($r.runtime[$key]-ceq$c.runtime[$key]-and$s.runtime[$key]-ceq$c.runtime[$key]-and$p.runtime[$key]-ceq$c.runtime[$key]) 'Qualified runtime differs'}
Need ($r.python_launcher-ceq$c.python_launcher-and$r.python_launcher_base_sha256-ceq$c.runtime.python_binary_sha256-and$r.gate_sha256-ceq$c.runtime_gate_sha256) 'Launcher/gate differs'
Need ((AuditHash $c.input_freeze)-ceq$c.input_freeze_sha256) 'Input freeze changed'
$f=ReadAuditMap $c.input_freeze
foreach($rel in $f.files.Keys){Need ((AuditHash (Join-Path $c.windows_root $rel))-ceq$f.files[$rel]) 'Frozen input changed'}
Need ((AuditHash $c.source_freeze)-ceq$c.source_freeze_sha256) 'Source manifest changed'
$source=ReadAuditMap $c.source_freeze
foreach($rel in $source.files.Keys){Need ((AuditHash (Join-Path $c.app_bundle_root $rel))-ceq$source.files[$rel]) 'App source changed'}
Need ((AuditHash $ptr.prepared_context)-ceq$ptr.prepared_context_sha256) 'Historical preparation changed'
$powerSha='6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1';$last=-1;$count=0
foreach($line in [IO.File]::ReadLines((Join-Path $art 'power-samples.jsonl'))){$value=$line|ConvertFrom-Json -AsHashtable;Need ($value.state.active_guid-ceq'381b4222-f694-41f0-9685-ff5bb260df2e'-and$value.state.settings_sha256-ceq$powerSha-and$value.state.setting_count-eq183) 'Power sample differs';Need ($value.elapsed_seconds-ge$last-and($last-lt0-or$value.elapsed_seconds-$last-le45)) 'Power gap';$last=$value.elapsed_seconds;$count++}
Need ($count-eq$r.power_monitor.sample_count-and$count-ge2-and$last-ge$r.power_monitor.scope_empty_elapsed_seconds+30) 'Power post-observation incomplete'
$support=[ordered]@{};$summary=[ordered]@{}
foreach($arm in @('direct','bridge')){
 $a=$p.arms[$arm];$e=ReadAuditMap (Join-Path $art ('external-viewer-'+$arm+'.json'));$w=ReadAuditMap (Join-Path $art ('terminal-renderer-'+$arm+'.json'));$launch=ReadAuditMap (Join-Path $art ('windows-renderer-launch-'+$arm+'.json'))
 Need ($a.status-ceq'captured'-and$a.query_emissions-eq1-and$a.elapsed_seconds-ge3-and$a.elapsed_seconds-le3.2-and$a.actual_Windows_renderer_confirmed-eq$true-and$a.actual_writable_client_count-eq1-and$a.synthetic_and_bridge_actual_exit_verified-eq$true-and$a.raw_input_exported-eq$false-and$a.no_keyboard_input_sent-eq$true) 'Arm capture not completed safely'
 Need ($w.run_id-ceq$c.run_id-and$e.run_id-ceq$c.run_id-and$w.arm-ceq$arm-and$e.arm-ceq$arm-and$w.nonce-ceq$e.nonce-and$launch.nonce-ceq$w.nonce-and$w.actual_windows_terminal-is[bool]-and$w.actual_windows_terminal-eq$true-and$e.pidfd_admitted-eq$true-and$w.viewer_pid-eq$e.viewer_pid-and$w.viewer_birth-ceq$e.viewer_birth) 'Renderer admission differs'
 Need ($w.observation_kind-ceq'installed_WindowsTerminal_process_window_and_pidfd_admission_metadata'-and$w.screenshot_observed-eq$false-and$w.keyboard_input_sent-eq$false-and$w.windows_pid-gt0-and$w.windows_window_handle-ne0-and$w.windows_birth_filetime_utc-gt0-and$w.model_requests-eq0-and$w.account_operations-eq0) 'Windows renderer metadata incomplete'
 foreach($name in @(('external-viewer-'+$arm+'.json'),('terminal-renderer-'+$arm+'.json'),('windows-renderer-launch-'+$arm+'.json'))){$support[$name]=AuditHash (Join-Path $art $name)}
 $summary[$arm]=@{capture_seconds=$a.elapsed_seconds;query_bursts=1;query_types=5;total_input_bytes=$a.total_input_bytes;control_classes=$a.control_classes;control_events=$a.control_events;incomplete_tail_class=$a.incomplete_tail_class;incomplete_tail_bytes=$a.incomplete_tail_byte_count;printable_byte_count=$a.printable_input_byte_count;input_framing_finding=$a.input_framing_finding;actual_child_resize_observed=$a.actual_child_resize_observed;dimensions=$a.dimensions}
}
Need ($p.arms.bridge.bridge.exit_code-eq0-and$p.arms.bridge.bridge.actual_NativeRuntime_Channel-eq$true-and$p.arms.bridge.bridge.actual_RawTerminalBridge-eq$true-and$p.arms.bridge.bridge.raw_frames_exported-eq$false) 'Real bridge comparison missing'
$summary.bridge.bridge_counts=$p.arms.bridge.bridge.counts
$observer=Join-Path $PSScriptRoot 'observe-terminal-probe-renderers080-20261109.ps1';$observerPeer=Join-Path $PSScriptRoot 'terminal-renderer-observer-independent-peer-5318-20261109.json'
Need ((AuditHash $observer)-ceq'5318e4d2e0af7b370966be272877701cb8941db2d5905b420565f9307092772f'-and(AuditHash $observerPeer)-ceq'7bb53831119e054b4f3ba2c7788b213739ac80a55db2936848c871ac8dc5529c') 'External renderer observer changed'
$reportPath=Join-Path $PSScriptRoot '080-terminal-input-probe-completed-final-20261109.json';Need (-not(Test-Path -LiteralPath $reportPath)) 'Final review exists'
$report=@{schema_version=1;scope='devbrain_no_model_terminal_probe_closing_audit';status='diagnostic_comparison_completed';run_id=$c.run_id;actual_windows_exec_session=76368;actual_windows_exit_code=0;actual_root_renderer_observer_session=26835;root_reported_renderer_observer_exit_code=0;active_context=$ctx;active_context_sha256=(AuditHash $ctx);prepared_context_sha256=$ptr.prepared_context_sha256;receipt_sha256=(AuditHash (Join-Path $art 'receipt.json'));controller_sha256=(AuditHash (Join-Path $art 'controller-report.json'));supervisor_sha256=(AuditHash (Join-Path $art 'supervisor-report.json'));support_artifact_sha256=$support;Windows_renderer_observer_sha256=(AuditHash $observer);Windows_renderer_observer_peer_sha256=(AuditHash $observerPeer);arms=$summary;scope_empty_post_seconds=$r.scope_cleanup_grace_seconds;external_post_exit_seconds=$r.cleanup_grace_seconds;controller_cleanup_seconds=$p.cleanup_grace_seconds;source_files_unchanged=$source.files.Count;frozen_inputs_unchanged=$f.files.Count;source_freeze_sha256=$c.source_freeze_sha256;cleanup_complete=$true;native_failure=$false;boot_changed=$false;power_changed=$false;sleep_restored=$true;comparison_kind='one_five_query_burst_then_three_seconds_capture_per_arm';resize_finding_interpretation='Both inner windows were explicitly pinned manual120x40 by this probe; direct resize targets inner, bridge resize targets outer and sends clientsize. Missing bridge child resize is instrumentation, not evidence of a product resize fault.';actual_Codex_or_Crossterm_tested=$false;actual_HTTP_tested=$false;actual_broker_transport='in_process_protocol_test_double';causal_conclusion='not_established';terminal_input_stability_qualified=$false;application_qualified=$false;release_qualified=$false;model_requests=0;account_operations=0;database_started=$false;production_modified=$false;eight_hour_started=$false}
[IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$ptr.status='diagnostic_comparison_completed';$ptr.active_context_sha256=AuditHash $ctx;$ptr.actual_windows_exit_code=0;$ptr.closing_report=$reportPath;$ptr.closing_report_sha256=AuditHash $reportPath
[IO.File]::WriteAllText($ptrPath,($ptr|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
@{report=$reportPath;sha256=(AuditHash $reportPath);actual_session=76368;actual_exit=0;cleanup_complete=$true;scope_post_seconds=$r.scope_cleanup_grace_seconds;external_post_seconds=$r.cleanup_grace_seconds;application_qualified=$false}|ConvertTo-Json
