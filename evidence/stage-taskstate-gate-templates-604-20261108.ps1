#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for task-state gate templates; this script never launches a process.';return}
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


$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
Verify $appPath '660a3bc9078a3a3caa78584e2c9364ea7b485148b6e4e1a7d1d88257d24de4d9'
$app=ReadMap $appPath
Require ($app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.run_id-ceq'app080-20261108T192100Z') 'New app not prepared'
Verify $app.freeze_manifest $app.freeze_sha256;Verify $app.setup_receipt $app.setup_receipt_sha256
$src=ReadMap $app.freeze_manifest;$appKeys=@($src.files.Keys|Where-Object{$_-clike'devbrain/*'})
Require ($appKeys.Count-eq198) 'Wrong source inventory';foreach($rel in $appKeys){Verify (RelativeFile $app.bundle_root $rel) $src.files[$rel]}
$buildPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v6-20261108.json'
Verify $buildPath 'c0adf65d68f858b03b4c4b72979c7ab73a55d4e76a922034061ec59176acf3f4';$build=ReadMap $buildPath
Require ($build.actual_windows_exit_code-eq0-and$build.cleanup_complete-eq$true-and$build.source_freeze_sha256-ceq$app.freeze_sha256) 'V6 actual build missing'
Verify $build.observation $build.observation_sha256;Artifacts $build.output_sha256 $build.windows_root
$oldGuardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-context-guards-queue-budget080-20261108T184628Z.json'
Verify $oldGuardPath 'c994134f6dcab8b2edcf01413c18d8c3248994ad3a2a647ffe0052f43c31406c';$oldGuard=ReadMap $oldGuardPath
Require ($oldGuard.helper_sha256.Count-eq38) 'Expected frozen helper map missing'
foreach($name in $oldGuard.helper_sha256.Keys){Verify (Join-Path $oldGuard.windows_tools $name) $oldGuard.helper_sha256[$name]}
$runtimePath=Join-Path $oldGuard.artifact_root 'gate.json';Verify $runtimePath $oldGuard.gate_sha256;$runtime=(ReadMap $runtimePath).runtime
$fixturePath=Join-Path $workspace 'evidence/080-controlled-fixtures-deploy-final-20261108.json';$fixtureSHA='d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c';Verify $fixturePath $fixtureSHA
$oldMasterPath=Join-Path $workspace 'evidence/080-finalsource-gate-templates-594-deploy-20261108.json';Verify $oldMasterPath '610110f2c035789cc1ef6bbc47c0046d689dc161ee66362798563cce04c57ab9';$oldMaster=ReadMap $oldMasterPath
$originals=[ordered]@{}
foreach($name in @('native','copilot','ollama20','frontend')){$path=Join-Path $oldMaster.template_root "$name.template.json";Verify $path $oldMaster.files["$name.template.json"];$originals[$name]=@{path=$path;sha=$oldMaster.files["$name.template.json"];value=(ReadMap $path)}}
$smokePath=Join-Path $workspace 'evidence/080-updater-smoke-assistantpref-38-proposal-v3-20261108.json';Verify $smokePath '12fd0e1ba6f3b59c6b99e2a91efc19a6ab9fe1abb778d2e6a07160482ef75a71';$smoke=ReadMap $smokePath;Verify $smoke.specification $smoke.specification_sha256
$soakPath=Join-Path $workspace 'evidence/080-soak-assistantpref-38-proposal-v3-20261108.json';Verify $soakPath 'a6fb92ce04377a244102da3b2a94fa9336c306dde168f907fdca3ac345e161bb';$soak=ReadMap $soakPath;Verify $soak.specification $soak.specification_sha256
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ');$root=Join-Path $physicalBase ("taskstate-gate-templates080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8))
Require (-not(Test-Path -LiteralPath $root)) 'Fresh template root exists';NoReparse $root;[void][IO.Directory]::CreateDirectory($root);PathProof $root
$inputs=Join-Path $root 'inputs';[void][IO.Directory]::CreateDirectory($inputs);$files=[ordered]@{}
$shared=[ordered]@{
 'app-context.json'=@{path=$appPath;sha=(HashFile $appPath)};'source-freeze.json'=@{path=$app.freeze_manifest;sha=$app.freeze_sha256};'prepare-receipt.json'=@{path=$app.setup_receipt;sha=$app.setup_receipt_sha256}
 'candidate-v6-context.json'=@{path=$buildPath;sha=(HashFile $buildPath)};'candidate-v6-observation.json'=@{path=$build.observation;sha=$build.observation_sha256}
 'previous604-context.json'=@{path=$oldGuardPath;sha=(HashFile $oldGuardPath)};'runtime-gate.json'=@{path=$runtimePath;sha=$oldGuard.gate_sha256};'runtime-five-fixtures.json'=@{path=$fixturePath;sha=$fixtureSHA}
 'old-template-master.json'=@{path=$oldMasterPath;sha=(HashFile $oldMasterPath)};'old-smoke-proposal.json'=@{path=$smokePath;sha=(HashFile $smokePath)};'old-smoke-spec.json'=@{path=$smoke.specification;sha=$smoke.specification_sha256}
 'old-soak-proposal.json'=@{path=$soakPath;sha=(HashFile $soakPath)};'old-soak-spec.json'=@{path=$soak.specification;sha=$soak.specification_sha256};'template-stager.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
}
foreach($name in $originals.Keys){$shared["old-$name-template.json"]=$originals[$name]}
foreach($name in $shared.Keys){$s=$shared[$name];CopyExact $s.path (Join-Path $inputs $name) $s.sha;$files["inputs/$name"]=$s.sha}
$templates=[ordered]@{};$candidate=[ordered]@{context=$buildPath;context_sha256=(HashFile $buildPath);directory=$build.candidate_directory;observation=$build.observation;observation_sha256=$build.observation_sha256;output_sha256=$build.output_sha256;qualified=$false;actual_windows_exit_code=0}
foreach($name in @('native','copilot','ollama20','frontend','upgrade_smoke','soak')){
 if($originals.Contains($name)){$old=$originals[$name].value;$spec=$old.specification_template;$basename=$old.controller_basename;$acceptance=$old.acceptance}
 elseif($name-ceq'upgrade_smoke'){$old=$smoke;$spec=ReadMap $smoke.specification;$basename='test_devbrain_update080_smoke.py';$acceptance=$smoke.acceptance}
 else{$old=$soak;$spec=ReadMap $soak.specification;$basename='soak-workload-080.py';$acceptance=$soak.acceptance}
 $specText=($spec|ConvertTo-Json -Depth 40).Replace($old.source_root,$app.source_root).Replace($old.python_launcher,$app.python_launcher)
 if($name-cin@('upgrade_smoke','soak')){$specText=$specText.Replace($old.linux_root,'<LINUX_RUN_ROOT>').Replace($old.run_id,'<RUN_ID>')}
 $spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String
 if($name-ceq'upgrade_smoke'){
  for($i=0;$i-lt$spec.argv.Count;$i++){
   if($spec.argv[$i]-ceq'--release-dir'){$spec.argv[$i+1]=$build.linux_root+'/releases/candidates/0.8.0'}
   if($spec.argv[$i]-ceq'--baseline-zip'){$spec.argv[$i+1]=$build.linux_root+'/releases/devbrain-0.7.2.zip'}
  }
  $acceptance.candidate_updater_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py'];$acceptance.candidate_zip_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip'];$acceptance.candidate_manifest_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json'];$acceptance.candidate_source_freeze_sha256=$app.freeze_sha256
 }
 $t=[ordered]@{schema_version=1;scope='devbrain_taskstate_gate_template';name=$name;status='prepared_not_run_pending_current604_fullbackend_and_UI';launch_permitted=$false;qualified=$false;linux_workload_started=$false;is_frozen_execution_spec=$false;materialization_required=$true;run_id=$null;windows_artifact_root=$null;linux_artifact_root=$null
  controller_basename=$basename;controller_sha256=$oldGuard.helper_sha256[$basename];controller_path=$null;windows_tools=$null;linux_tools=$null;reviewed_helper_sha256=$oldGuard.helper_sha256;helper_count=38
  source_snapshot=$app.run_id;source_root=$app.source_root;python_launcher=$app.python_launcher;source_freeze=$app.freeze_manifest;source_freeze_sha256=$app.freeze_sha256;source_file_count=198;source_finalized=$false
  app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$app.setup_receipt_sha256;app_prepare_actual_windows_exit_code=0;qualified_package_pin_count=59;base_python=$oldGuard.base_python;runtime=$runtime;runtime_gate_sha256=$oldGuard.gate_sha256
  current_guard_binding=@{passed=$false;context=$null;context_sha256=$null;receipt=$null;receipt_sha256=$null;actual_count=$null;expected_count=604;module_count=12;required_source_freeze_sha256=$app.freeze_sha256;required_helper_map=$oldGuard.helper_sha256}
  current_full_backend_binding=@{passed=$false;context=$null;receipt_sha256=$null;attestation=$null;attestation_sha256=$null;expected_count=1537;must_use_original_qualified_source=$true;canonical_output='ACTUAL_NEW_BACKEND_ARTIFACT_ROOT/final-full-suite.json'}
  current_ux_binding=@{passed=$false;context=$null;receipt_sha256=$null;expected_cases=377;modules=28};current_ui_binding=@{passed=$false;context=$null;receipt_sha256=$null;required_tasks=5;required_geometries=3}
  candidate_binding=$candidate;runtime_fixture_binding=@{path=$fixturePath;sha256=$fixtureSHA;runtime_only=$true;application_qualification=$false;requires_same_supervision_bytes=$true}
  timeout_seconds=$old.timeout_seconds;cleanup_grace_seconds=30;specification_template=$spec;acceptance=$acceptance;original_runtime_result_reused=$false;production_modified=$false;credentials_read=$false;created_utc=[DateTimeOffset]::UtcNow.ToString('o')
 }
 $path=Join-Path $root "$name.template.json";NewJson $path $t;$files["$name.template.json"]=HashFile $path;$templates[$name]=@{path=$path;sha256=(HashFile $path)}
}
$freeze=Join-Path $root 'template-input-freeze.json';NewJson $freeze @{schema_version=1;scope='devbrain_taskstate_gate_template_inputs';files=$files;helper_sha256=$oldGuard.helper_sha256;source_freeze_sha256=$app.freeze_sha256}
$master=[ordered]@{schema_version=1;scope='devbrain_taskstate_gate_templates';status='prepared_not_run_pending_current604_and_all_application_gates';launch_permitted=$false;linux_workload_started=$false;qualified=$false;source_finalized=$false;source_snapshot=$app.run_id;source_root=$app.source_root;python_launcher=$app.python_launcher;source_freeze=$app.freeze_manifest;source_freeze_sha256=$app.freeze_sha256;app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$app.setup_receipt_sha256;app_file_count=198;expected_backend_cases=1537;expected_ux_cases=377;ux_modules=28;windows_root=$root;input_freeze=$freeze;input_freeze_sha256=(HashFile $freeze);input_file_count=$files.Count;templates=$templates;helper_sha256=$oldGuard.helper_sha256;helper_count=38;current_guard_receipt_sha256=$null;current_guard_passed=$false;expected_guard_cases=604;guard_modules=12;candidate_binding=$candidate;runtime_gate_sha256=$oldGuard.gate_sha256;runtime=$runtime;runtime_only_fixtures=@{path=$fixturePath;sha256=$fixtureSHA;application_qualification=$false};full_suite_attestation_sha256=$null;current_UI_passed=$false;old_results_pooled=$false;credentials_read=$false;production_modified=$false}
Artifacts $files $root
$masterPath=Join-Path $workspace 'evidence/080-taskstate-remaining-gate-templates-604-20261108.json';NewJson $masterPath $master
@{master=$masterPath;sha256=(HashFile $masterPath);root=$root;freeze_sha256=(HashFile $freeze);files=$files.Count;helpers=38;source_snapshot=$app.run_id;launch_permitted=$false}|ConvertTo-Json
