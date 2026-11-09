# Windows-only failed-formal-UI closure audit. Never launches WSL, models or UI.
$ErrorActionPreference='Stop'
function Need([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read([string]$p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -AsHashtable}
function EqualMap($a,$b,[string]$why){Need ($a.Count-eq$b.Count) $why;foreach($k in $b.Keys){Need ($a.Contains($k)-and$a[$k]-ceq$b[$k]) $why}}
function SafeChild([string]$root,[string]$relative){
 Need (-not[IO.Path]::IsPathRooted($relative)) 'Absolute child rejected'
 $root=[IO.Path]::GetFullPath($root).TrimEnd([IO.Path]::DirectorySeparatorChar)
 $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
 Need ($path.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) 'Escaping child rejected'
 $cursor=Get-Item -LiteralPath $path -Force
 while($null-ne$cursor){Need (($cursor.Attributes-band[IO.FileAttributes]::ReparsePoint)-eq0) 'Reparse path rejected';if($cursor.FullName.Equals($root,[StringComparison]::OrdinalIgnoreCase)){break};$cursor=if($cursor-is[IO.DirectoryInfo]){$cursor.Parent}else{$cursor.Directory}}
 Need ($null-ne$cursor) ('Parent chain missing: '+$root+' -> '+$path)
 return $path
}
$cp='evidence/080-interactive-sidebar-resize-agent-active-context-20261108.json'
$c=Read $cp
Need ($c.run_id-ceq'interactive-sidebar-resize080-20261109T104544Z-14a140ad') 'Wrong run'
$a=$c.artifact_root
$r=Read (Join-Path $a receipt.json);$s=Read (Join-Path $a supervisor-report.json)
$d=Read (Join-Path $a controller-report.json);$e=Read (Join-Path $a supervisor-exit.json)
$x=Read (Join-Path $a interactive-results.json)
foreach($v in @($r,$s,$d,$e,$x)){Need ($v.run_id-ceq$c.run_id) 'Run identity mismatch'}
Need ($r.passed-eq$false-and$r.cleanup_complete-eq$false-and$r.forced_cleanup-eq$true-and$r.controller_exit_verified-eq$false) 'Historical raw fail flags changed'
Need ($r.windows_proxy_returncode-eq1-and$r.supervisor_returncode-eq1-and$r.supervisor_exit_verified-eq$true) 'Failed actual supervisor exit missing'
Need ($e.actual_exit_verified-eq$true-and$e.windows_proxy_returncode-eq1-and$e.stdio_complete-eq$true-and$e.qualification_passed-eq$false) 'Proxy exit/stdio missing'
$proxy=Get-Process -Id $e.windows_proxy_identity.pid -ErrorAction SilentlyContinue
if($null-ne$proxy){Need ($proxy.StartTime.ToUniversalTime()-ne[DateTime]::Parse($e.windows_proxy_identity.started_utc).ToUniversalTime()) 'Original Windows proxy still alive'}
Need ($r.scope_unit-ceq'devbrain-q-1101b183a63e4f2a81d7972925d37f51.scope'-and$r.scope_cgroup_identity-ceq'25:2961') 'Owned scope identity mismatch'
Need ($r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30) 'Scope quiet observation missing'
Need ($s.passed-eq$false-and$s.child_returncode-eq1-and$s.controller_exit_verified-eq$true-and$s.cleanup_complete-eq$true-and$s.forced_cleanup-eq$false-and$s.scope_descendants_stopped-eq$true-and$s.scope_membership_verified-eq$true) 'Actual child exit/cleanup missing'
Need ($s.scope_unit-ceq$r.scope_unit-and$s.scope_cgroup_identity-ceq$r.scope_cgroup_identity-and$s.control_group-ceq$r.control_group-and$s.cleanup_grace_seconds-ge30) 'Supervisor scope binding mismatch'
foreach($k in @('remaining_scope_processes','remaining_tagged_processes','new_wsl_dumps','new_kernel_fatals')){Need ($s.Contains($k)-and@($s[$k]).Count-eq0) 'Supervisor leftover/fault'}
foreach($k in @('new_wsl_dumps','new_kernel_fatals')){Need ($r.Contains($k)-and@($r[$k]).Count-eq0) 'Windows new fault'}
Need ($s.native_failure-eq$false-and$r.native_failure-eq$false) 'New native platform fault'
$expectedSupervisorErrors=@('RuntimeError: Controller returned a nonzero exit code','Final verification: Unsupported or incomplete controller status')
Need (@($s.errors).Count-eq2) 'Unexpected supervisor error inventory'
for($i=0;$i-lt2;$i++){Need ($s.errors[$i]-ceq$expectedSupervisorErrors[$i]) 'Unexpected supervisor error'}
Need ($d.status-ceq'failed'-and$d.cleanup_complete-eq$true-and$d.forced_cleanup-eq$false-and$d.external_viewers_actual_exit_verified-eq$true-and$d.cleanup_grace_seconds-ge30-and@($d.errors).Count-eq0) 'Controller owned cleanup missing'
Need ($d.engine.started-eq$true-and$d.engine.actual_exit_verified-eq$true-and$d.engine.cleanup_complete-eq$true-and$d.engine.graceful_shutdown_requested-eq$true-and$d.engine.forced_cleanup-eq$false-and$d.engine.returncode-eq143-and$d.engine.unexpected_exit_before_shutdown-eq$false) 'JVM shutdown missing'
foreach($k in @('oauth_phase_sync','oauth_cache_sync','oauth_cache_release')){Need ($d[$k].passed-eq$true-and@($d[$k].error_codes).Count-eq0) 'OAuth sync/release missing'}
Need ($d.oauth_phase_sync.conflict-eq$false-and$d.oauth_cache_sync.conflict-eq$false-and$d.native_binaries_unchanged-eq$true-and$d.worker_started-eq$false) 'Auth/native state mismatch'
Need ($r.initial_boot_id-ceq'370fca73-9ca1-474d-aab5-024ec5872e12'-and$r.final_boot_id-ceq$r.initial_boot_id-and$s.initial_boot_id-ceq$r.initial_boot_id-and$s.final_boot_id-ceq$r.initial_boot_id) 'Boot changed'
Need ($r.sleep_inhibition.acquired-eq$true-and$r.sleep_inhibition.restored-eq$true-and$r.power_monitor.changed-eq$false) 'Sleep/power not restored'
Need ($r.power_profile_start.active_guid-ceq'381b4222-f694-41f0-9685-ff5bb260df2e'-and$r.power_profile_start.settings_sha256-ceq'6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'-and$r.power_profile_start.setting_count-eq183) 'Balanced baseline differs'
EqualMap $r.power_profile_start $r.power_profile_end 'Power profile changed'
$points=@(Get-Content -LiteralPath (Join-Path $a power-samples.jsonl)|ForEach-Object {$_|ConvertFrom-Json -AsHashtable})
Need ($points.Count-eq37-and$points.Count-eq$r.power_monitor.sample_count) 'Power sample count differs'
$prev=-1.0;$maxGap=0.0
foreach($p in $points){Need ($p.elapsed_seconds-ge$prev) 'Power samples unordered';if($prev-ge0){$maxGap=[Math]::Max($maxGap,$p.elapsed_seconds-$prev)};EqualMap $p.state $r.power_profile_start 'Sample power differs';$prev=$p.elapsed_seconds}
Need ($maxGap-le45-and$points[-1].elapsed_seconds-ge($r.power_monitor.scope_empty_elapsed_seconds+30)) 'Post-cleanup power observation incomplete'
$probe=Get-Content -LiteralPath (Join-Path $a probe-scope.stdout.log) -Raw
Need ($probe.StartsWith("LOAD=not-found"+[char]10+"GROUP="+[char]10+"POPULATED=0"+[char]10+"IDENTITY="+[char]10)) 'Final scope probe not absent/empty'
$probeBoot=(Get-Content -LiteralPath (Join-Path $a probe-boot.stdout.log) -Raw).Trim()
Need ($probeBoot-ceq$r.final_boot_id) 'Final boot probe differs'
foreach($n in @('probe-scope.stderr.log','probe-boot.stderr.log','probe-kernel.stderr.log','scope-stop.stderr.log')){Need ((Get-Item -LiteralPath (Join-Path $a $n)).Length-eq0) 'Probe/cleanup stderr not empty'}
Need ((Sha $c.input_freeze)-ceq'30edc5154a3872f69f48b8fe298bb5727aab2264351376db903870eaa726670d') 'Input freeze changed'
$f=Read $c.input_freeze;Need ($f.files.Count-eq20) 'Wrong input count'
foreach($k in $f.files.Keys){Need ((Sha (SafeChild $c.windows_root $k))-ceq$f.files[$k]) 'Frozen input changed'}
Need ($c.helper_sha256.Count-eq38) 'Wrong helper count'
foreach($k in $c.helper_sha256.Keys){Need ((Sha (SafeChild $c.windows_tools $k))-ceq$c.helper_sha256[$k]) 'Frozen helper changed'}
EqualMap $r.helper_sha256_start $r.helper_sha256_end 'Observed helper hashes changed'
EqualMap $s.helper_sha256_start $s.helper_sha256_end 'Supervisor helper hashes changed'
foreach($k in $s.helper_sha256_start.Keys){Need ($c.helper_sha256[$k]-ceq$s.helper_sha256_start[$k]) 'Wrong helper generation'}
EqualMap $r.input_sha256_start $r.input_sha256_end 'Observed inputs changed'
Need ($null-eq$r.controller_sha256_start-and$null-eq$r.controller_sha256_end) 'Raw failed-receipt null controller hash state changed'
Need ($s.controller_sha256-ceq$c.controller_sha256-and$s.controller_sha256_end-ceq$c.controller_sha256) 'Actual supervisor controller hash differs'
Need ((Sha $c.source_freeze)-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703') 'App freeze changed'
$af=Read $c.source_freeze;$bundle=Join-Path (Split-Path $c.source_freeze) bundle
Need ($af.files.Count-eq209-and$af.app_files-eq198) 'App bundle count differs'
foreach($k in $af.files.Keys){Need ((Sha (SafeChild $bundle $k))-ceq$af.files[$k]) 'Frozen app bundle changed'}
$expected=@{};$appPrefix='devbrain/'
foreach($k in $af.files.Keys){if($k.StartsWith('devbrain/src/')-or$k.StartsWith('devbrain/tests/')-or$k.StartsWith('devbrain/data/')-or$k-ceq'devbrain/pyproject.toml'-or$k-ceq'devbrain/uv.lock'){$expected[$k.Substring($appPrefix.Length)]=$af.files[$k]}}
Need ($expected.Count-eq153) 'Wrong controller source count';EqualMap $d.source_hashes $expected 'Controller source differs'
Need ($x.operator-ceq'agent'-and$x.human_reported-eq$false-and$x.agent_acceptance_passed-eq$false-and$x.observations.Count-eq5) 'UI result identity differs'
foreach($pair in @(@('start','failed'),@('switch','blocked'),@('source','passed'),@('connection','passed'),@('reconnect','blocked'))){Need ($x.observations['task:'+$pair[0]].status-ceq$pair[1]) 'UI task verdict differs'}
$all=@{}
foreach($n in $r.artifact_sha256.Keys){$actual=Sha (SafeChild $a $n);Need ($actual-ceq$r.artifact_sha256[$n]) 'Raw receipt artifact changed';$all[$n]=$actual}
foreach($p in Get-ChildItem -LiteralPath $a -File){$all[$p.Name]=Sha $p.FullName}
Need ((Sha 'evidence/080-real-wt-formal-ui-operator-inventory-20261109.json')-ceq'ce30791f40438e3265f440307fb2562e5e73afe8c6b0e86f6424c9046c6d8a6d') 'Operator inventory changed'
$report=@{
 schema_version=1;scope='failed_formal_real_WT_UI_owned_cleanup_admission';status='failed_UI_safe_next_owned_workload_only';created_utc=[DateTime]::UtcNow.ToString('o')
 run_id=$c.run_id;actual_windows_exec_session=98979;actual_windows_exit_code=1;root_actual_windows_exit_observed_utc='2026-11-09T11:23:58Z'
 qualification_passed=$false;overall_UI_passed=$false;application_qualified=$false;release_qualified=$false;source_final=$false;eight_hour_started=$false;production_modified=$false
 raw_receipt_passed=$r.passed;raw_receipt_cleanup_complete=$r.cleanup_complete;raw_receipt_forced_cleanup=$r.forced_cleanup;raw_receipt_controller_exit_verified=$r.controller_exit_verified
 raw_supervisor_passed=$s.passed;raw_supervisor_cleanup_complete=$s.cleanup_complete;raw_failure_flags_preserved=$true
 controller_actual_exit_verified=$s.controller_exit_verified;controller_actual_exit_code=$s.child_returncode;actual_windows_proxy_exit_verified=$e.actual_exit_verified;actual_proxy_exit_code=$e.windows_proxy_returncode;stdio_complete=$e.stdio_complete
 safe_next_owned_workload_only=$true;safe_next_account_test_after_closed_UI_leases=$true;cleanup_claim_limited_to_owned_scope=$true;global_process_absence_claim=$false
 scope_unit=$r.scope_unit;scope_cgroup_identity=$r.scope_cgroup_identity;scope_empty_verified=$r.scope_empty_verified;scope_quiet_seconds=$r.scope_cleanup_grace_seconds;outer_post_exit_seconds=$r.cleanup_grace_seconds;final_scope_load='not-found';final_scope_populated=0
 remaining_tagged_process_count=0;remaining_scope_process_count=0;outside_owned_scope_unobservable_processes=$s.unobservable_external_processes;outside_owned_scope_processes_not_owned_or_killed=$true
 owned_external_viewers_actual_pidfd_exit_verified=$d.external_viewers_actual_exit_verified;owned_JVM_actual_exit_verified=$d.engine.actual_exit_verified;owned_JVM_graceful_shutdown_requested=$d.engine.graceful_shutdown_requested;owned_JVM_exit_code=$d.engine.returncode
 OAuth_phase_sync_passed=$d.oauth_phase_sync.passed;OAuth_final_cache_sync_passed=$d.oauth_cache_sync.passed;OAuth_source_lease_release_passed=$d.oauth_cache_release.passed;owned_account_leases_released=$true
 native_boot_dump_kernel_power_sleep_clean=$true;power_sample_count=$points.Count;maximum_observed_power_gap_seconds=$maxGap;initial_boot_id=$r.initial_boot_id;final_boot_id=$r.final_boot_id
 source_snapshot=$c.source_snapshot;source_freeze_sha256=$c.source_freeze_sha256;actual_controller_source_hashes_verified=$expected.Count;app_bundle_files_rehashed=$af.files.Count;app_files_rehashed=$af.app_files;frozen_inputs_rehashed=$f.files.Count;helpers_rehashed=$c.helper_sha256.Count;native_binary_hashes_unchanged=$d.native_binaries_unchanged
 operator='agent';human_reported=$false;official_observation_count=5;tasks=@{start='failed';switch='blocked';source='passed';connection='passed';reconnect='blocked'}
 operator_report=(Join-Path (Get-Location) 'evidence/080-real-wt-formal-ui-operator-inventory-20261109.json');operator_report_sha256='ce30791f40438e3265f440307fb2562e5e73afe8c6b0e86f6424c9046c6d8a6d'
 receipt=(Join-Path $a receipt.json);receipt_sha256=(Sha (Join-Path $a receipt.json));raw_artifact_sha256=$all
 newLinuxprobe_started_by_reviewer=$false;newmodels_or_account_queries_by_reviewer=$false;private_source_credentials_account_values_or_raw_terminal_exported=$false
}
$outPath=Join-Path (Get-Location) 'evidence/080-real-wt-formal-ui-failed-safe-next-20261109.json'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($report|ConvertTo-Json -Depth 15))
$stream=[IO.File]::Open($outPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
[pscustomobject]@{status=$report.status;report=$outPath;report_sha256=(Sha $outPath);receipt_sha256=$report.receipt_sha256;safe_next=$true;scope_quiet=$report.scope_quiet_seconds;outer_quiet=$report.outer_post_exit_seconds;power_samples=$points.Count;max_gap=$maxGap;input_count=$f.files.Count;helpers=$c.helper_sha256.Count;app_bundle=$af.files.Count;controller_source=$expected.Count}|ConvertTo-Json -Depth 4

