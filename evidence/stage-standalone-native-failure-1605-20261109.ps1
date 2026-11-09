#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for standalone1605 attestation metadata; this script never launches a process.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$sourceHelper=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $sourceHelper -Algorithm SHA256).Hash.ToLowerInvariant() -cne '6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical staging source changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($sourceHelper,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Canonical staging syntax changed'}
$nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ceq 'Add-Type'},$false))
if($nodes.Count-ne1){throw 'Canonical helper inventory changed'};. ([scriptblock]::Create($nodes[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$false))
 if($nodes.Count-ne1){throw 'Canonical function inventory changed'};. ([scriptblock]::Create($nodes[0].Extent.Text))
}
function Require([bool]$Good,[string]$Message){if(-not $Good){throw $Message}}
function PathProof([string]$Path){
 if($Path.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){SourceProof $Path}
 else{NoReparse $Path;Require ([QualificationStagePath080]::FinalPath($Path).Equals([IO.Path]::GetFullPath($Path),[StringComparison]::OrdinalIgnoreCase)) 'Canonical physical path differs'}
}
function ReadMap([string]$Path){PathProof $Path;Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -AsHashtable -DateKind String}
function Verify([string]$Path,[string]$Digest){Require ($Digest-cmatch'^[0-9a-f]{64}$') 'Missing exact digest';PathProof $Path;Require ((HashFile $Path)-ceq$Digest) 'Input digest differs'}
function NewJson([string]$Path,$Value){
 if($Path.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){NoReparse $Path $workspace}else{NoReparse $Path}
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 60)+[Environment]::NewLine)
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()};PathProof $Path
}
function CopyExact([string]$Source,[string]$Target,[string]$Digest){
 Verify $Source $Digest;NoReparse $Target;[IO.File]::Copy($Source,$Target,$false)
 Verify $Target $Digest;Verify $Source $Digest
}
function RelativeFile([string]$Root,[string]$Relative){
 Require ($Relative-and$Relative-notmatch'(^|/)\.\.(/|$)|\\|:'-and-not$Relative.StartsWith('/')) 'Unsafe relative evidence path'
 $p=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
 Require ($p.StartsWith([IO.Path]::GetFullPath($Root).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'Relative evidence escaped root'
 return $p
}
function SameMap($Actual,$Expected){
 Require ($Actual.Count-eq$Expected.Count) 'Map count differs'
 foreach($k in $Expected.Keys){Require ($Actual.Contains($k)-and$Actual[$k]-ceq$Expected[$k]) "Map mismatch: $k"}
}
function Artifacts($Map,[string]$Root){Require ($Map.Count-gt0) 'Empty digest map';foreach($k in $Map.Keys){Verify (RelativeFile $Root $k) $Map[$k]}}




$oldPath=Join-Path $workspace 'evidence/080-standalone-sidebar-resize-attestation-prepared-context-20261109.json'
Verify $oldPath 'dd0b9167aefc8729ffd7ce3a218d23fc257fef890cf419bf0e8f4d6e3b4aea4b';$old=ReadMap $oldPath
Verify $old.launcher '174a7e601b9b991a5baa02fe1bac109e78ec8c62e1b4aac61ed0b25cbb7572c7'
Verify $old.materializer '5f866de6f81c19b9a560c482510ec12305d7a7ecd71692f03123b52193a5cf94'
Verify $old.seed_freeze $old.seed_freeze_sha256;$oldSeed=ReadMap $old.seed_freeze;Artifacts $oldSeed.files $old.windows_root
$backendPath=Join-Path $workspace 'evidence/080-fullbackend-native-failure-diagnostic-active-context-20261109.json'
Verify $backendPath '8a4b0c1a1a3074d98f9e3bd04069607bcf008ab2b122ec5cd4a6fb8c4c18d37e';$b=ReadMap $backendPath
Require ($b.status-ceq'diagnostic_passed_not_release_qualified'-and$b.actual_test_count-eq1605-and$b.actual_windows_exit_code-eq0-and$b.actual_windows_exec_session-eq74540-and$b.cleanup_complete-eq$true) 'Actual current1605 backend completion required'
Verify $b.receipt '9416368767ed5d6ec8eee6486da9f868ee6350ebc1c5231300b242b0d6343d6b'
Verify $b.final_report '106bb67cfd1338b26041d547192cc1ba6b6939cd69ab9911c07d8bca4340430b'
Verify $b.input_freeze $b.input_freeze_sha256;$bf=ReadMap $b.input_freeze;Artifacts $bf.files $b.windows_root
Verify $b.guard_context '9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6';$g=ReadMap $b.guard_context
Verify $g.receipt '9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.helper_file_count-eq38) 'Current604 incomplete'
SameMap $g.helper_sha256 $old.helper_sha256;SameMap $g.helper_sha256 $b.helper_sha256;Artifacts $g.helper_sha256 $g.windows_tools
Verify $b.app_freeze '9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9'
Verify $b.app_prepare_receipt 'fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd'
$contextPath=Join-Path $workspace 'evidence/080-standalone-native-failure-attestation-prepared-context-20261109.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Never overwrite historical prepared context'
$run='suite-attest-native-failure-envelope-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh envelope required';NoReparse $root
foreach($sub in @('inputs','artifacts')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
function NewText([string]$Path,[string]$Text){NoReparse $Path;$s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text);$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()};PathProof $Path}
$plan=ReadMap $old.plan
$plan.run_id=$run;$plan.backend_run_id=$b.run_id;$plan.backend_context=$backendPath;$plan.backend_root=$b.artifact_root;$plan.backend_linux_root=$b.linux_artifact_root
$plan.backend_root_actual_exec_session=$null;$plan.source_root=$b.source_root;$plan.source_freeze=$b.app_freeze;$plan.source_freeze_sha256=$b.app_freeze_sha256;$plan.python_launcher=$b.python_launcher;$plan.tools=$g.windows_tools
$plan.helper_sha256=$g.helper_sha256;$plan.expected_cases=1605;$plan.canonical_output=Join-Path $b.artifact_root 'final-full-suite.json';$plan.canonical_linux_output=$b.linux_artifact_root+'/final-full-suite.json'
$plan.attestor_argv=@($b.python_launcher,'-I','-B',($g.linux_tools+'/attest-full-suite-080.py'),'--artifact-root',$b.linux_artifact_root,'--source-root',$b.source_root,'--mode','full-suite','--output',$plan.canonical_linux_output)
$plan.bounded_linux_argv=@('/usr/bin/timeout','--signal=TERM','--kill-after=5s','120s')+$plan.attestor_argv
Require ($plan.attestor_argv.Count-eq12-and$plan.bounded_linux_argv.Count-eq16-and-not(Test-Path -LiteralPath $plan.canonical_output)) 'Canonical argv/output differs'
$launcher=[IO.File]::ReadAllText($old.launcher).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace('1561','1605').Replace("`$context.status -cne 'passed'","`$context.status -cne 'diagnostic_passed_not_release_qualified'")
$launcher=$launcher.Replace('$freeze.backend_root_exec_session -ne 64756','($freeze.backend_root_exec_session -isnot [long] -and $freeze.backend_root_exec_session -isnot [int]) -or $freeze.backend_root_exec_session -le 0')
$launcher=$launcher.Replace('$context.actual_windows_exec_session -ne 64756','$context.actual_windows_exec_session -ne $freeze.backend_root_exec_session')
$materializer=[IO.File]::ReadAllText($old.materializer).Replace($old.windows_root,$root).Replace((ReadMap $old.plan).tools,$g.windows_tools).Replace("`$context.status -ceq 'passed'","`$context.status -ceq 'diagnostic_passed_not_release_qualified'")
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
$c.source_final=$false;$c.application_qualified=$false;$c.release_qualified=$false;$c.qualified=$false;$c.diagnostic_only=$true;$c.error_inventory_only=$true;$c.guard_qualifies_current_source=$false;$c.status='prepared_pending_actual_backend_admission'
$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=Join-Path $root 'artifacts';$c.backend_run_id=$b.run_id;$c.backend_context=$backendPath;$c.backend_artifact_root=$b.artifact_root
$c.expected_backend_actual_exec_session=74540;$c.expected_backend_cases=1605;$c.source_root=$b.source_root;$c.source_freeze_sha256=$b.app_freeze_sha256;$c.helper_sha256=$g.helper_sha256;$c.qualified_guard_receipt_sha256=$g.receipt_sha256
$c.canonical_output=$plan.canonical_output;$c.canonical_linux_output=$plan.canonical_linux_output;$c.launcher=$launcherPath;$c.launcher_sha256=HashFile $launcherPath;$c.materializer=$materializerPath;$c.materializer_sha256=HashFile $materializerPath
$c.plan=$planPath;$c.plan_sha256=HashFile $planPath;$c.seed_freeze=$seedPath;$c.seed_freeze_sha256=HashFile $seedPath
$c.reverse_transform_only_root_tools_session_count=$false;$c.reverse_transform_only_root_tools_count_and_diagnostic_status=$true;$c.session_binding='Positive explicit BackendActualExecSession required by Prepare and compared to hash-bound completed context; observer rechecks sealed admission/context equality'
$c.previous_taskstate_prepared_context=$oldPath;$c.previous_taskstate_prepared_context_sha256='dd0b9167aefc8729ffd7ce3a218d23fc257fef890cf419bf0e8f4d6e3b4aea4b'
$c.created_utc=[DateTimeOffset]::UtcNow.ToString('o');$c.actual_backend_context_sha256=$null;$c.actual_backend_receipt_sha256=$null;$c.actual_backend_passed=$false
Artifacts $files $root;Artifacts $g.helper_sha256 $g.windows_tools;NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$root;launcher_sha256=$c.launcher_sha256;materializer_sha256=$c.materializer_sha256;seed_sha256=$c.seed_freeze_sha256;plan_sha256=$c.plan_sha256;expected_cases=1605;backend_session=74540;linux_started=$false;launch_permitted=$false}|ConvertTo-Json
