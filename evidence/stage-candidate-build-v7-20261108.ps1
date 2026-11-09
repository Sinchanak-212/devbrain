#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$AppContextSha256,[string]$PrepareReceiptSha256)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for candidate v7; this script never launches a process.';return}
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

$oldContextPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v6-20261108.json'
$appContextPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
Verify $oldContextPath 'c0adf65d68f858b03b4c4b72979c7ab73a55d4e76a922034061ec59176acf3f4'
Verify $appContextPath $AppContextSha256
$old=ReadMap $oldContextPath;$app=ReadMap $appContextPath
Require ($app.run_id-ceq'app080-20261108T202627Z'-and$app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.app_files-eq198-and$app.qualified_package_pin_count-eq59-and$app.pins_unchanged-eq$true-and$app.linux_source_matches_freeze-eq$true-and$app.native_failure-eq$false-and$app.cleanup_grace_seconds-ge30) 'New app actual preparation is incomplete'
Require ($app.freeze_sha256-ceq'1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14'-and$app.setup_receipt_sha256-ceq$PrepareReceiptSha256) 'New app identity differs'
Verify $app.freeze_manifest $app.freeze_sha256;Verify $app.setup_receipt $app.setup_receipt_sha256
foreach($pair in @(@('input_freeze','input_freeze_sha256'),@('launcher','launcher_sha256'),@('launch_plan','launch_plan_sha256'),@('launcher_freeze','launcher_freeze_sha256'))){Verify $old[$pair[0]] $old[$pair[1]]}
Require ($old.launcher_sha256-ceq'3ea150c7dccb545b9ba3f2bef47de1aeb878884bc60c5b96c6294ea3a52d71ac') 'Approved v6 launcher differs'
Verify (Join-Path $old.windows_root 'builder-ast-proof.json') '805ed8c08906668dadb0a8df7e13886720b12f4605b99e144d7f33c22a7737cb'
$oldFreeze=ReadMap $old.input_freeze;$source=ReadMap $app.freeze_manifest
$appKeys=@($source.files.Keys|Where-Object{$_.StartsWith('devbrain/')}|Sort-Object)
Require ($appKeys.Count-eq198) 'Exactly 198 app files required'
$changed=@($appKeys|Where-Object{$oldFreeze.files[$_]-cne$source.files[$_]})
$expectedChanged=@('devbrain/src/devbrain/agent.py','devbrain/tests/test_extraction_safety.py')
Require (($changed -join '|')-ceq($expectedChanged -join '|')) 'Unexpected app delta from v6'
foreach($rel in $appKeys){Verify (RelativeFile $app.bundle_root $rel) $source.files[$rel]}
$copyOld=@('release-tools/build-devbrain-update-080.py','release-tools/devbrain-update080-template.py','releases/devbrain-0.7.2.zip','inputs/gate.json','inputs/guard-context.json','inputs/guard-receipt.json','inputs/toolbundle-freeze.json')
foreach($rel in $copyOld){Verify (RelativeFile $old.windows_root $rel) $oldFreeze.files[$rel]}
$extra=@(
 @('inputs/app-context.json',$appContextPath,$AppContextSha256),
 @('inputs/source-freeze.json',$app.freeze_manifest,$app.freeze_sha256),
 @('inputs/app-prepare-receipt.json',$app.setup_receipt,$app.setup_receipt_sha256),
 @('inputs/length-repair-preparation.json',(Join-Path $workspace 'evidence/080-extraction-length-repair-preparation-20261108.json'),'5eab009d4cdeccbf47f9f96da19d52c0aefbb9631c3314c3ec49d2ccfe677560'),
 @('inputs/length-repair-qr-peer-review.json',(Join-Path $workspace 'evidence/080-extraction-length-repair-qr-peer-review-20261108.json'),'d9dab7e45d3d17ffb908720c90b3ff9ab63cd3fe7c0fc45597a7fe5394ea1349'),
 @('inputs/length-repair-independent-peer-review.json',(Join-Path $workspace 'evidence/080-extraction-length-repair-peer-review-20261108.json'),'d5b4afc4a089e32640facaa83d3108f6158bdf3c07e26a91e7d510f82c1147b3'),
 @('inputs/previous-build-context-v6.json',$oldContextPath,'c0adf65d68f858b03b4c4b72979c7ab73a55d4e76a922034061ec59176acf3f4')
)
foreach($row in $extra){Verify $row[1] $row[2]}
PathProof $physicalBase
$runId='final-candidate-length080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$newRoot=Join-Path $physicalBase $runId
Require (-not(Test-Path -LiteralPath $newRoot)) 'Fresh physical root required'
NoReparse $newRoot;$null=[IO.Directory]::CreateDirectory($newRoot);PathProof $newRoot
$linuxRoot='/mnt/c/'+$newRoot.Substring(3).Replace('\','/')
$files=[ordered]@{}
function AddCopy([string]$Relative,[string]$SourcePath,[string]$Digest){
 $destination=RelativeFile $newRoot $Relative
 $parent=[IO.Path]::GetDirectoryName($destination)
 NoReparse $parent;$null=[IO.Directory]::CreateDirectory($parent);PathProof $parent
 CopyExact $SourcePath $destination $Digest;$files[$Relative]=$Digest
}
foreach($rel in $appKeys){AddCopy $rel (RelativeFile $app.bundle_root $rel) $source.files[$rel]}
foreach($rel in $copyOld){AddCopy $rel (RelativeFile $old.windows_root $rel) $oldFreeze.files[$rel]}
foreach($row in $extra){AddCopy $row[0] $row[1] $row[2]}
$artifactRoot=Join-Path $newRoot 'artifacts';$null=[IO.Directory]::CreateDirectory($artifactRoot);PathProof $artifactRoot
$plan=ReadMap $old.launch_plan
$plan.run_id=$runId
$plan.builder_argv=@($plan.builder_argv|ForEach-Object{$_.Replace($old.linux_root,$linuxRoot)})
$plan.bounded_linux_argv=@($plan.bounded_linux_argv|ForEach-Object{$_.Replace($old.linux_root,$linuxRoot)})
$plan.launch_waits_for=@('Root review and explicit serial handoff; no other Linux workload','Source202627 actual prepare passed; mechanical output remains unqualified and has no current-source UI/application gate claim')
$plan.previous_successful_build_plan_sha256=$old.launch_plan_sha256
Require ($plan.builder_argv.Count-eq6-and$plan.bounded_linux_argv.Count-eq10) 'Builder and timeout arrays must retain 6 and 10 literal arguments'
$planPath=Join-Path $newRoot 'launch-plan-v7.json';NewJson $planPath $plan;$files['launch-plan-v7.json']=HashFile $planPath
$freeze=[ordered]@{
 schema_version=1;scope='devbrain_frozen_candidate_build_envelope';run_id=$runId;status='prepared_not_run'
 source_snapshot=$app.run_id;app_file_count=198;source_freeze_sha256=$app.freeze_sha256;app_prepare_receipt_sha256=$app.setup_receipt_sha256
 toolbundle_freeze_sha256=$old.toolbundle_freeze_sha256;guard_receipt_sha256=$old.guard_receipt_sha256;runtime_gate_sha256=$old.runtime_gate_sha256;baseline_sha256=$old.baseline_sha256
 files=$files;qualified=$false;application_qualification=$false;source_final_qualification=$false;new_guard604_status='not_run';created_utc=[DateTime]::UtcNow.ToString('o')
}
$freezePath=Join-Path $newRoot 'build-input-freeze-v7.json';NewJson $freezePath $freeze
$original=[IO.File]::ReadAllText($old.launcher)
$launcherText=$original.Replace($old.windows_root,$newRoot).Replace('build-input-freeze-v6.json','build-input-freeze-v7.json').Replace('launcher-freeze-v6.json','launcher-freeze-v7.json').Replace('launch-plan-v6.json','launch-plan-v7.json')
Require ($launcherText-cne$original) 'Launcher root transformation missing'
Require ($launcherText.Replace($newRoot,$old.windows_root).Replace('build-input-freeze-v7.json','build-input-freeze-v6.json').Replace('launcher-freeze-v7.json','launcher-freeze-v6.json').Replace('launch-plan-v7.json','launch-plan-v6.json')-ceq$original) 'Unexpected observer semantic change'
$launcherPath=Join-Path $newRoot 'run-candidate-build-v7.ps1'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes($launcherText)
$stream=[IO.File]::Open($launcherPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
PathProof $launcherPath
$pt=$null;$pe=$null;$null=[Management.Automation.Language.Parser]::ParseFile($launcherPath,[ref]$pt,[ref]$pe)
Require ($pe.Count-eq0) 'New launcher parse failed'
CopyExact (Join-Path $old.windows_root 'builder-ast-proof.json') (Join-Path $newRoot 'builder-ast-proof.json') $old.builder_ast_proof_sha256
$launcherFreezePath=Join-Path $newRoot 'launcher-freeze-v7.json'
$lf=[ordered]@{
 schema_version=1;scope='devbrain_candidate_build_launcher_freeze';run_id=$runId
 files=[ordered]@{'run-candidate-build-v7.ps1'=(HashFile $launcherPath);'builder-ast-proof.json'=$old.builder_ast_proof_sha256;'build-input-freeze-v7.json'=(HashFile $freezePath)}
 status='prepared_not_run';windows_ast='pass';actual_json_builder_args=6;actual_json_timeout_args=10;root_review_required=$true;qualified=$false
 approved_v6_launcher_sha256=$old.launcher_sha256;allowed_delta_only=@('exact private root literal','three v6 metadata file names changed to v7')
}
NewJson $launcherFreezePath $lf
Artifacts $files $newRoot;Artifacts $lf.files $newRoot
Require (-not(Test-Path -LiteralPath (Join-Path $newRoot 'releases/candidates/0.8.0'))) 'Candidate must remain absent before build'
$context=[ordered]@{
 schema_version=1;scope='devbrain_candidate_build_preparation';status='prepared_not_run';run_id=$runId
 windows_root=$newRoot;linux_root=$linuxRoot;artifact_root=$artifactRoot;linux_artifact_root=($linuxRoot+'/artifacts')
 app_file_count=198;source_snapshot=$app.run_id;source_freeze_sha256=$app.freeze_sha256;app_prepare_receipt_sha256=$app.setup_receipt_sha256
 source_final_qualification=$false;toolbundle_freeze_sha256=$old.toolbundle_freeze_sha256;guard_receipt_sha256=$old.guard_receipt_sha256;guard_count=403
 runtime_gate_sha256=$old.runtime_gate_sha256;base_python=$old.base_python;baseline_sha256=$old.baseline_sha256
 input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);launch_plan=$planPath;launch_plan_sha256=(HashFile $planPath);windows_tools=$old.windows_tools
 controller_alias_used=$false;launch_permitted=$false;build_started=$false;qualified=$false;production_modified=$false;prior_candidates_modified=$false
 created_utc=[DateTime]::UtcNow.ToString('o');launcher=$launcherPath;launcher_sha256=(HashFile $launcherPath);launcher_freeze=$launcherFreezePath;launcher_freeze_sha256=(HashFile $launcherFreezePath)
 builder_ast_proof_sha256=$old.builder_ast_proof_sha256;launcher_arguments=@('-NoProfile','-File',$launcherPath,'-Execute')
 build_timeout_seconds=120;kill_grace_seconds=5;post_exit_observation_seconds=30;nonzero_requires_manual_pid_birth_cleanup_admission=$true;application_qualification=$false
 supersedes_context=$oldContextPath;supersedes_context_sha256=(HashFile $oldContextPath);previous_candidate_outputs=$old.output_sha256;prior_successful_build_observation_sha256=$old.observation_sha256
 actual_builder_argument_count=6;actual_timeout_argument_count=10;root_static_review_passed=$false;actual_windows_exit_code=$null;actual_windows_exec_session=$null;cleanup_complete=$null
 observer_implementation_unchanged_except_root_and_metadata_filenames=$true;observer_functions_from_approved_403_bundle=$true;latest_backup_helpers_not_used_by_mechanical_build=$true
 new_source_diff_only_reviewed_length_repair_files=$changed;helper_sha256=$old.helper_sha256
 length_repair_peer_review_sha256='d9dab7e45d3d17ffb908720c90b3ff9ab63cd3fe7c0fc45597a7fe5394ea1349'
 new_guard604_status='not_run';current_source_application_gates_status='not_run';expected_backend_cases=1557;expected_ux_cases=377
 candidate_directory=(Join-Path $newRoot 'releases/candidates/0.8.0');output_sha256=$null;observation=$null;observation_sha256=$null
}
$contextPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v7-20261108.json'
NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$newRoot;launcher=$launcherPath;launcher_sha256=(HashFile $launcherPath);freeze_sha256=(HashFile $freezePath);plan_sha256=(HashFile $planPath);app_files=198;input_files=$files.Count;new_launcher_parse_errors=$pe.Count;builder_args=$plan.builder_argv.Count;timeout_args=$plan.bounded_linux_argv.Count;status='prepared_not_run';linux_launched=$false}|ConvertTo-Json -Depth 5

