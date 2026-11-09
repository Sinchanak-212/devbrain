[CmdletBinding()]
param([switch]$Stage,[string]$CandidateContextSha256)
# Windows filesystem staging only. No process launches or application qualification.
if(-not $Stage){Write-Output 'NOT_RUN: -Stage requires the completed new candidate context SHA. No workloads are launched.';return}
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$workspace=(Get-Location).Path
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
if((Get-FileHash -LiteralPath (Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1') -Algorithm SHA256).Hash.ToLowerInvariant() -cne '6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical staging helper changed'}
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'),[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Stager AST error'}
$add=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Add-Type'},$false))
if($add.Count -ne 1){throw 'Unexpected canonical helper inventory'}
. ([scriptblock]::Create($add[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $node=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$false))
 if($node.Count -ne 1){throw 'Missing filesystem helper'}
 . ([scriptblock]::Create($node[0].Extent.Text))
}
function Physical([string]$Path){
 NoReparse $Path
 if(-not [QualificationStagePath080]::FinalPath($Path).Equals([IO.Path]::GetFullPath($Path),[StringComparison]::OrdinalIgnoreCase)){throw "Canonical mismatch: $Path"}
}
function ReadMap([string]$Path){ Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -DateKind String }
function NewJson([string]$Path,$Value){
 if([IO.Path]::GetFullPath($Path).StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){NoReparse $Path $workspace}else{NoReparse $Path}
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 40)+[Environment]::NewLine)
 $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
 if([IO.Path]::GetFullPath($Path).StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){SourceProof $Path}else{Physical $Path}
}
function CopyExact([string]$Source,[string]$Target,[string]$Expected,[bool]$WorkspaceSource=$false){
 if($WorkspaceSource){SourceProof $Source}else{Physical $Source}
 if((HashFile $Source) -cne $Expected){throw "Source hash mismatch: $Source"}
 NoReparse $Target
 [IO.File]::Copy($Source,$Target,$false)
 Physical $Target
 if((HashFile $Target) -cne $Expected -or (HashFile $Source) -cne $Expected){throw 'Copy hash mismatch'}
}

