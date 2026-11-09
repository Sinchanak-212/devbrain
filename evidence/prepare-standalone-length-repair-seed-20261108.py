"""Generate Windows-only staging metadata; does not execute the generated observer."""
import hashlib
from pathlib import Path

e = Path(__file__).resolve().parent
p = e / 'stage-ux-task-state-604-20261108.ps1'
assert hashlib.sha256(p.read_bytes()).hexdigest() == '19c84062b65a881ab049f8d47d6cfbf2ef8a582e78e961a21fd9df1a3ddec13e'
prefix = p.read_text(encoding='utf-8-sig').split('$masterPath=', 1)[0]
prefix = prefix.replace('UX377 execution metadata', 'standalone1557 attestation metadata')
body = r'''
$oldPath=Join-Path $workspace 'evidence/080-standalone-task-state-attestation-prepared-context-20261108.json'
Verify $oldPath '664a00e98b3fb34a5b4c122e68cd3e6c8323a52df50696624ef165295c1b74bb';$old=ReadMap $oldPath
Verify $old.launcher 'a3b40d6521253b2548f3e03a6e7c6e74bfdd3ffefb72b8e163dd569e206c238b'
Verify $old.materializer 'af293087698237364fa68ce2034ebf6ba14c101b20eb0455060ebd7cbf690d61'
Verify $old.seed_freeze $old.seed_freeze_sha256;$oldSeed=ReadMap $old.seed_freeze;Artifacts $oldSeed.files $old.windows_root
$backendPath=Join-Path $workspace 'evidence/080-fullbackend-length-repair-active-context-20261108.json'
Verify $backendPath 'ab7a9c3073c9d9bf79a8a4f8bb14795b1ed9ef4a529df1da3a207ae34b43b831';$b=ReadMap $backendPath
Require ($b.status-ceq'prepared_not_run'-and$b.expected_test_count-eq1557-and$null-eq$b.actual_windows_exit_code-and$b.source_final-eq$false) 'Backend must remain unrun preparation'
Verify $b.input_freeze $b.input_freeze_sha256;$bf=ReadMap $b.input_freeze;Artifacts $bf.files $b.windows_root
Verify $b.guard_context '0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d';$g=ReadMap $b.guard_context
Verify $g.receipt 'c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82'
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.helper_file_count-eq38) 'Current604 incomplete'
SameMap $g.helper_sha256 $old.helper_sha256;SameMap $g.helper_sha256 $b.helper_sha256;Artifacts $g.helper_sha256 $g.windows_tools
Verify $b.app_freeze '1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14'
Verify $b.app_prepare_receipt '4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e'
$contextPath=Join-Path $workspace 'evidence/080-standalone-length-repair-attestation-prepared-context-20261108.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Never overwrite historical prepared context'
$run='suite-attest-length-envelope-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh envelope required';NoReparse $root
foreach($sub in @('inputs','artifacts')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
function NewText([string]$Path,[string]$Text){NoReparse $Path;$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text);$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()};PathProof $Path}
$plan=ReadMap $old.plan
$plan.run_id=$run;$plan.backend_run_id=$b.run_id;$plan.backend_context=$backendPath;$plan.backend_root=$b.artifact_root;$plan.backend_linux_root=$b.linux_artifact_root
$plan.backend_root_actual_exec_session=$null;$plan.source_root=$b.source_root;$plan.source_freeze=$b.app_freeze;$plan.source_freeze_sha256=$b.app_freeze_sha256;$plan.python_launcher=$b.python_launcher;$plan.tools=$g.windows_tools
$plan.helper_sha256=$g.helper_sha256;$plan.expected_cases=1557;$plan.canonical_output=Join-Path $b.artifact_root 'final-full-suite.json';$plan.canonical_linux_output=$b.linux_artifact_root+'/final-full-suite.json'
$plan.attestor_argv=@($b.python_launcher,'-I','-B',($g.linux_tools+'/attest-full-suite-080.py'),'--artifact-root',$b.linux_artifact_root,'--source-root',$b.source_root,'--mode','full-suite','--output',$plan.canonical_linux_output)
$plan.bounded_linux_argv=@('/usr/bin/timeout','--signal=TERM','--kill-after=5s','120s')+$plan.attestor_argv
Require ($plan.attestor_argv.Count-eq12-and$plan.bounded_linux_argv.Count-eq16-and-not(Test-Path -LiteralPath $plan.canonical_output)) 'Canonical argv/output differs'
$launcher=[IO.File]::ReadAllText($old.launcher).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1537','1557')
$launcher=$launcher.Replace('$freeze.backend_root_exec_session -ne 64756','($freeze.backend_root_exec_session -isnot [long] -and $freeze.backend_root_exec_session -isnot [int]) -or $freeze.backend_root_exec_session -le 0')
$launcher=$launcher.Replace('$context.actual_windows_exec_session -ne 64756','$context.actual_windows_exec_session -ne $freeze.backend_root_exec_session')
$materializer=[IO.File]::ReadAllText($old.materializer).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools)
$materializer=$materializer.Replace('[string]$BackendReceiptSha256)','[string]$BackendReceiptSha256,[long]$BackendActualExecSession)')
$materializer=$materializer.Replace('$context.actual_windows_exec_session -eq 64756','$BackendActualExecSession -gt 0 -and $context.actual_windows_exec_session -eq $BackendActualExecSession')
$materializer=$materializer.Replace('backend_root_exec_session=64756','backend_root_exec_session=$BackendActualExecSession')
Require ($launcher-notmatch'64756|1537|guards-task-state080|suite-attest-taskstate' -and $materializer-notmatch'64756|guards-task-state080|suite-attest-taskstate') 'Stale launch identity remains'
$launcherPath=Join-Path $root 'run-full-suite-attestation.ps1';$materializerPath=Join-Path $root 'prepare-full-suite-attestation.ps1'
NewText $launcherPath $launcher;NewText $materializerPath $materializer
foreach($p in @($launcherPath,$materializerPath)){$t=$null;$err=$null;$null=[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$err);Require ($err.Count-eq0) 'Generated observer parse failure'}
$planPath=Join-Path $root 'launch-plan.json';NewJson $planPath $plan
$files=[ordered]@{'launch-plan.json'=(HashFile $planPath);'run-full-suite-attestation.ps1'=(HashFile $launcherPath);'prepare-full-suite-attestation.ps1'=(HashFile $materializerPath)}
foreach($rel in @('attestor-ast-proof.json','inputs/approved-mechanical-observer.ps1','inputs/controlled-fixtures-final.json','inputs/gate.json')){CopyExact (Join-Path $old.windows_root $rel) (Join-Path $root $rel) $oldSeed.files[$rel];$files[$rel]=$oldSeed.files[$rel]}
CopyExact $b.app_freeze (Join-Path $root 'inputs/source-freeze.json') $b.app_freeze_sha256;$files['inputs/source-freeze.json']=$b.app_freeze_sha256
$seedPath=Join-Path $root 'envelope-seed-freeze.json';NewJson $seedPath @{schema_version=1;scope='devbrain_standalone_attestation_prepared_seed';files=$files;helper_sha256=$g.helper_sha256;source_freeze_sha256=$b.app_freeze_sha256;runtime_started=$false;backend_passed=$false}
$c=$old
$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=Join-Path $root 'artifacts';$c.backend_run_id=$b.run_id;$c.backend_context=$backendPath;$c.backend_artifact_root=$b.artifact_root
$c.expected_backend_actual_exec_session=$null;$c.expected_backend_cases=1557;$c.source_root=$b.source_root;$c.source_freeze_sha256=$b.app_freeze_sha256;$c.helper_sha256=$g.helper_sha256;$c.qualified_guard_receipt_sha256=$g.receipt_sha256
$c.canonical_output=$plan.canonical_output;$c.canonical_linux_output=$plan.canonical_linux_output;$c.launcher=$launcherPath;$c.launcher_sha256=HashFile $launcherPath;$c.materializer=$materializerPath;$c.materializer_sha256=HashFile $materializerPath
$c.plan=$planPath;$c.plan_sha256=HashFile $planPath;$c.seed_freeze=$seedPath;$c.seed_freeze_sha256=HashFile $seedPath
$c.reverse_transform_only_root_tools_session_count=$true;$c.session_binding='Positive explicit BackendActualExecSession required by Prepare and compared to hash-bound completed context; observer rechecks sealed admission/context equality'
$c.previous_taskstate_prepared_context=$oldPath;$c.previous_taskstate_prepared_context_sha256='664a00e98b3fb34a5b4c122e68cd3e6c8323a52df50696624ef165295c1b74bb'
$c.created_utc=[DateTimeOffset]::UtcNow.ToString('o');$c.actual_backend_context_sha256=$null;$c.actual_backend_receipt_sha256=$null;$c.actual_backend_passed=$false
Artifacts $files $root;Artifacts $g.helper_sha256 $g.windows_tools;NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$root;launcher_sha256=$c.launcher_sha256;materializer_sha256=$c.materializer_sha256;seed_sha256=$c.seed_freeze_sha256;plan_sha256=$c.plan_sha256;expected_cases=1557;backend_session=$null;linux_started=$false;launch_permitted=$false}|ConvertTo-Json
'''
target = e / 'stage-standalone-length-repair-1557-20261108.ps1'
with target.open('x', encoding='utf-8', newline='\n') as stream:
    stream.write(prefix + body)
print(hashlib.sha256(target.read_bytes()).hexdigest())
