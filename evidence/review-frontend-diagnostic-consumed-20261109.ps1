# Historical Windows-only closing review already executed. No Linux/model commands.
# Current contexts are now finalized; original fresh-state guard prevents replay.
$ErrorActionPreference='Stop'
function Need([bool]$ok,[string]$why){if(-not$ok){throw $why}}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Read([string]$p){Get-Content -Raw -LiteralPath $p|ConvertFrom-Json -AsHashtable}
function MatchMap($a,$b,[string]$why){Need ($a.Count-eq$b.Count) $why;foreach($k in $b.Keys){Need ($a.Contains($k)-and$a[$k]-ceq$b[$k]) $why}}
$cp='evidence/080-frontend-diagnostic-active-context-20261109T100750Z.json';$c=Read $cp
Need ($c.status-ceq'diagnostic_finished_pending_evidence_review'-and$c.actual_windows_exit_code-eq0-and$c.run_id-ceq'frontend-diag080-20261109T100750Z-e7bd65b8') 'Actual exit missing'
$a=$c.artifact_root;$r=Read (Join-Path $a receipt.json);$s=Read (Join-Path $a supervisor-report.json);$d=Read (Join-Path $a controller-report.json);$x=Read (Join-Path $a regressions-results.json)
Need ($r.passed-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.windows_proxy_returncode-eq0-and$r.sleep_inhibition.restored-eq$true) 'Raw cleanup missing'
Need ($r.run_id-ceq$c.run_id-and$s.run_id-ceq$c.run_id-and$d.run_id-ceq$c.run_id-and$x.run_id-ceq$c.run_id) 'Run identity differs'
foreach($key in @('errors','new_kernel_fatals','new_wsl_dumps')){Need ($r.Contains($key)-and@($r[$key]).Count-eq0) 'New fault or missing proof'}
Need ($r.initial_boot_id-ceq$r.final_boot_id-and$r.power_monitor.changed-eq$false-and$r.power_profile_start.settings_sha256-ceq'6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'-and$r.power_profile_end.settings_sha256-ceq$r.power_profile_start.settings_sha256) 'Boot or power changed'
Need ($s.passed-eq$true-and$s.cleanup_complete-eq$true-and$s.child_returncode-eq0-and$s.controller_exit_verified-eq$true-and$s.forced_cleanup-eq$false-and$s.native_failure-eq$false-and$s.scope_descendants_stopped-eq$true-and$s.scope_unit-ceq$r.scope_unit-and$s.scope_cgroup_identity-ceq$r.scope_cgroup_identity-and$s.cleanup_grace_seconds-ge30) 'Supervisor mismatch'
foreach($key in @('errors','new_kernel_fatals','new_wsl_dumps','remaining_scope_processes','remaining_tagged_processes')){Need ($s.Contains($key)-and@($s[$key]).Count-eq0) 'Supervisor leftover or fault'}
Need ($d.status-ceq'regressions_completed_pending_external_watch'-and$d.scope-ceq'devbrain_targeted_regressions'-and$d.phase-ceq'frontend'-and$d.cleanup_complete-eq$true-and$d.cleanup_grace_seconds-ge30-and$d.workload_criteria_passed-eq$true-and$d.forced_cleanup-eq$false-and@($d.errors).Count-eq0-and$x.status-ceq'passed') 'Controller failed'
$all=@{};foreach($key in $r.artifact_sha256.Keys){Need ((Sha (Join-Path $a $key))-ceq$r.artifact_sha256[$key]) 'Raw artifact hash changed';$all[$key]=$r.artifact_sha256[$key]}
Need ($s.controller_report_sha256-ceq$r.artifact_sha256['controller-report.json']) 'Supervisor controller binding differs'
$f=Read $c.input_freeze;foreach($rel in $f.files.Keys){Need ((Sha (Join-Path $c.windows_root $rel))-ceq$f.files[$rel]) 'Frozen input changed'}
foreach($n in $c.helper_sha256.Keys){Need ((Sha (Join-Path $c.windows_tools $n))-ceq$c.helper_sha256[$n]) 'Frozen helper changed'}
MatchMap $r.helper_sha256_start $r.helper_sha256_end 'Observed helpers changed';foreach($n in $r.helper_sha256_start.Keys){Need ($c.helper_sha256.Contains($n)-and$c.helper_sha256[$n]-ceq$r.helper_sha256_start[$n]) 'Observed helper generation differs'}
$af=Read $c.app_freeze;$expect=@{};$expectFrontend=@{};$static=@{}
$appPrefix='devbrain/';$frontPrefix='devbrain/frontend/';$staticPrefix='devbrain/src/devbrain/web_static/'
foreach($k in $af.files.Keys){if($k.StartsWith('devbrain/src/')-or$k.StartsWith('devbrain/tests/')-or$k.StartsWith('devbrain/data/')-or$k-ceq'devbrain/pyproject.toml'-or$k-ceq'devbrain/uv.lock'){$expect[$k.Substring($appPrefix.Length)]=$af.files[$k]};if($k.StartsWith($frontPrefix)){$expectFrontend[$k.Substring($frontPrefix.Length)]=$af.files[$k]};if($k.StartsWith($staticPrefix)){$static[$k.Substring($staticPrefix.Length)]=$af.files[$k]}}
MatchMap $d.source_hashes $expect 'Controller source differs';MatchMap $x.source_hashes $expectFrontend 'Frontend source differs'
$counts=@{}
foreach($pair in @(@('unit',10),@('browser',8))){
 $name=$pair[0];$count=$pair[1];$j=[xml](Get-Content -Raw -LiteralPath (Join-Path $a ('frontend-'+$name+'.xml')))
 $cases=@($j.SelectNodes('//testcase'));Need ($cases.Count-eq$count-and@($j.SelectNodes('//failure|//error|//skipped')).Count-eq0) 'JUnit failure or incomplete'
 $ids=@($cases|ForEach-Object{$_.GetAttribute('classname')+'::'+$_.GetAttribute('name')});Need (@($ids|Sort-Object -Unique).Count-eq$count) 'JUnit duplicate cases'
 Need ($x[$name].passed-eq$count-and$x[$name].failures-eq0-and$x[$name].errors-eq0-and$x[$name].skipped-eq0) 'JUnit/result count differs';$counts[$name]=$x[$name]
}
foreach($key in @('install','unit','build','browser','audit_all','audit_runtime')){Need ($x.steps[$key].returncode-eq0-and$x.steps[$key].actual_exit_verified-eq$true) 'Step exit failed'}
Need ($x.steps.server_shutdown.actual_exit_verified-eq$true-and$x.steps.server_shutdown.returncode-in@(0,143,-15)) 'Server exit missing'
foreach($suffix in @('all','runtime')){$audit=Read (Join-Path $a ('frontend-audit-'+$suffix+'.json'));Need ($audit.Contains('metadata')-and$audit.metadata.Contains('vulnerabilities')-and$audit.metadata.vulnerabilities.Contains('total')-and$audit.metadata.vulnerabilities.total-eq0) 'Audit nonzero'}
$built=Read (Join-Path $a frontend-build-manifest.json);Need ($built.Count-gt0-and$static.Count-ge$built.Count) 'Build/static inventory missing'
foreach($rel in $built.Keys){Need ($static.Contains($rel)-and$built[$rel]-ceq$static[$rel]) ('Built bytes differ: '+$rel)}
$report=@{schema_version=1;scope='devbrain_independent_frontend_diagnostic_review';status='diagnostic_passed_not_release_qualified';run_id=$c.run_id;actual_windows_exec_session=68778;actual_windows_exit_code=0;cleanup_complete=$true;safe_next_owned_scope_only=$true;error_inventory_only=$true;formal_release_gate=$false;release_qualified=$false;application_qualified=$false;current_ui_passed=$false;source_freeze_sha256=$c.source_freeze_sha256;source_files=$expect.Count;frontend_source_files=$expectFrontend.Count;helper_count=38;raw_artifact_sha256=$all;receipt=(Join-Path $a receipt.json);receipt_sha256=(Sha (Join-Path $a receipt.json));controller_sha256=$r.artifact_sha256['controller-report.json'];supervisor_sha256=$r.artifact_sha256['supervisor-report.json'];scope_unit=$r.scope_unit;scope_identity=$r.scope_cgroup_identity;scope_quiet_seconds=$r.scope_cleanup_grace_seconds;outer_quiet_seconds=$r.cleanup_grace_seconds;controller_quiet_seconds=$d.cleanup_grace_seconds;native_failure=$false;power_changed=$false;boot_id=$r.final_boot_id;sleep_restored=$true;unit=$counts.unit;browser=$counts.browser;steps=$x.steps;current_build_files=$built.Count;packaged_static_files=$static.Count;all_current_built_bytes_match_candidate=$true;retained_older_unused_static_files=($static.Count-$built.Count);audit_review_history=@{first_windows_audit_exit=1;first_failed_before_publication=$true;cause='Audit-only source namespace prefix length32vs33; product/raw frontend result unaffected';corrected_to='literalPrefix.Length';all_raw_proofs_reverified=$true};created_utc=[DateTime]::UtcNow.ToString('o')}
$reportPath='evidence/080-frontend-diagnostic-final-20261109.json';$bytes=[Text.UTF8Encoding]::new($false).GetBytes(($report|ConvertTo-Json -Depth 12))
$stream=[IO.File]::Open((Join-Path (Get-Location) $reportPath),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
$c.status='diagnostic_passed_not_release_qualified';$c.actual_windows_exec_session=68778;$c.cleanup_complete=$true;$c.receipt=(Join-Path $a receipt.json);$c.receipt_sha256=$report.receipt_sha256;$c.final_report=(Join-Path (Get-Location) $reportPath);$c.final_report_sha256=Sha $reportPath
[IO.File]::WriteAllText((Join-Path (Get-Location) $cp),($c|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
[pscustomobject]@{status=$c.status;context_sha256=(Sha $cp);report=$reportPath;report_sha256=$c.final_report_sha256;receipt_sha256=$c.receipt_sha256;unit=$counts.unit;browser=$counts.browser;scope_quiet=$r.scope_cleanup_grace_seconds;outer_quiet=$r.cleanup_grace_seconds;current_build_files=$built.Count;packaged_static_files=$static.Count;safe_next=$true}|ConvertTo-Json -Depth 5