function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Verify([string]$Path,[string]$Expected){
 Require ($Expected -cmatch '^[0-9a-f]{64}$') "Invalid expected digest: $Path"
 if([IO.Path]::GetFullPath($Path).StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){SourceProof $Path}else{Physical $Path}
 Require ((HashFile $Path) -ceq $Expected) "Digest mismatch: $Path"
}
function RelativeFile([string]$Root,[string]$Name){
 Require (-not [IO.Path]::IsPathRooted($Name) -and $Name -notmatch '(^|[/\\])\.\.([/\\]|$)') 'Unsafe relative evidence path'
 $path=[IO.Path]::GetFullPath((Join-Path $Root $Name))
 Require ($path.StartsWith([IO.Path]::GetFullPath($Root).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'Evidence escaped root'
 return $path
}
function SameMap($Actual,$Expected){
 Require ($Actual.Count -eq $Expected.Count) 'Map inventory mismatch'
 foreach($name in $Expected.Keys){Require ($Actual.Contains($name) -and $Actual[$name] -ceq $Expected[$name]) "Map mismatch: $name"}
}
function ArtifactHashes($Map,[string]$Root){
 Require ($Map.Count -gt 0) 'Missing artifact digest map'
 foreach($name in $Map.Keys){Verify (RelativeFile $Root $name) $Map[$name]}
}
function GoodReceipt([string]$Path,[string]$Expected){
 Verify $Path $Expected
 $row=ReadMap $Path
 Require ($row.passed -eq $true -and $row.child_returncode -eq 0 -and $row.supervisor_returncode -eq 0) 'Receipt was not successful'
 Require ($row.controller_exit_verified -eq $true -and $row.supervisor_exit_verified -eq $true -and $row.cleanup_complete -eq $true -and $row.scope_empty_verified -eq $true) 'Exit or cleanup proof incomplete'
 Require ($row.forced_cleanup -eq $false -and $row.native_failure -eq $false -and @($row.errors).Count -eq 0 -and @($row.new_wsl_dumps).Count -eq 0) 'Receipt contains a failure'
 Require ($row.initial_boot_id -ceq $row.final_boot_id -and $row.cleanup_grace_seconds -ge 30 -and $row.scope_cleanup_grace_seconds -ge 30) 'Receipt observation incomplete'
 Require ($row.sleep_inhibition.restored -eq $true -and $row.power_monitor.changed -eq $false) 'Power or sleep restoration failed'
 ArtifactHashes $row.artifact_sha256 (Split-Path $Path -Parent)
 return $row
}

$priorPath=Join-Path $workspace 'evidence/080-guards-deploy-final-active-context-20261108.json'
SourceProof $priorPath
$prior=ReadMap $priorPath
$priorReceiptSHA='20ec03224dab3da992557d5c8f5a5ddf28dd2f9ed6b8f85e4a2dd5a80e960c82'
$priorFreezeSHA='d9d0145a00ea7cb27f79305ac5655938f80fb7571572f44317b94cbdca711bb9'
Require ($prior.run_id -ceq 'guards-deploy-final080-20261108T165834Z' -and $prior.status -ceq 'passed' -and $prior.actual_windows_exit_code -eq 0 -and $prior.actual_test_count -eq 594) 'Actual594 baseline is required'
$priorReceipt=GoodReceipt $prior.receipt $priorReceiptSHA
Verify $prior.final_report '0ecfdd12104145b7b44f0fe7fdc483edebd2a3efbac4f4e906b2ffe092229453'
Verify $prior.freeze_manifest $priorFreezeSHA
$oldFreeze=ReadMap $prior.freeze_manifest
Require ($oldFreeze.files.Count -eq 55 -and $oldFreeze.helper_files.Count -eq 38 -and $oldFreeze.test_modules.Count -eq 12) 'Prior inventory mismatch'
ArtifactHashes $oldFreeze.files $prior.windows_root
$observed=ReadMap (Join-Path $prior.artifact_root 'regression-source.json')
SameMap $observed.guard_sources.helper_sha256 $oldFreeze.helper_files

$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
SourceProof $appPath
$app=ReadMap $appPath
$sourceSHA='3dfc2738944f1a5fa3ab3087080f716c92d72f98cef819d7761d1118384f5fcf'
$prepareSHA='2fc2fbf9c20d97674c67847f1039b1a9091f1f5239b0aa26c1c3857bc65bb336'
Require ($app.run_id -ceq 'app080-20261108T183259Z' -and $app.status -ceq 'prepared_passed' -and $app.actual_windows_exit_code -eq 0) 'New app preparation is incomplete'
Require ($app.app_files -eq 198 -and $app.qualified_package_pin_count -eq 59 -and $app.pins_unchanged -eq $true -and $app.linux_source_matches_freeze -eq $true) 'New app preparation is not exact'
Require ($app.python_launcher -ceq '/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T183259Z/venv/bin/python' -and $app.source_root -ceq '/home/piotr/.cache/devbrain-runtime-080/postbios-app080-20261108T183259Z/project/devbrain') 'Unexpected qualified source/interpreter'
Verify $app.freeze_manifest $sourceSHA
Verify $app.setup_receipt $prepareSHA
$appFreeze=ReadMap $app.freeze_manifest
Require ($appFreeze.files.Count -eq 209 -and $appFreeze.app_files -eq 198) 'Source inventory mismatch'
ArtifactHashes $appFreeze.files $app.bundle_root
$appHashes=@{}
foreach($relative in $appFreeze.files.Keys){if($relative.StartsWith('devbrain/')){$appHashes[$relative.Substring(9)]=$appFreeze.files[$relative]}}
Require ($appHashes.Count -eq 198) 'Application subset mismatch'
$prep=ReadMap $app.setup_receipt
Require ($prep.passed -eq $true -and $prep.phase -ceq 'prepare' -and $prep.proxy_exit_code -eq 0 -and $prep.controller_exit_verified -eq $true -and $prep.cleanup_complete -eq $true -and $prep.forced_cleanup -eq $false) 'Preparation actual exit/cleanup failed'
Require ($prep.cleanup_grace_seconds -ge 30 -and $prep.initial_boot_id -ceq $prep.final_boot_id -and @($prep.errors).Count -eq 0 -and @($prep.new_kernel_fatals).Count -eq 0 -and @($prep.new_wsl_dumps).Count -eq 0 -and $prep.sleep_inhibition.restored -eq $true -and $prep.runtime_verified_after_cleanup -eq $true) 'Preparation observation incomplete'

$budgetPrepPath=Join-Path $workspace 'evidence/080-queue-extraction-budget-preparation-20261108.json'
$budgetPeerPath=Join-Path $workspace 'evidence/080-queue-extraction-budget-peer-review-20261108.json'
$appPeerPath=Join-Path $workspace 'evidence/080-extraction-budget-qr-peer-review-20261108.json'
Verify $budgetPrepPath '16f9316cbc38132125282a58547618f2cd13c238c99dfa4940223141d92caf8f'
Verify $budgetPeerPath 'f24720660d26800872753a67026c0a17c83b739401b1a406a4a09b950980d7ab'
Verify $appPeerPath '329e3853f782401a57a864dd8b6178e1842a0a805efd27b3997dced3448997c1'
$changed=@{
 'replay-failed-queue-080.py'='e8513a36aa5d7443db76935f4a6a01c62b547a7c92341ac5b05d9a3710a70d1b'
 'retry-production-queue-080.py'='f24c3cf721dbdbcc9b810f09c4e688c04a5682ea502853b084cdba593429d90e'
 'test_queue_replay080_guards.py'='0423ae6e131ddfa40f6adf1d7e7dd48fd7ad15536bd4d9b55563bfa5332075ab'
 'test_production_queue080_guards.py'='cede3a01a8d3e6f982142ceda64aff3313d3eaaf2a0bd5c2b86b1855b315ad9a'
}
SameMap (ReadMap $budgetPeerPath).files_sha256 $changed
$helpers=@{}
foreach($name in $oldFreeze.helper_files.Keys){
 Require ([IO.Path]::GetFileName($name) -ceq $name) 'Invalid helper name'
 if($changed.ContainsKey($name)){
  Verify (Join-Path $workspace ('release-tools/'+$name)) $changed[$name]
  $helpers[$name]=$changed[$name]
 }else{$helpers[$name]=$oldFreeze.helper_files[$name]}
}
Require ($helpers.Count -eq 38 -and $changed.Count -eq 4) 'Helper delta inventory mismatch'

$candidatePath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v5-20261108.json'
Verify $candidatePath $CandidateContextSha256
$candidate=ReadMap $candidatePath
Require ($candidate.status -ceq 'candidate_built_observed_not_qualified' -and $candidate.actual_windows_exit_code -eq 0 -and $candidate.cleanup_complete -eq $true -and $candidate.root_output_review_passed -eq $true) 'Candidate build is not completed and reviewed'
Require ($candidate.source_snapshot -ceq $app.run_id -and $candidate.source_freeze_sha256 -ceq $sourceSHA -and $candidate.app_prepare_receipt_sha256 -ceq $prepareSHA) 'Candidate source preparation differs'
Verify $candidate.observation $candidate.observation_sha256
$build=ReadMap $candidate.observation
Require ($build.passed -eq $true -and $build.actual_exit_verified -eq $true -and $build.actual_proxy_exit -eq 0 -and $build.cleanup_complete -eq $true -and $build.stdio_complete -eq $true -and $build.post_exit_observed_seconds -ge 30) 'Build actual exit/observation incomplete'
Require ($build.run_id -ceq $candidate.run_id -and $build.initial_boot_id -ceq $build.final_boot_id -and @($build.errors).Count -eq 0 -and $build.sleep_inhibition.restored -eq $true) 'Build native/boot/power observation failed'
Require ($build.power_start.active_guid -ceq '381b4222-f694-41f0-9685-ff5bb260df2e' -and $build.power_end.active_guid -ceq $build.power_start.active_guid -and $build.power_end.settings_sha256 -ceq $build.power_start.settings_sha256 -and $build.qualified -eq $false) 'Build power or qualification boundary differs'
SameMap $build.output_sha256 $candidate.output_sha256
Require ($candidate.output_sha256.Count -eq 4) 'Candidate four-file inventory mismatch'
ArtifactHashes $candidate.output_sha256 $candidate.windows_root
$candidateNames=@('devbrain-update-0.8.0.py','devbrain-0.8.0.zip','devbrain-update-0.8.0-manifest.json','devbrain-0.8.0.zip.sha256')
foreach($name in $candidateNames){Require ($candidate.output_sha256.Contains('releases/candidates/0.8.0/'+$name)) 'Missing candidate output'}
$candidateManifest=ReadMap (Join-Path $candidate.candidate_directory 'devbrain-update-0.8.0-manifest.json')
SameMap $candidateManifest.source_sha256 $appHashes
Require ($candidateManifest.source_files -eq 198 -and $candidateManifest.qualified -eq $false) 'Candidate manifest is not the new unqualified198 source'
Require ($candidateManifest.updater_sha256 -ceq $candidate.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py'] -and $candidateManifest.zip_sha256 -ceq $candidate.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip']) 'Candidate manifest output mismatch'

# Only after all actual prerequisites are verified do we create a fresh root.
$contextPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
Require (-not (Test-Path -LiteralPath $contextPath)) 'Do not overwrite a prior context'
$runId='guards-queue-budget080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path $physicalBase $runId
Require (-not (Test-Path -LiteralPath $runRoot)) 'Fresh guard root required'
NoReparse $runRoot
foreach($sub in @('tools','artifacts','candidate','inputs')){$null=[IO.Directory]::CreateDirectory((Join-Path $runRoot $sub));Physical (Join-Path $runRoot $sub)}
$files=@{}
function CopyInput([string]$Source,[string]$Relative,[string]$Expected){
 $target=RelativeFile $runRoot $Relative
 CopyExact $Source $target $Expected ([IO.Path]::GetFullPath($Source).StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase))
 $files[$Relative]=$Expected
}
foreach($name in $helpers.Keys){
 $source=if($changed.ContainsKey($name)){Join-Path $workspace ('release-tools/'+$name)}else{Join-Path $prior.windows_tools $name}
 CopyInput $source ('tools/'+$name) $helpers[$name]
}
CopyInput (Join-Path $prior.artifact_root 'gate.json') 'artifacts/gate.json' $prior.gate_sha256
foreach($name in $candidateNames){CopyInput (Join-Path $candidate.candidate_directory $name) ('candidate/'+$name) $candidate.output_sha256['releases/candidates/0.8.0/'+$name]}
$inputs=@(
 @($appPath,'app-context.json',(HashFile $appPath)),
 @($app.freeze_manifest,'app-source-freeze.json',$sourceSHA),
 @($app.setup_receipt,'app-prepare-receipt.json',$prepareSHA),
 @($candidatePath,'candidate-build-context.json',$CandidateContextSha256),
 @($candidate.observation,'candidate-build-observation.json',$candidate.observation_sha256),
 @($prior.receipt,'previous-594-receipt.json',$priorReceiptSHA),
 @($prior.freeze_manifest,'previous-594-freeze.json',$priorFreezeSHA),
 @($prior.final_report,'previous-594-final-report.json',(HashFile $prior.final_report)),
 @($budgetPrepPath,'queue-budget-preparation.json',(HashFile $budgetPrepPath)),
 @($budgetPeerPath,'queue-budget-peer-review.json',(HashFile $budgetPeerPath)),
 @($appPeerPath,'app-budget-peer-review.json',(HashFile $appPeerPath))
)
foreach($entry in $inputs){CopyInput $entry[0] ('inputs/'+$entry[1]) $entry[2]}
$linuxRoot='/mnt/c/'+$runRoot.Substring(3).Replace('\','/')
$artifactRoot=Join-Path $runRoot 'artifacts'
$oldSpec=ReadMap $prior.specification
$spec=ReadMap $prior.specification
$spec.run_id=$runId
$spec.python_launcher=$app.python_launcher
for($i=0;$i -lt $spec.argv.Count;$i++){
 $value=[string]$spec.argv[$i]
 if($value -ceq $prior.run_id){$value=$runId}
 elseif($value -ceq $prior.source_root){$value=$app.source_root}
 elseif($value.StartsWith($prior.linux_root+'/')){$value=$linuxRoot+$value.Substring($prior.linux_root.Length)}
 $spec.argv[$i]=$value
}
Require ($spec.argv.Count -eq 13 -and $spec.argv[0] -ceq '--execute' -and $spec.argv[2] -ceq 'guards' -and $spec.argv[8] -ceq $app.source_root -and $spec.argv[12] -ceq ($linuxRoot+'/candidate/devbrain-update-0.8.0.py')) 'Guard argv transform differs'
SameMap $spec.env $oldSpec.env
$specPath=Join-Path $artifactRoot 'spec.json'
NewJson $specPath $spec
$files['artifacts/spec.json']=HashFile $specPath
$inputPath=Join-Path $runRoot 'guard-input-manifest.json'
$inventory=@{schema_version=1;run_id=$runId;helper_files=$helpers;test_modules=$oldFreeze.test_modules;helper_count=38;guard_module_count=12;expected_cases=604;actual_collection_authoritative=$true;changed_helpers=$changed;new_app_required=$true;source_freeze_sha256=$sourceSHA;source_final=$false;previous_guard_receipt_sha256=$priorReceiptSHA;application_qualified=$false;release_qualified=$false}
NewJson $inputPath $inventory
$files['guard-input-manifest.json']=HashFile $inputPath
Require ($files.Count -eq 56) 'New frozen input inventory mismatch'
ArtifactHashes $files $runRoot
$actualFiles=@(Get-ChildItem -LiteralPath $runRoot -Recurse -Force -File)
Require ($actualFiles.Count -eq $files.Count) 'Unexpected staged files'
$freezePath=Join-Path $runRoot 'toolbundle-freeze.json'
$freeze=@{schema_version=1;run_id=$runId;status='frozen_not_run';helper_files=$helpers;test_modules=$oldFreeze.test_modules;helper_count=38;guard_module_count=12;expected_cases=604;actual_collection_authoritative=$true;files=$files;total_files=$files.Count;changed_helpers=$changed;source_freeze_sha256=$sourceSHA;source_final=$false;candidate_updater_sha256=$candidateManifest.updater_sha256;previous_guard_receipt_sha256=$priorReceiptSHA;previous_guard_freeze_sha256=$priorFreezeSHA;canonical_path_and_hash_checks_passed=$true;application_qualified=$false;release_qualified=$false}
NewJson $freezePath $freeze
$context=@{
 schema_version=1;status='prepared_not_run';run_id=$runId;phase='guards';windows_root=$runRoot;linux_root=$linuxRoot
 windows_tools=(Join-Path $runRoot 'tools');linux_tools=($linuxRoot+'/tools');artifact_root=$artifactRoot;linux_artifact_root=($linuxRoot+'/artifacts')
 controller=($linuxRoot+'/tools/run-regressions-080.py');base_python=$prior.base_python;python_launcher=$app.python_launcher;source_root=$app.source_root
 specification=$specPath;specification_sha256=(HashFile $specPath);freeze_manifest=$freezePath;freeze_sha256=(HashFile $freezePath);toolbundle_freeze=$freezePath;toolbundle_freeze_sha256=(HashFile $freezePath)
 input_manifest=$inputPath;input_manifest_sha256=(HashFile $inputPath);frozen_input_count=$files.Count;helper_file_count=38;guard_module_count=12;helper_sha256=$helpers;reviewed_helper_sha256=$helpers;changed_helpers=$changed
 expected_test_count=604;actual_collection_authoritative=$true;timeout_seconds=600;cleanup_grace_seconds=30;private_root='/home/piotr/.cache/devbrain-regressions-080';wsl_crash_directory=$prior.wsl_crash_directory
 app_run_id=$app.run_id;app_snapshot=$app.run_id;app_freeze=$app.freeze_manifest;app_freeze_sha256=$sourceSHA;app_file_count=198;app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$prepareSHA
 source_final=$false;source_is_current_candidate=$true;source_finalization_basis='Frozen prepared new source; current application acceptance and release qualification are pending'
 candidate_build_run_id=$candidate.run_id;candidate_build_context=$candidatePath;candidate_build_context_sha256=$CandidateContextSha256;candidate_build_observation_sha256=$candidate.observation_sha256
 updater_sha256=$candidateManifest.updater_sha256;candidate_zip_sha256=$candidateManifest.zip_sha256;candidate_manifest_sha256=$candidate.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json']
 gate_sha256=$prior.gate_sha256;guard_receipt=$prior.receipt;guard_receipt_sha256=$priorReceiptSHA;previous_guard_run=$prior.run_id;previous_guard_receipt_sha256=$priorReceiptSHA;prior_guard_used_only_for_bootstrap_and_unchanged_tool_evidence=$true
 reviewed_preparation_sha256=(HashFile $budgetPrepPath);peer_review_sha256=(HashFile $budgetPeerPath);app_peer_review_sha256=(HashFile $appPeerPath)
 historical_application_pass_reused=$false;prior_runtime_fixtures_source_run_id='app080-20261108T160614Z';prior_runtime_fixtures_guard_receipt_sha256=$priorReceiptSHA;prior_runtime_fixtures_application_qualification=$false
 linux_workload_started=$false;launch_permitted=$false;requires_root_serial_handoff=$true;production_execution_permitted=$false;application_qualified=$false;release_qualified=$false;receipt_sha256=$null;actual_windows_exit_code=$null;cleanup_complete=$false
}
NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$runId;freeze_sha256=(HashFile $freezePath);specification_sha256=(HashFile $specPath);inputs=$files.Count;helpers=38;modules=12;expected_cases=604;linux_started=$false;application_qualified=$false}|ConvertTo-Json -Depth 5
