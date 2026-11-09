#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256,[string]$AppContextSha256,[int]$GuardExecSessionId)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for isolated six-job replay; this script never launches a process.';return}
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


$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
$oldPath=Join-Path $workspace 'evidence/080-queue-copy-budget-active-context-20261108.json'
$diagnosisPath=Join-Path $workspace 'evidence/080-queue-copy-budget-failed-diagnosis-20261108.json'
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
$guardSHA=$GuardContextSha256
$receiptSHA=$GuardReceiptSha256
$oldSHA='e989ae82392cfe2f7ade886af220abb541347e31e45f2f23cde150e37b3339ed'
$diagnosisSHA='feefc1379e5cfad6325d981a168fe1e0d090c35e92a2a8dde2ccc7de50059d69'
Verify $guardPath $guardSHA;Verify $oldPath $oldSHA;Verify $diagnosisPath $diagnosisSHA
Verify $appPath $AppContextSha256
$g=ReadMap $guardPath;$old=ReadMap $oldPath;$diagnosis=ReadMap $diagnosisPath;$app=ReadMap $appPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$GuardExecSessionId-gt0-and$g.actual_windows_exec_session-eq$GuardExecSessionId-and$g.run_id-cmatch'^guards-task-state080-[0-9]{8}T[0-9]{6}Z$'-and$g.actual_test_count-eq604-and$g.cleanup_complete-eq$true) 'Actual604 and cleanup required'
Verify $g.receipt $receiptSHA;Verify $g.final_report $GuardFinalReportSha256
$r=ReadMap $g.receipt
Require ($r.passed-eq$true-and$r.run_id-ceq$g.run_id-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and@($r.errors).Count-eq0-and$r.sleep_inhibition.restored-eq$true) 'Actual guard receipt incomplete'
Artifacts $r.artifact_sha256 $g.artifact_root
Verify $g.freeze_manifest $g.freeze_sha256;$freeze=ReadMap $g.freeze_manifest
Require ($freeze.files.Count-eq56-and$freeze.helper_files.Count-eq38-and$freeze.test_modules.Count-eq12) 'Wrong604 inventory'
Artifacts $freeze.files $g.windows_root;SameMap $freeze.helper_files $g.helper_sha256;SameMap $freeze.helper_files $g.reviewed_helper_sha256
Require ($diagnosis.run_id-ceq$old.run_id-and$diagnosis.root_actual_exit-eq1-and$diagnosis.root_actual_exec_session-eq9100-and$diagnosis.safe_next_workload-eq$true-and$diagnosis.scope_empty_verified-eq$true-and$diagnosis.scope_quiet_seconds-ge30-and$diagnosis.outer_post_exit_seconds-ge30-and$diagnosis.functional_passed-eq$false-and$diagnosis.raw_outputs_or_contexts_modified-eq$false) 'Old failed replay cleanup admission incomplete'
Require ($app.run_id-ceq'app080-20261108T192100Z'-and$app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.freeze_sha256-ceq$g.app_freeze_sha256-and$app.python_launcher-ceq$g.python_launcher-and$app.source_root-ceq$g.source_root) 'New app preparation mismatch'
Verify $app.freeze_manifest '0f46007731a08309644cc46a7bb28a3d57b6d6693e7f470593d87e5cfa773613'
Verify $app.setup_receipt 'c9034ec96e53b320e2ec6fc29a7f1bcb492a35b9c8fc8353b6047891c2649f63'
$af=ReadMap $app.freeze_manifest;Require ($af.app_files-eq198-and$af.files.Count-eq209) 'New source inventory differs';Artifacts $af.files $app.bundle_root
Verify $g.candidate_build_context $g.candidate_build_context_sha256
$candidate=ReadMap $g.candidate_build_context
Require ($candidate.status-ceq'candidate_built_observed_not_qualified'-and$candidate.actual_windows_exit_code-eq0-and$candidate.cleanup_complete-eq$true-and$candidate.source_freeze_sha256-ceq$app.freeze_sha256) 'New candidate build mismatch'
Verify $candidate.observation $candidate.observation_sha256
$fixturePath=Join-Path $workspace 'evidence/080-controlled-fixtures-deploy-final-20261108.json'
$fixtureSHA='d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c'
Verify $fixturePath $fixtureSHA
$fixture=ReadMap $fixturePath
Require ($fixture.passed-eq$true-and$fixture.status-ceq'passed_runtime_supervision_only'-and$fixture.application_qualification-eq$false) 'Runtime-only proof boundary differs'
Verify $old.specification $old.specification_sha256
$spec=ReadMap $old.specification
Require ($spec.argv.Count-eq15-and$spec.argv[0]-ceq'--execute'-and$spec.argv[9]-ceq'--backup'-and$spec.argv[10]-ceq'/home/piotr/.local/state/devbrain-updates/20261107T093838Z-bbfafb96/database.devbrain.json.gz'-and$old.acceptance.backup_sha256-ceq'698591d33252a1f0e802a01fac78feb90f56ef37fc0c5f717ed26667f635ac70'-and$old.timeout_seconds-eq1800) 'Original exact backup/controller argument contract differs'
Require ($spec.argv[11]-ceq'--data-dir'-and$spec.argv[13]-ceq'--arcade-dist'-and$old.acceptance.expected_jobs-eq6-and$old.acceptance.expected_kinds.extract-eq3-and$old.acceptance.expected_kinds.import-eq3) 'Original whole-six replay contract differs'
$contextPath=Join-Path $workspace 'evidence/080-queue-copy-task-state-active-context-20261108.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Never overwrite prior trial'
PathProof $physicalBase
$runId='queue-copy-taskstate080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $runId
Require (-not(Test-Path -LiteralPath $root)) 'Fresh root required';NoReparse $root
foreach($sub in @('artifacts','inputs')){$null=[IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
$art=Join-Path $root 'artifacts';$dataDir='/home/piotr/.cache/devbrain-qualification-080/'+$runId+'/queue-copy'
$files=[ordered]@{}
function CopyInput([string]$Source,[string]$Relative,[string]$Digest){CopyExact $Source (RelativeFile $root $Relative) $Digest;$files[$Relative]=$Digest}
CopyInput (Join-Path $g.artifact_root 'gate.json') 'artifacts/gate.json' $g.gate_sha256
$inputs=@(
 @($guardPath,'guard-context.json',$guardSHA),@($g.receipt,'guard-receipt.json',$receiptSHA),
 @($g.final_report,'guard-final-report.json',$g.final_report_sha256),@($g.freeze_manifest,'toolbundle-freeze.json',$g.freeze_sha256),
 @($appPath,'app-context.json',(HashFile $appPath)),@($app.freeze_manifest,'source-freeze.json',$app.freeze_sha256),
 @($app.setup_receipt,'app-prepare-receipt.json',$app.setup_receipt_sha256),@($oldPath,'historical-failed-context.json',$oldSHA),
 @($old.specification,'historical-failed-spec.json',$old.specification_sha256),@($diagnosisPath,'historical-failed-cleanup-admission.json',$diagnosisSHA),
 @($fixturePath,'runtime-only-fixtures594.json',$fixtureSHA),@($g.candidate_build_context,'candidate-v6-context.json',$g.candidate_build_context_sha256),
 @($candidate.observation,'candidate-v6-observation.json',$candidate.observation_sha256)
)
foreach($row in $inputs){CopyInput $row[0] ('inputs/'+$row[1]) $row[2]}
$spec.run_id=$runId;$spec.python_launcher=$app.python_launcher
$spec.argv[2]=$runId;$spec.argv[4]=$linuxRoot+'/artifacts';$spec.argv[6]=$linuxRoot+'/artifacts/gate.json';$spec.argv[8]=$app.source_root;$spec.argv[12]=$dataDir
$oldSpec=ReadMap $old.specification
for($i=0;$i-lt15;$i++){if($i-notin@(2,4,6,8,12)){Require ($spec.argv[$i]-ceq$oldSpec.argv[$i]) 'Unexpected argument mutation'}}
SameMap $spec.env $oldSpec.env
Require (($spec.required_artifacts-join'|')-ceq($oldSpec.required_artifacts-join'|')) 'Required artifacts changed'
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
Artifacts $files $root
$inputFreeze=Join-Path $root 'prepared-input-freeze.json'
NewJson $inputFreeze ([ordered]@{schema_version=1;run_id=$runId;status='prepared_not_run';files=$files;helper_sha256=$freeze.helper_files;source_freeze_sha256=$app.freeze_sha256;guard_receipt_sha256=$receiptSHA;purpose='isolated_targeted_regression_of_same_six_historical_jobs';source_final=$false;application_qualification=$false;production_retry_permitted=$false})
$gate=ReadMap (Join-Path $art 'gate.json')
$launch=[ordered]@{ArtifactRoot=$art;LinuxArtifactRoot=($linuxRoot+'/artifacts');PythonExecutable=$g.base_python;Controller=($g.linux_tools+'/replay-failed-queue-080.py');ControllerArgumentsFile=$specPath;RunId=$runId;TimeoutSeconds=1800;CleanupGraceSeconds=30;WslCrashDirectory=$g.wsl_crash_directory}
$c=[ordered]@{
 schema_version=1;scope='devbrain_targeted_queue_copy_regression_preparation';phase='queue-copy';name='queue_copy';status='prepared_not_run';run_id=$runId
 windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=($linuxRoot+'/artifacts');data_dir=$dataDir
 windows_tools=$g.windows_tools;linux_tools=$g.linux_tools;wrapper=(Join-Path $g.windows_tools 'run-supervised-080.ps1');controller=$launch.Controller;controller_basename='replay-failed-queue-080.py';controller_sha256=$freeze.helper_files['replay-failed-queue-080.py']
 base_python=$g.base_python;python_launcher=$app.python_launcher;source_root=$app.source_root;runtime=$gate.runtime
 specification=$specPath;specification_sha256=(HashFile $specPath);required_artifacts=$spec.required_artifacts;input_freeze=$inputFreeze;input_freeze_sha256=(HashFile $inputFreeze);input_file_count=$files.Count
 helper_file_count=38;helper_sha256=$freeze.helper_files;reviewed_helper_sha256=$freeze.helper_files;toolbundle_freeze=$g.freeze_manifest;toolbundle_freeze_sha256=$g.freeze_sha256
 app_run_id=$app.run_id;app_snapshot=$app.run_id;source_snapshot=$app.run_id;source_freeze=$app.freeze_manifest;source_freeze_sha256=$app.freeze_sha256;app_freeze=$app.freeze_manifest;app_freeze_sha256=$app.freeze_sha256;app_file_count=198
 app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$app.setup_receipt_sha256;source_final=$false;source_finalized=$false
 guard_context=$guardPath;guard_context_sha256=$guardSHA;guard_receipt=$g.receipt;guard_receipt_sha256=$receiptSHA;guard_final_report=$g.final_report;guard_final_report_sha256=$g.final_report_sha256;guard_test_count=604;guard_module_count=12;guard_passed=$true;guard_actual_windows_exit_code=0;gate_sha256=$g.gate_sha256
 candidate_directory=$candidate.candidate_directory;candidate_updater_sha256=$g.updater_sha256;candidate_zip_sha256=$g.candidate_zip_sha256;candidate_manifest_sha256=$g.candidate_manifest_sha256;candidate_build_observation_sha256=$candidate.observation_sha256
 previous_failed_context=$oldPath;previous_failed_context_sha256=$oldSHA;previous_failed_specification_sha256=$old.specification_sha256;previous_failed_exec_session=9100;previous_failed_cleanup_admission=$diagnosisPath;previous_failed_cleanup_admission_sha256=$diagnosisSHA;historical_results_pooled=$false
 latest_fixture_report=$fixturePath;latest_fixture_report_sha256=$fixtureSHA;latest_fixture_count=5;latest_fixture_passed=$true;fixture_qualification_scope='unchanged_runtime_instrumentation_only';fixture_guard_case_count=594;fixture_application_qualification=$false
 acceptance=$old.acceptance;extraction_policy=@{work_seconds=120;outer_watchdog_seconds=125;inference_lease_seconds=210;guard_cases_actual_passed=604}
 full_suite_attestation=$null;full_suite_attestation_sha256=$null;current_backend_actual_pass=$false;current_ui_passed=$false;current_ux_passed=$false;current_native_passed=$false;current_copilot_passed=$false;current_recall_passed=$false;current_frontend_passed=$false
 target_regression_authorized_before_other_application_gates=$true;is_frozen_execution_spec=$true;launch_parameters_without_Execute=$launch;timeout_seconds=1800;cleanup_grace_seconds=30;wsl_crash_directory=$g.wsl_crash_directory
 source_and_helper_hashes_verified=$true;backup_file_read_or_hashed_during_materialization=$false;private_backup_credentials_or_production_read=$false;original_roots_and_transcripts_accessed_during_staging=$false
 production_remains_stopped=$true;production_retry_permitted=$false;production_modified=$false;production_services_started=$false;application_qualified=$false;release_qualified=$false;qualified=$false
 linux_workload_started=$false;launch_permitted=$false;requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true;preparation_only=$true;actual_windows_exit_code=$null;cleanup_complete=$false;receipt_sha256=$null
}
NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$runId;root=$root;spec_sha256=(HashFile $specPath);input_freeze_sha256=(HashFile $inputFreeze);input_files=$files.Count;argv_count=$spec.argv.Count;timeout_seconds=1800;linux_started=$false;private_backup_read=$false}|ConvertTo-Json -Depth 5

