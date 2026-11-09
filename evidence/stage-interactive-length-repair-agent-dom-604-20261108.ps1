#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$BackendContextSha256,[string]$QueueContextSha256,[string]$UxContextPath,[string]$UxContextSha256)
if(-not $Stage){Write-Output 'NOT_RUN: current completed backend1557, queue6 and UX377 proof digests are required; no workload is launched.';return}
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



# Future completed proof digests are supplied explicitly; no process is launched.
$masterPath=Join-Path $workspace 'evidence/080-interactive-length-repair-agent-templates-20261108.json'
Verify $masterPath '5f7a9ffe5467eaa2f203986a7385fe60243da249dd6e3b023792f0b72f0c45a4'
$master=ReadMap $masterPath
foreach($entry in $master.files.GetEnumerator()){Verify $entry.Key $entry.Value}
$templatePath=Join-Path $workspace 'evidence/interactive-length-repair-agent-templates-20261108/interactive.context.template.json'
$protocolPath=Join-Path $workspace 'evidence/interactive-length-repair-agent-templates-20261108/operator-protocol.json'
$context=ReadMap $templatePath
$g=ReadMap $context.guard_context
Verify $context.guard_context '0d47b2ea314be36b18749076196693227d91d8395645ad1779a412894582565d'
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.app_run_id-ceq'app080-20261108T202627Z') 'Actual current604 required'
Verify $g.receipt 'c2469d14d080ecdf96d42d6dc4c887207a706898ea3681fa5b10749a26113b82'
Verify $g.freeze_manifest $g.freeze_sha256
$freeze=ReadMap $g.freeze_manifest
Require ($freeze.helper_files.Count-eq38-and$freeze.files.Count-eq56) 'Current helper inventory differs'
Artifacts $freeze.files $g.windows_root
SameMap $freeze.helper_files $g.helper_sha256
$guardSource=ReadMap (Join-Path $g.artifact_root 'regression-source.json')
$sourceHashes=$guardSource.source_hashes
Require ($sourceHashes.Count-gt100-and$sourceHashes.Contains('src/devbrain/agent.py')-and$sourceHashes.Contains('src/devbrain/store.py')) 'Current source proof absent'
Verify $context.source_freeze '1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14'
Verify $context.app_prepare_receipt '4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e'
$app=ReadMap (Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json')
Require ($app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.run_id-ceq$context.source_snapshot-and$app.freeze_sha256-ceq$context.source_freeze_sha256-and$app.setup_receipt_sha256-ceq$context.app_prepare_receipt_sha256) 'Current application preparation changed'
function CleanRun([string]$Path,[string]$Digest,[string]$Role){
 Require ([IO.Path]::GetFullPath($Path).StartsWith((Join-Path $workspace 'evidence')+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($Path)-like'080-*-active-context-20261108.json') 'Only current evidence contexts are admitted'
 Verify $Path $Digest
 $c=ReadMap $Path
 Require ($c.status-ceq'passed'-and$c.actual_windows_exit_code-eq0-and$c.cleanup_complete-eq$true-and$c.actual_windows_exec_session-gt0) 'Actual successful context and cleanup required'
 Require ($c.source_root-ceq$context.source_root-and$c.python_launcher-ceq$context.python_launcher-and$c.source_freeze_sha256-ceq$context.source_freeze_sha256) 'Current source/interpreter required'
 Require ($c.windows_root.StartsWith($physicalBase+'\',[StringComparison]::OrdinalIgnoreCase)-and[IO.Path]::GetFileName($c.windows_root)-ceq$c.run_id-and$c.artifact_root-ceq(Join-Path $c.windows_root 'artifacts')) 'Proof root escaped qualification'
 Require ($c.linux_artifact_root-ceq('/mnt/c/'+$c.artifact_root.Substring(3).Replace('\','/'))) 'Proof C-to-Linux root differs'
 $rp=Join-Path $c.artifact_root 'receipt.json'
 Verify $rp $c.receipt_sha256
 $r=ReadMap $rp
 Require ($r.run_id-ceq$c.run_id-and$r.passed-eq$true-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false) 'Raw proof did not pass'
 Require ($r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and@($r.errors).Count-eq0-and@($r.new_wsl_dumps).Count-eq0-and@($r.new_kernel_fatals).Count-eq0-and$r.initial_boot_id-ceq$r.final_boot_id-and$r.sleep_inhibition.restored-eq$true-and$r.power_monitor.changed-eq$false) 'Raw observation incomplete'
 Artifacts $r.artifact_sha256 $c.artifact_root
 $ctrl=ReadMap (Join-Path $c.artifact_root 'controller-report.json')
 Require ($ctrl.run_id-ceq$c.run_id-and$ctrl.cleanup_complete-eq$true) 'Controller cleanup differs'
 SameMap $ctrl.source_hashes $sourceHashes
 foreach($entry in $r.helper_sha256_start.GetEnumerator()){Require ($entry.Value-ceq$freeze.helper_files[$entry.Key]-and$r.helper_sha256_end[$entry.Key]-ceq$entry.Value) 'Proof helper changed'}
 return @{context=$c;path=$Path;sha256=$Digest;receipt=$r;receipt_path=$rp;receipt_sha256=$c.receipt_sha256;controller=$ctrl}
}
function CompleteTests($Proof,[string]$CollectionName,[string]$XMLName,[int]$Expected){
 $root=$Proof.context.artifact_root
 $collection=ReadMap (Join-Path $root $CollectionName)
 Require ($collection.run_id-ceq$Proof.context.run_id-and$collection.nodeids.Count-eq$Expected) 'Complete current collection required'
 $wanted=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 foreach($id in $collection.nodeids){Require ($id-is[string]-and$id-and$wanted.Add($id)) 'Collection duplicate or empty case'}
 $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null
 $reader=[Xml.XmlReader]::Create((Join-Path $root $XMLName),$settings)
 try{$xml=[Xml.XmlDocument]::new();$xml.XmlResolver=$null;$xml.Load($reader)}finally{$reader.Dispose()}
 Require ($xml.DocumentElement.psbase.Name-in@('testsuite','testsuites')-and$xml.SelectNodes('//failure|//error|//skipped').Count-eq0) 'JUnit contains nonpassing tests'
 $cases=$xml.SelectNodes('//testcase');Require ($cases.Count-eq$Expected) 'JUnit case count differs'
 $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
 foreach($case in $cases){$p=$case.SelectNodes('./properties/property[@name="nodeid"]');Require ($p.Count-eq1-and$wanted.Contains($p[0].GetAttribute('value'))-and$seen.Add($p[0].GetAttribute('value'))) 'JUnit differs from complete collection'}
}
$backend=CleanRun $context.backend_prerequisite_context $BackendContextSha256 'backend'
Require ($backend.controller.status-ceq'full_suite_completed_pending_attestation'-and$backend.controller.pytest_returncode-eq0-and$backend.controller.collection_returncode-eq0-and$backend.controller.source_unchanged-eq$true) 'Whole backend incomplete'
CompleteTests $backend 'collection.json' 'pytest.xml' 1557
$frozen=ReadMap (Join-Path $backend.context.artifact_root 'frozen-source.json');Require ($frozen.expected_skips.Count-eq0) 'No backend skip allowance'
$queue=CleanRun $context.queue_prerequisite_context $QueueContextSha256 'queue'
Require ($queue.controller.status-ceq'queue_copy_completed_pending_external_watch'-and$queue.controller.all_six_replayed-eq$true-and$queue.controller.production_modified-eq$false-and$queue.controller.backup_sha256-ceq'698591d33252a1f0e802a01fac78feb90f56ef37fc0c5f717ed26667f635ac70'-and$queue.controller.jobs.Count-eq6-and$queue.controller.unrelated_jobs_unchanged-eq$true) 'Fresh complete original six-job copy required'
$kinds=@{import=0;extract=0};foreach($job in $queue.controller.jobs){Require ($kinds.ContainsKey($job.kind)-and$job.state-ceq'completed'-and$job.attempts-eq$job.previous_attempts+1) 'Selected copy attempt did not complete';$kinds[$job.kind]++}
Require ($kinds.import-eq3-and$kinds.extract-eq3) 'Six historical kinds differ';SameMap $queue.controller.duplicate_counts_before $queue.controller.duplicate_counts_after
$ux=CleanRun $UxContextPath $UxContextSha256 'ux'
Require ($ux.controller.status-ceq'regressions_completed_pending_external_watch') 'Current UX controller incomplete'
CompleteTests $ux 'ux-collection.json' 'ux.xml' 377
$uxResults=ReadMap (Join-Path $ux.context.artifact_root 'regressions-results.json')
Require ($uxResults.phase-ceq'ux'-and$uxResults.modules.Count-eq28-and$uxResults.counts.collected-eq377-and$uxResults.counts.passed-eq377-and$uxResults.counts.skipped-eq0-and$uxResults.counts.failures-eq0-and$uxResults.counts.errors-eq0) 'Current UX377/28 required'
Verify $g.candidate_build_context $g.candidate_build_context_sha256
$candidate=ReadMap $g.candidate_build_context
Require ($candidate.status-ceq'candidate_built_observed_not_qualified'-and$candidate.actual_windows_exit_code-eq0-and$candidate.cleanup_complete-eq$true-and$candidate.source_freeze_sha256-ceq$context.source_freeze_sha256) 'Current candidate incomplete'
Verify $candidate.observation $candidate.observation_sha256
Verify $context.reviewed_agent_driver $context.reviewed_agent_driver_sha256
$contextPath=Join-Path $workspace 'evidence/080-interactive-length-repair-agent-active-context-20261108.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Never overwrite an interactive trial'
$runId='interactive-length-repair080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $runId
Require (-not(Test-Path -LiteralPath $root)) 'Fresh interactive root required'
NoReparse $root
foreach($sub in @('artifacts','inputs')){$null=[IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$artifacts=Join-Path $root 'artifacts';$files=[ordered]@{}
function CopyInput([string]$Source,[string]$Name,[string]$Digest){CopyExact $Source (RelativeFile $root $Name) $Digest;$files[$Name]=$Digest}
$entries=@(
 @($context.guard_context,'inputs/guard-context.json',$context.guard_context_sha256),@($g.receipt,'inputs/guard-receipt.json',$g.receipt_sha256),@($g.freeze_manifest,'inputs/toolbundle-freeze.json',$g.freeze_sha256),
 @((Join-Path $g.artifact_root 'regression-source.json'),'inputs/guard-source.json',(HashFile (Join-Path $g.artifact_root 'regression-source.json'))),
 @((Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'),'inputs/app-context.json',(HashFile (Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'))),
 @($app.freeze_manifest,'inputs/source-freeze.json',$app.freeze_sha256),@($app.setup_receipt,'inputs/prepare-receipt.json',$app.setup_receipt_sha256),
 @($backend.path,'inputs/backend-context.json',$backend.sha256),@($backend.receipt_path,'inputs/backend-receipt.json',$backend.receipt_sha256),
 @($queue.path,'inputs/queue-context.json',$queue.sha256),@($queue.receipt_path,'inputs/queue-receipt.json',$queue.receipt_sha256),
 @($ux.path,'inputs/ux-context.json',$ux.sha256),@($ux.receipt_path,'inputs/ux-receipt.json',$ux.receipt_sha256),
 @($g.candidate_build_context,'inputs/candidate-context.json',$g.candidate_build_context_sha256),@($candidate.observation,'inputs/candidate-observation.json',$candidate.observation_sha256),
 @($templatePath,'inputs/interactive-context-template.json',(HashFile $templatePath)),@($protocolPath,'inputs/operator-protocol.json',(HashFile $protocolPath)),
 @((Join-Path $g.artifact_root 'gate.json'),'artifacts/gate.json',$g.gate_sha256),
 @($context.reviewed_agent_driver,'artifacts/agent-pty-relay-pixels.py',$context.reviewed_agent_driver_sha256)
)
foreach($entry in $entries){CopyInput $entry[0] $entry[1] $entry[2]}
$spec=ReadMap $context.specification_template
Require ($spec.argv.Count-eq23-and$spec.argv[19]-ceq'--operator'-and$spec.argv[20]-ceq'agent'-and$spec.argv[21]-ceq'--duration'-and$spec.argv[22]-ceq'1800') 'Official UI contract changed'
$oldSpec=ReadMap $context.specification_template
$spec.run_id=$runId;$spec.python_launcher=$app.python_launcher;$spec.argv[2]=$runId;$spec.argv[4]=$linuxRoot+'/artifacts';$spec.argv[6]=$app.source_root
for($i=0;$i-lt23;$i++){if($i-notin@(2,4,6)){Require ($spec.argv[$i]-ceq$oldSpec.argv[$i]) 'Unexpected UI argument mutation'}}
SameMap $spec.env $oldSpec.env
$specPath=Join-Path $artifacts 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
Artifacts $files $root
$inputFreeze=Join-Path $root 'prepared-input-freeze.json'
NewJson $inputFreeze @{schema_version=1;run_id=$runId;status='prepared_not_run';files=$files;helper_sha256=$freeze.helper_files;source_freeze_sha256=$context.source_freeze_sha256;operator='agent';human_reported=$false;application_qualified=$false;previous_results_pooled=$false}
$context.run_id=$runId;$context.windows_root=$root;$context.linux_root=$linuxRoot;$context.artifact_root=$artifacts;$context.linux_artifact_root=$linuxRoot+'/artifacts'
$context.status='prepared_not_run';$context.specification=$specPath;$context.specification_sha256=HashFile $specPath;$context.execution_argv_materialized=$true;$context.materialization_required=$false
$context.windows_tools=$g.windows_tools;$context.linux_tools=$g.linux_tools;$context.controller=$g.linux_tools+'/run-interactive-ux080.py';$context.controller_name='run-interactive-ux080.py';$context.controller_sha256=$freeze.helper_files['run-interactive-ux080.py'];$context.wrapper=Join-Path $g.windows_tools 'run-supervised-080.ps1';$context.base_python=$g.base_python;$context.required_artifacts=$spec.required_artifacts
$context.input_freeze=$inputFreeze;$context.input_freeze_sha256=HashFile $inputFreeze;$context.frozen_input_count=$files.Count;$context.gate_sha256=$g.gate_sha256
$context.backend_prerequisite_passed=$true;$context.backend_prerequisite_context_sha256=$BackendContextSha256;$context.backend_prerequisite_receipt_sha256=$backend.receipt_sha256
$context.queue_prerequisite_passed=$true;$context.queue_prerequisite_context_sha256=$QueueContextSha256;$context.queue_prerequisite_receipt_sha256=$queue.receipt_sha256
$context.ux_prerequisite_context=$UxContextPath;$context.ux_prerequisite_context_sha256=$UxContextSha256;$context.ux_prerequisite_passed=$true;$context.ux_prerequisite_receipt_sha256=$ux.receipt_sha256
$context.ready_file=Join-Path $artifacts 'interactive-ready.json';$context.agent_pty_relay_pixels=Join-Path $artifacts 'agent-pty-relay-pixels.py';$context.agent_pty_relay_pixels_sha256=$context.reviewed_agent_driver_sha256;$context.active_agent_pty_relay=$linuxRoot+'/artifacts/agent-pty-relay-pixels.py'
$context.launch_parameters_without_Execute=@{ArtifactRoot=$artifacts;LinuxArtifactRoot=($linuxRoot+'/artifacts');PythonExecutable=$g.base_python;Controller=$context.controller;ControllerArgumentsFile=$specPath;RunId=$runId;TimeoutSeconds=1980;CleanupGraceSeconds=30;WslCrashDirectory=$g.wsl_crash_directory}
$context.preparation_only=$true;$context.prepared_utc=[DateTime]::UtcNow.ToString('o')
NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$runId;specification_sha256=(HashFile $specPath);input_freeze_sha256=(HashFile $inputFreeze);inputs=$files.Count;required_observations=8;operator='agent';human_reported=$false;launch_permitted=$false;Linux_started=$false}|ConvertTo-Json -Depth 5
