#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[ValidateSet('baseline072','target080')][string]$Mode='baseline072')
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for readonly source comparison; no Linux/process is launched.';return}
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



$checker=Join-Path $workspace 'release-tools/check-production-source080-v7.py';$checkerSHA='47838bbff07f73639563c43d0f37c5c92e3dc8ff7ab0529132e4d4fad570b8b3';Verify $checker $checkerSHA
$observer=Join-Path $workspace 'release-tools/run-source-preflight080-v7.ps1';$observerSHA='f03ddf073f85636c3fc5ac53d892f695ec761f5674117c3b8d98afbdd3a819be';Verify $observer $observerSHA
$oldObserver='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification\suite-attest38-envelope-20261108T172927Z-7c934da9\run-full-suite-attestation.ps1'
$oldObserverSHA='effa58f4721b45060d531ebcbd22bb0aa96587bf9cf743f77685ff510f3ff7c2';Verify $oldObserver $oldObserverSHA
foreach($script in @($observer,$oldObserver)){$t=$null;$e=$null;[void][Management.Automation.Language.Parser]::ParseFile($script,[ref]$t,[ref]$e);Require ($e.Count-eq0) 'Observer parse failed'}
$guardPath='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification\source-preflight-baseline072-20261108T202335Z-99cb5d07\inputs\qualified-observer-context.json';$guardSHA='7e1b2c594bbdd2355ff182192561ed5544f39efeba538d3ccb0d70d428550223';Verify $guardPath $guardSHA;$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_windows_exec_session-eq30021-and$g.actual_test_count-eq604-and$g.cleanup_complete-eq$true) 'Actual qualified observer component proof absent'
$receiptSHA='4cd621cdeea918ca9f67c405f463fe1ac1be47546009e39c542b4ad1bbeb6e36';Verify $g.receipt $receiptSHA;$r=ReadMap $g.receipt
Require ($r.passed-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and@($r.errors).Count-eq0) 'Observer component cleanup proof differs'
Artifacts $r.artifact_sha256 $g.artifact_root;Verify $g.freeze_manifest $g.freeze_sha256;$f=ReadMap $g.freeze_manifest;Artifacts $f.files $g.windows_root
Require ($f.files.Count-eq56-and$f.helper_files.Count-eq38) 'Frozen observer bundle differs';SameMap $f.helper_files $g.helper_sha256
$observerHelpers=@{'run-supervised-080.ps1'='721109e2295099fcc4dea6e1a1bc55e773e577e2de673931c33a7e4bb7812c74';'qualification-power-080.ps1'='0a46c1d6a2abca8a4be4dfc79daaff33332e91f95d4c627fe7c301523ba9e8a9'}
foreach($name in $observerHelpers.Keys){Require ($f.helper_files[$name]-ceq$observerHelpers[$name]) 'Reviewed observer helper mismatch';Verify (Join-Path $g.windows_tools $name) $observerHelpers[$name]}
$gatePath=Join-Path $g.artifact_root 'gate.json';$gateSHA='a6bd365cea68986ed6795990272c766679bbd29fd9407e904a12c2956bcdf7fb';Verify $gatePath $gateSHA;$gate=ReadMap $gatePath
Require ($gate.status-ceq'pass'-and$gate.runtime.python_executable-ceq'/home/piotr/.cache/devbrain-runtime-080/runtimes/python/bin/python3.12'-and$gate.runtime.python_binary_sha256-ceq'23bc148d2b48964b621c5561ff2b81c1d9c7b717967a7491efbf12f4304882b5') 'Qualified base Python changed'
$buildPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v7-20261108.json';$buildSHA='cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6';Verify $buildPath $buildSHA;$b=ReadMap $buildPath
Require ($b.actual_windows_exit_code-eq0-and$b.cleanup_complete-eq$true-and$b.source_freeze_sha256-ceq'1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14') 'Current public release build mismatch'
Verify $b.observation $b.observation_sha256;Artifacts $b.output_sha256 $b.windows_root
$zip=Join-Path $b.windows_root 'releases/devbrain-0.7.2.zip';$zipSHA='6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c';$count=182;$packageCount=64
if($Mode-ceq'target080'){$zip=Join-Path $b.candidate_directory 'devbrain-0.8.0.zip';$zipSHA='4fb8b1203dfce52eb5bfd094b2649899316e09ada64cbd2dc14e1bb8de071508';$count=198;$packageCount=69}
Verify $zip $zipSHA
$policy=Join-Path $workspace 'evidence/080-unmanaged-build-output-public-policy-20261108.json';$policySHA='dd4312ebed54b8aea60c9bfccad0317f8f12fcf2e7d6c173099d707c407f425d';Verify $policy $policySHA
# No reads of production, credentials, account stores, config or models occur here.
# All admission above is public evidence. First filesystem mutation is below.
$run='source-preflight-'+$Mode+'-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh comparison root already exists';NoReparse $root
foreach($sub in @('inputs','artifacts')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$art=Join-Path $root 'artifacts';$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt=$linuxRoot+'/artifacts'
$copies=[ordered]@{
 'check-production-source080.py'=@{path=$checker;sha=$checkerSHA};'run-source-preflight080.ps1'=@{path=$observer;sha=$observerSHA}
 'inputs/unmanaged-output-public-policy.json'=@{path=$policy;sha=$policySHA}
 'inputs/materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)};'inputs/approved-observer.ps1'=@{path=$oldObserver;sha=$oldObserverSHA}
 'inputs/gate.json'=@{path=$gatePath;sha=$gateSHA};'inputs/release.zip'=@{path=$zip;sha=$zipSHA}
 'inputs/qualified-observer-context.json'=@{path=$guardPath;sha=$guardSHA};'inputs/qualified-observer-receipt.json'=@{path=$g.receipt;sha=$receiptSHA}
 'inputs/qualified-observer-freeze.json'=@{path=$g.freeze_manifest;sha=$g.freeze_sha256}
 'inputs/candidate-context.json'=@{path=$buildPath;sha=$buildSHA};'inputs/candidate-observation.json'=@{path=$b.observation;sha=$b.observation_sha256}
}
$files=[ordered]@{};foreach($rel in $copies.Keys){$v=$copies[$rel];CopyExact $v.path (Join-Path $root $rel) $v.sha;$files[$rel]=$v.sha}
$argv=@($gate.runtime.python_executable,'-I','-B',($linuxRoot+'/check-production-source080.py'),'--execute','--mode',$Mode,'--source-dir','/home/piotr/src/devbrain','--release-zip',($linuxRoot+'/inputs/release.zip'),'--runtime-gate',($linuxRoot+'/inputs/gate.json'),'--output',($linuxArt+'/source-comparison.json'))
Require ($argv.Count-eq15) 'Direct exact15 checker arguments required'
$plan=@{schema_version=1;scope='devbrain_readonly_source_comparison_launch_plan';run_id=$run;mode=$Mode;windows_root=$root;linux_root=$linuxRoot;production_source='/home/piotr/src/devbrain';python_launcher=$gate.runtime.python_executable;checker_sha256=$checkerSHA;observer_helper_sha256=$observerHelpers;release_zip_sha256=$zipSHA;expected_file_count=$count;expected_package_file_count=$packageCount;checker_argv=$argv;bounded_linux_argv=(@('/usr/bin/timeout','--signal=TERM','--kill-after=5s','60s')+$argv);canonical_output=(Join-Path $art 'source-comparison.json');canonical_linux_output=($linuxArt+'/source-comparison.json');registered_controller=$false;point_in_time_only=$true;deployment_authorized=$false;no_child_process_creation_in_exact_checker=$true}
$planPath=Join-Path $root 'launch-plan.json';NewJson $planPath $plan;$files['launch-plan.json']=HashFile $planPath
$freezePath=Join-Path $root 'input-freeze.json';NewJson $freezePath @{schema_version=1;scope='devbrain_readonly_source_observer_inputs';run_id=$run;files=$files;observer_helper_sha256=$observerHelpers;production_read=$false;linux_executed=$false}
$context=@{schema_version=1;scope='devbrain_readonly_source_comparison_envelope';status='prepared_not_run_pending_explicit_serial_handoff';run_id=$run;mode=$Mode;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;launcher=(Join-Path $root 'run-source-preflight080.ps1');launcher_sha256=$observerSHA;input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);plan=$planPath;plan_sha256=(HashFile $planPath);checker_sha256=$checkerSHA;expected_file_count=$count;expected_package_file_count=$packageCount;release_zip_sha256=$zipSHA;runtime_gate_sha256=$gateSHA;python_executable=$gate.runtime.python_executable;qualified_observer_receipt_sha256=$receiptSHA;candidate_context_sha256=$buildSHA;observer_helper_sha256=$observerHelpers;launch_parameters_without_Execute=@{InputFreezeSha256=(HashFile $freezePath)};production_read=$false;production_modified=$false;registered_controller=$false;application_qualification=$false;release_qualification=$false;deployment_authorized=$false;point_in_time_only=$true;launch_permitted=$false;actual_windows_exit_code=$null;actual_windows_exec_session=$null;comparison_sha256=$null;observation_sha256=$null;cleanup_complete=$false;post_exit_observation_required_seconds=30;created_utc=[DateTimeOffset]::UtcNow.ToString('o')}
Artifacts $files $root;foreach($name in $observerHelpers.Keys){Verify (Join-Path $g.windows_tools $name) $observerHelpers[$name]};Verify $guardPath $guardSHA
$contextPath=Join-Path $root 'prepared-context.json';NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$run;mode=$Mode;launcher=$context.launcher;launcher_sha256=$observerSHA;input_freeze_sha256=$context.input_freeze_sha256;input_count=$files.Count;launch_permitted=$false;linux_started=$false;production_read=$false}|ConvertTo-Json -Depth 5
