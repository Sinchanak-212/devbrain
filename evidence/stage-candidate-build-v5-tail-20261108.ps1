
$oldContextPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v4-20261108.json'
$appContextPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
Verify $oldContextPath 'e5403e9e6bf747aed11adcd85960b19f67bae445ea2d8527f9cec5f70ef7737f'
Verify $appContextPath '7f14edc423655eb90e0ced54d3ff05e55f17a6ee34bb05f2a3b29eaf9d282e39'
$old=ReadMap $oldContextPath;$app=ReadMap $appContextPath
Require ($app.run_id-ceq'app080-20261108T183259Z'-and$app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.app_files-eq198-and$app.qualified_package_pin_count-eq59-and$app.pins_unchanged-eq$true-and$app.linux_source_matches_freeze-eq$true-and$app.native_failure-eq$false-and$app.cleanup_grace_seconds-ge30) 'New app actual preparation is incomplete'
Require ($app.freeze_sha256-ceq'3dfc2738944f1a5fa3ab3087080f716c92d72f98cef819d7761d1118384f5fcf'-and$app.setup_receipt_sha256-ceq'2fc2fbf9c20d97674c67847f1039b1a9091f1f5239b0aa26c1c3857bc65bb336') 'New app identity differs'
Verify $app.freeze_manifest $app.freeze_sha256;Verify $app.setup_receipt $app.setup_receipt_sha256
foreach($pair in @(@('input_freeze','input_freeze_sha256'),@('launcher','launcher_sha256'),@('launch_plan','launch_plan_sha256'),@('launcher_freeze','launcher_freeze_sha256'))){Verify $old[$pair[0]] $old[$pair[1]]}
Require ($old.launcher_sha256-ceq'e385b99709ccb7f750652b83208f26f16b048d0faeb2154070e719b12eaf2c4d') 'Approved v4 launcher differs'
Verify (Join-Path $old.windows_root 'builder-ast-proof.json') '805ed8c08906668dadb0a8df7e13886720b12f4605b99e144d7f33c22a7737cb'
$oldFreeze=ReadMap $old.input_freeze;$source=ReadMap $app.freeze_manifest
$appKeys=@($source.files.Keys|Where-Object{$_.StartsWith('devbrain/')}|Sort-Object)
Require ($appKeys.Count-eq198) 'Exactly 198 app files required'
$changed=@($appKeys|Where-Object{$oldFreeze.files[$_]-cne$source.files[$_]})
$expectedChanged=@('devbrain/src/devbrain/agent.py','devbrain/src/devbrain/service.py','devbrain/tests/test_extraction_safety.py','devbrain/tests/test_memory_stabilization.py')
Require (($changed -join '|')-ceq($expectedChanged -join '|')) 'Unexpected app delta from v4'
foreach($rel in $appKeys){Verify (RelativeFile $app.bundle_root $rel) $source.files[$rel]}
$copyOld=@('release-tools/build-devbrain-update-080.py','release-tools/devbrain-update080-template.py','releases/devbrain-0.7.2.zip','inputs/gate.json','inputs/guard-context.json','inputs/guard-receipt.json','inputs/toolbundle-freeze.json')
foreach($rel in $copyOld){Verify (RelativeFile $old.windows_root $rel) $oldFreeze.files[$rel]}
$extra=@(
 @('inputs/app-context.json',$appContextPath,'7f14edc423655eb90e0ced54d3ff05e55f17a6ee34bb05f2a3b29eaf9d282e39'),
 @('inputs/source-freeze.json',$app.freeze_manifest,$app.freeze_sha256),
 @('inputs/app-prepare-receipt.json',$app.setup_receipt,$app.setup_receipt_sha256),
 @('inputs/extraction-budget-preparation.json',(Join-Path $workspace 'evidence/080-extraction-budget-preparation-20261108.json'),'8f0f342befeac6415cd4de882144c1e191be04725e3421a6b6512e7ab9485866'),
 @('inputs/extraction-budget-peer-review.json',(Join-Path $workspace 'evidence/080-extraction-budget-qr-peer-review-20261108.json'),'329e3853f782401a57a864dd8b6178e1842a0a805efd27b3997dced3448997c1'),
 @('inputs/extraction-budget-freeze-handoff.json',(Join-Path $workspace 'evidence/080-extraction-budget-freeze-handoff-20261108.json'),'238a69e6c5147e8ece8f6343d5c8fdc1a96b4ecbe558d9368ab1dcc3d2d7f271'),
 @('inputs/previous-build-context-v4.json',$oldContextPath,'e5403e9e6bf747aed11adcd85960b19f67bae445ea2d8527f9cec5f70ef7737f')
)
foreach($row in $extra){Verify $row[1] $row[2]}
PathProof $physicalBase
$runId='final-candidate-extraction080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
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
$plan.launch_waits_for=@('Root review and explicit serial handoff; no other Linux workload','Source183259 actual prepare passed; mechanical output remains unqualified and has no current-source UI/application gate claim')
$plan.previous_successful_build_plan_sha256=$old.launch_plan_sha256
Require ($plan.builder_argv.Count-eq6-and$plan.bounded_linux_argv.Count-eq10) 'Builder and timeout arrays must retain 6 and 10 literal arguments'
$planPath=Join-Path $newRoot 'launch-plan-v5.json';NewJson $planPath $plan;$files['launch-plan-v5.json']=HashFile $planPath
$freeze=[ordered]@{
 schema_version=1;scope='devbrain_frozen_candidate_build_envelope';run_id=$runId;status='prepared_not_run'
 source_snapshot=$app.run_id;app_file_count=198;source_freeze_sha256=$app.freeze_sha256;app_prepare_receipt_sha256=$app.setup_receipt_sha256
 toolbundle_freeze_sha256=$old.toolbundle_freeze_sha256;guard_receipt_sha256=$old.guard_receipt_sha256;runtime_gate_sha256=$old.runtime_gate_sha256;baseline_sha256=$old.baseline_sha256
 files=$files;qualified=$false;application_qualification=$false;source_final_qualification=$false;new_guard604_status='not_run';created_utc=[DateTime]::UtcNow.ToString('o')
}
$freezePath=Join-Path $newRoot 'build-input-freeze-v5.json';NewJson $freezePath $freeze
$original=[IO.File]::ReadAllText($old.launcher)
$launcherText=$original.Replace($old.windows_root,$newRoot).Replace('build-input-freeze-v4.json','build-input-freeze-v5.json').Replace('launcher-freeze-v4.json','launcher-freeze-v5.json').Replace('launch-plan-v4.json','launch-plan-v5.json')
Require ($launcherText-cne$original) 'Launcher root transformation missing'
Require ($launcherText.Replace($newRoot,$old.windows_root).Replace('build-input-freeze-v5.json','build-input-freeze-v4.json').Replace('launcher-freeze-v5.json','launcher-freeze-v4.json').Replace('launch-plan-v5.json','launch-plan-v4.json')-ceq$original) 'Unexpected observer semantic change'
$launcherPath=Join-Path $newRoot 'run-candidate-build-v5.ps1'
$bytes=[Text.UTF8Encoding]::new($false).GetBytes($launcherText)
$stream=[IO.File]::Open($launcherPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
PathProof $launcherPath
$pt=$null;$pe=$null;$null=[Management.Automation.Language.Parser]::ParseFile($launcherPath,[ref]$pt,[ref]$pe)
Require ($pe.Count-eq0) 'New launcher parse failed'
CopyExact (Join-Path $old.windows_root 'builder-ast-proof.json') (Join-Path $newRoot 'builder-ast-proof.json') $old.builder_ast_proof_sha256
$launcherFreezePath=Join-Path $newRoot 'launcher-freeze-v5.json'
$lf=[ordered]@{
 schema_version=1;scope='devbrain_candidate_build_launcher_freeze';run_id=$runId
 files=[ordered]@{'run-candidate-build-v5.ps1'=(HashFile $launcherPath);'builder-ast-proof.json'=$old.builder_ast_proof_sha256;'build-input-freeze-v5.json'=(HashFile $freezePath)}
 status='prepared_not_run';windows_ast='pass';actual_json_builder_args=6;actual_json_timeout_args=10;root_review_required=$true;qualified=$false
 approved_v4_launcher_sha256=$old.launcher_sha256;allowed_delta_only=@('exact private root literal','three v4 metadata file names changed to v5')
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
 new_source_diff_only_reviewed_extraction_budget_files=$changed;helper_sha256=$old.helper_sha256
 extraction_budget_peer_review_sha256='329e3853f782401a57a864dd8b6178e1842a0a805efd27b3997dced3448997c1'
 new_guard604_status='not_run';current_source_application_gates_status='not_run';expected_backend_cases=1517;expected_ux_cases=377
 candidate_directory=(Join-Path $newRoot 'releases/candidates/0.8.0');output_sha256=$null;observation=$null;observation_sha256=$null
}
$contextPath=Join-Path $workspace 'evidence/080-final-candidate-build-ready-context-v5-20261108.json'
NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$newRoot;launcher=$launcherPath;launcher_sha256=(HashFile $launcherPath);freeze_sha256=(HashFile $freezePath);plan_sha256=(HashFile $planPath);app_files=198;input_files=$files.Count;new_launcher_parse_errors=$pe.Count;builder_args=$plan.builder_argv.Count;timeout_args=$plan.bounded_linux_argv.Count;status='prepared_not_run';linux_launched=$false}|ConvertTo-Json -Depth 5

