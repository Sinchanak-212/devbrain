#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){'NOT_RUN: independent diagnostic UI filesystem staging only; no account/model process.';return}
# Explicit user: parallel isolated instances; collect independent functional failures; NO8h.
# This new diagnostic admission does NOT modify or satisfy formal 37e UI admission.
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



$masterPath=Join-Path $workspace 'evidence/080-interactive-sidebar-resize-agent-templates-20261108.json'
Verify $masterPath '4d5597f51bc8ebb0da7b286a1a8b167a0bf088f150649726e39078edc325ceb3'
$master=ReadMap $masterPath
foreach($entry in $master.files.GetEnumerator()){Verify $entry.Key $entry.Value}
$templatePath=Join-Path $workspace 'evidence/interactive-sidebar-resize-agent-templates-20261108/interactive.context.template.json'
$protocolPath=Join-Path $workspace 'evidence/interactive-sidebar-resize-agent-templates-20261108/operator-protocol.json'
$context=ReadMap $templatePath
$guardSHA='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6'
$receiptSHA='9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
Verify $context.guard_context $guardSHA
$g=ReadMap $context.guard_context
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.actual_windows_exec_session-eq82992-and$g.app_run_id-ceq'app080-20261108T222731Z') 'Current604 required'
Verify $g.receipt $receiptSHA
Verify $g.final_report 'ad4a0f638bef723c4e8c918e2daeb4f71eac60e238d32ea454586ca53d326e8f'
$guardRaw=ReadMap $g.receipt
Require ($guardRaw.passed-eq$true-and$guardRaw.cleanup_complete-eq$true-and$guardRaw.forced_cleanup-eq$false-and$guardRaw.native_failure-eq$false-and$guardRaw.scope_empty_verified-eq$true-and$guardRaw.scope_cleanup_grace_seconds-ge30-and$guardRaw.cleanup_grace_seconds-ge30-and$guardRaw.sleep_inhibition.restored-eq$true) 'Guard cleanup differs'
Artifacts $guardRaw.artifact_sha256 $g.artifact_root
Verify $g.freeze_manifest $g.freeze_sha256
$freeze=ReadMap $g.freeze_manifest
Require ($freeze.helper_files.Count-eq38-and$freeze.files.Count-eq56) 'Wrong current helper inventory'
Artifacts $freeze.files $g.windows_root
SameMap $freeze.helper_files $g.helper_sha256
SameMap $freeze.helper_files $context.helper_sha256
$guardSourcePath=Join-Path $g.artifact_root 'regression-source.json'
$guardSource=ReadMap $guardSourcePath
Require ($guardSource.source_hashes.Count-eq153) 'Wrong current code manifest'
Verify $context.source_freeze 'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'
Verify $context.app_prepare_receipt '4cba08753a5d44463687271f5e695ccddac4d2284ca348b66630f480facde918'
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
$app=ReadMap $appPath
Require ($app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.run_id-ceq'app080-20261108T222731Z'-and$app.freeze_sha256-ceq$context.source_freeze_sha256) 'Current app differs'
$af=ReadMap $app.freeze_manifest
Require ($af.app_files-eq198-and$af.files.Count-eq209) 'Current App209/198 differs'
Artifacts $af.files $app.bundle_root
foreach($name in $guardSource.source_hashes.Keys){Require ($guardSource.source_hashes[$name]-ceq$af.files['devbrain/'+$name]) 'Current executed code manifest differs'}
Verify $g.candidate_build_context '6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b'
$candidate=ReadMap $g.candidate_build_context
Require ($candidate.status-ceq'candidate_built_observed_not_qualified'-and$candidate.actual_windows_exit_code-eq0-and$candidate.cleanup_complete-eq$true-and$candidate.source_freeze_sha256-ceq$context.source_freeze_sha256) 'Current V8 differs'
Verify $candidate.observation $candidate.observation_sha256
foreach($name in $candidate.output_sha256.Keys){Verify (RelativeFile $candidate.windows_root $name) $candidate.output_sha256[$name]}
$queuePath=Join-Path $workspace 'evidence/080-queue-copy-sidebar-resize-active-context-20261108.json'
Verify $queuePath 'a05caa481f1a2bbf6c47151b64cfd7b30207963e9bea0fdcaabf5becdfed32b4'
$queue=ReadMap $queuePath
Require ($queue.status-ceq'passed'-and$queue.actual_windows_exec_session-eq61090-and$queue.actual_windows_exit_code-eq0-and$queue.cleanup_complete-eq$true-and$queue.source_freeze_sha256-ceq$context.source_freeze_sha256) 'Current copy6 differs'
Verify $queue.receipt 'ffc1eab7c6d973de8810e57b5f0f620536fdfdbe16501d538e14c062c7a81b13'
Verify $queue.final_report 'e00816e8d2c8c6a66ecdac5b8af460431f75944f98653b4d58692a2ec3421515'
Verify $context.reviewed_agent_driver $context.reviewed_agent_driver_sha256
$contextPath=Join-Path $workspace 'evidence/080-diagnostic-interactive-sidebar-resume-active-context-20261109.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Never overwrite a diagnostic UI trial'
$runId='diag-interactive-sidebar080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $runId
Require (-not(Test-Path -LiteralPath $root)) 'Fresh diagnostic root required'
NoReparse $root
foreach($sub in @('artifacts','inputs')){$null=[IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$artifacts=Join-Path $root 'artifacts';$files=[ordered]@{}
function CopyInput([string]$Source,[string]$Name,[string]$Digest){CopyExact $Source (RelativeFile $root $Name) $Digest;$files[$Name]=$Digest}
$entries=@(
 @($context.guard_context,'inputs/guard-context.json',$guardSHA),@($g.receipt,'inputs/guard-receipt.json',$receiptSHA),@($g.freeze_manifest,'inputs/toolbundle-freeze.json',$g.freeze_sha256),
 @($guardSourcePath,'inputs/guard-source.json',(HashFile $guardSourcePath)),@($appPath,'inputs/app-context.json',(HashFile $appPath)),
 @($app.freeze_manifest,'inputs/source-freeze.json',$app.freeze_sha256),@($app.setup_receipt,'inputs/prepare-receipt.json',$app.setup_receipt_sha256),
 @($queuePath,'inputs/queue-context.json',(HashFile $queuePath)),@($queue.receipt,'inputs/queue-receipt.json',$queue.receipt_sha256),@($queue.final_report,'inputs/queue-final-report.json',$queue.final_report_sha256),
 @($g.candidate_build_context,'inputs/candidate-context.json',$g.candidate_build_context_sha256),@($candidate.observation,'inputs/candidate-observation.json',$candidate.observation_sha256),
 @($templatePath,'inputs/interactive-context-template.json',(HashFile $templatePath)),@($protocolPath,'inputs/operator-protocol.json',(HashFile $protocolPath)),
 @((Join-Path $g.artifact_root 'gate.json'),'artifacts/gate.json',$g.gate_sha256),
 @($context.reviewed_agent_driver,'artifacts/agent-pty-relay-pixels.py',$context.reviewed_agent_driver_sha256)
)
foreach($entry in $entries){CopyInput $entry[0] $entry[1] $entry[2]}
$admission=[ordered]@{
 schema_version=1;purpose='independent_diagnostic_UI_error_inventory';not_release_admission=$true;run_id=$runId
 user_authorization='Parallel isolated instances; continue independent tests after ordinary functional failure; NO8h.'
 source_freeze_sha256=$context.source_freeze_sha256;current604_pass=$true;current_copy6_pass=$true;v8_built_not_qualified=$true
 missing_formal_prerequisites=@('current complete backend1561 final acceptance','current UX381 final acceptance','current canonical full-suite1561 attestation')
 formal_backend_pass_claimed=$false;formal_UX_pass_claimed=$false;formal_UI_admission37e_modified=$false
 application_qualified=$false;release_qualified=$false;source_final=$false;human_reported=$false
 native_account_lease_acquired_during_staging=$false;account_queries_or_credentials_read_during_staging=$false
 actual_start_requires_root_GO_and_exclusive_native_account_lease=$true;eight_hours_authorized=$false
}
$admissionPath=Join-Path $root 'inputs/diagnostic-admission.json'
NewJson $admissionPath $admission;$files['inputs/diagnostic-admission.json']=HashFile $admissionPath
$spec=ReadMap $context.specification_template
Require ($spec.argv.Count-eq23-and$spec.argv[19]-ceq'--operator'-and$spec.argv[20]-ceq'agent'-and$spec.argv[21]-ceq'--duration'-and$spec.argv[22]-ceq'1800') 'Official UI contract changed'
$oldSpec=ReadMap $context.specification_template
$spec.run_id=$runId;$spec.python_launcher=$app.python_launcher;$spec.argv[2]=$runId;$spec.argv[4]=$linuxRoot+'/artifacts';$spec.argv[6]=$app.source_root
for($i=0;$i-lt23;$i++){if($i-notin@(2,4,6)){Require ($spec.argv[$i]-ceq$oldSpec.argv[$i]) 'Unexpected UI argument mutation'}}
SameMap $spec.env $oldSpec.env
$specPath=Join-Path $artifacts 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
Artifacts $files $root
$inputFreeze=Join-Path $root 'prepared-input-freeze.json'
NewJson $inputFreeze @{schema_version=1;run_id=$runId;status='prepared_not_run';files=$files;helper_sha256=$freeze.helper_files;source_freeze_sha256=$context.source_freeze_sha256;operator='agent';human_reported=$false;application_qualified=$false;previous_results_pooled=$false;diagnostic_only=$true;formal_prerequisites_missing=$admission.missing_formal_prerequisites}
$context.run_id=$runId;$context.windows_root=$root;$context.linux_root=$linuxRoot;$context.artifact_root=$artifacts;$context.linux_artifact_root=$linuxRoot+'/artifacts'
$context.status='prepared_not_run';$context.specification=$specPath;$context.specification_sha256=HashFile $specPath;$context.execution_argv_materialized=$true;$context.materialization_required=$false
$context.windows_tools=$g.windows_tools;$context.linux_tools=$g.linux_tools;$context.controller=$g.linux_tools+'/run-interactive-ux080.py';$context.controller_name='run-interactive-ux080.py';$context.controller_sha256=$freeze.helper_files['run-interactive-ux080.py'];$context.wrapper=Join-Path $g.windows_tools 'run-supervised-080.ps1';$context.base_python=$g.base_python;$context.required_artifacts=$spec.required_artifacts
$context.guard_context_sha256=$guardSHA;$context.guard_receipt=$g.receipt;$context.guard_receipt_sha256=$receiptSHA;$context.guard_passed=$true;$context.guard_actual_windows_exit_code=0
$context.toolbundle_freeze=$g.freeze_manifest;$context.toolbundle_freeze_sha256=$g.freeze_sha256
$context.candidate_build_context=$g.candidate_build_context;$context.candidate_build_context_sha256=$g.candidate_build_context_sha256
$context.candidate_updater_sha256=$g.updater_sha256;$context.candidate_zip_sha256=$g.candidate_zip_sha256
$context.input_freeze=$inputFreeze;$context.input_freeze_sha256=HashFile $inputFreeze;$context.frozen_input_count=$files.Count;$context.gate_sha256=$g.gate_sha256
$context.backend_prerequisite_context=$null;$context.backend_prerequisite_context_sha256=$null;$context.backend_prerequisite_receipt_sha256=$null;$context.backend_prerequisite_passed=$false
$context.ux_prerequisite_context=$null;$context.ux_prerequisite_context_sha256=$null;$context.ux_prerequisite_receipt_sha256=$null;$context.ux_prerequisite_passed=$false
$context.queue_prerequisite_context=$queuePath;$context.queue_prerequisite_context_sha256=HashFile $queuePath;$context.queue_prerequisite_receipt_sha256=$queue.receipt_sha256;$context.queue_prerequisite_passed=$true
$context.launch_requires_backend_pass=$false;$context.launch_requires_ux_pass=$false;$context.launch_requires_queue_pass=$false
$context.diagnostic_only=$true;$context.purpose='independent_diagnostic_UI_error_inventory';$context.formal_release_admission=$false;$context.missing_formal_prerequisites=$admission.missing_formal_prerequisites
$context.application_qualified=$false;$context.release_qualified=$false;$context.source_final=$false;$context.source_finalized=$false;$context.source_qualification_pending=$true
$context.diagnostic_admission=$admissionPath;$context.diagnostic_admission_sha256=HashFile $admissionPath
$context.ready_file=Join-Path $artifacts 'interactive-ready.json';$context.agent_pty_relay_pixels=Join-Path $artifacts 'agent-pty-relay-pixels.py';$context.agent_pty_relay_pixels_sha256=$context.reviewed_agent_driver_sha256;$context.active_agent_pty_relay=$linuxRoot+'/artifacts/agent-pty-relay-pixels.py'
$context.launch_parameters_without_Execute=@{ArtifactRoot=$artifacts;LinuxArtifactRoot=($linuxRoot+'/artifacts');PythonExecutable=$g.base_python;Controller=$context.controller;ControllerArgumentsFile=$specPath;RunId=$runId;TimeoutSeconds=1980;CleanupGraceSeconds=30;WslCrashDirectory=$g.wsl_crash_directory}
$context.preparation_only=$true;$context.prepared_utc=[DateTime]::UtcNow.ToString('o');$context.actual_windows_exec_session=$null;$context.actual_windows_exit_code=$null;$context.linux_workload_started=$false;$context.cleanup_complete=$false
NewJson $contextPath $context
@{context=$contextPath;context_sha256=HashFile $contextPath;run_id=$runId;root=$root;specification_sha256=HashFile $specPath;input_freeze_sha256=HashFile $inputFreeze;inputs=$files.Count;argv_count=23;required_observations=8;diagnostic_only=$true;formal_prereqs_claimed_passed=$false;credentials_read=$false;Linux_started=$false;launch_permitted=$false}|ConvertTo-Json -Depth 5