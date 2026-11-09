#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string[]]$Names=@('frontend','ollama20','native','copilot','upgrade_smoke'))
if(-not $Stage){'NOT_RUN: diagnostic filesystem staging only; never launches Linux, tests or models.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$canonical=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $canonical).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical path helper changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($canonical,[ref]$tok,[ref]$err)
if($err.Count){throw 'Canonical path helper parse failed'}
$add=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($add.Count-ne1){throw 'Canonical Add-Type changed'};. ([scriptblock]::Create($add[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $node=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($node.Count-ne1){throw 'Canonical function changed'};. ([scriptblock]::Create($node[0].Extent.Text))
}
$formal=Join-Path $workspace 'evidence/stage-five-sidebar-final-gates-after-ui-20261108.ps1'
if((Get-FileHash -LiteralPath $formal).Hash.ToLowerInvariant()-cne'37293adac1ea634fc9da250c80fd88bebaf0491bc1369c4c997d157818bd0c84'){throw 'Formal materializer changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($formal,[ref]$tok,[ref]$err)
if($err.Count){throw 'Formal materializer parse failed'}
foreach($name in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts')){
 $node=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($node.Count-ne1){throw 'Reviewed path function changed'};. ([scriptblock]::Create($node[0].Extent.Text))
}
$masterPath=Join-Path $workspace 'evidence/080-sidebar-resize-remaining-gate-templates-604-20261108.json'
$masterSHA='f4e039f5040cd70f2f3b0aa18699bfacc92e1f445ad2bb81dd685d96b2643dba'
Verify $masterPath $masterSHA;$master=ReadMap $masterPath
Require ($master.source_snapshot-ceq'app080-20261108T222731Z'-and$master.source_freeze_sha256-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'-and$master.helper_count-eq38) 'Wrong current template generation'
Verify $master.input_freeze $master.input_freeze_sha256
$tf=ReadMap $master.input_freeze;Artifacts $tf.files $master.windows_root;SameMap $tf.helper_sha256 $master.helper_sha256
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
$appSHA='d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
Verify $appPath $appSHA;$app=ReadMap $appPath
Require ($app.run_id-ceq$master.source_snapshot-and$app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.qualified_package_pin_count-eq59-and$app.pins_unchanged-eq$true) 'Current preparation missing'
Verify $app.freeze_manifest $master.source_freeze_sha256
$af=ReadMap $app.freeze_manifest;Artifacts $af.files $app.bundle_root
Require ($af.files.Count-eq209-and$app.app_files-eq198) 'Current app inventory changed'
Verify $app.setup_receipt $master.app_prepare_receipt_sha256
$prep=ReadMap $app.setup_receipt
Require ($prep.passed-eq$true-and$prep.cleanup_complete-eq$true-and$prep.forced_cleanup-eq$false-and$prep.sleep_inhibition.restored-eq$true) 'Preparation cleanup incomplete'
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
$guardSHA='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6'
Verify $guardPath $guardSHA;$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_windows_exec_session-eq82992-and$g.actual_test_count-eq604-and$g.cleanup_complete-eq$true-and$g.app_freeze_sha256-ceq$master.source_freeze_sha256) 'Current604 gate missing'
SameMap $g.helper_sha256 $master.helper_sha256;SameMap $g.reviewed_helper_sha256 $master.helper_sha256
$receiptPath=Join-Path $g.artifact_root 'receipt.json';$receiptSHA='9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
Verify $receiptPath $receiptSHA;$r=ReadMap $receiptPath
Require ($r.passed-eq$true-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and$r.sleep_inhibition.restored-eq$true) 'Current604 independent cleanup incomplete'
foreach($k in @('errors','new_wsl_dumps','new_kernel_fatals')){Require (@($r[$k]).Count-eq0) 'Current604 errors or native events'}
Artifacts $r.artifact_sha256 $g.artifact_root
Verify $g.final_report 'ad4a0f638bef723c4e8c918e2daeb4f71eac60e238d32ea454586ca53d326e8f'
Verify $g.freeze_manifest $g.freeze_sha256
foreach($n in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $n) $master.helper_sha256[$n]}
$candidatePath=$master.candidate_binding.context
Verify $candidatePath '6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b'
$build=ReadMap $candidatePath
Require ($build.status-ceq'candidate_built_observed_not_qualified'-and$build.actual_windows_exit_code-eq0-and$build.cleanup_complete-eq$true-and$build.root_output_review_passed-eq$true-and$build.source_freeze_sha256-ceq$master.source_freeze_sha256) 'Current candidate not built/reviewed'
Artifacts $build.output_sha256 $build.windows_root
Verify $build.observation $build.observation_sha256
$fixtures=$master.runtime_only_fixtures.path
Verify $fixtures $master.runtime_only_fixtures.sha256
$controllers=@{frontend='run-regressions-080.py';ollama20='run-regressions-080.py';native='validate-native-account080.py';copilot='validate-copilot-account080.py';upgrade_smoke='test_devbrain_update080_smoke.py'}
Require ($Names.Count-gt0-and@($Names|Sort-Object -Unique).Count-eq$Names.Count) 'Names must be unique'
$templates=[ordered]@{}
foreach($name in $Names){
 Require ($controllers.ContainsKey($name)) 'Unsupported diagnostic gate'
 $entry=$master.templates[$name];Verify $entry.path $entry.sha256;$t=ReadMap $entry.path
 Require ($t.source_root-ceq$master.source_root-and$t.python_launcher-ceq$master.python_launcher-and$t.source_freeze_sha256-ceq$master.source_freeze_sha256-and$t.controller_basename-ceq$controllers[$name]-and$t.controller_sha256-ceq$master.helper_sha256[$controllers[$name]]) 'Template source/controller differs'
 SameMap $t.reviewed_helper_sha256 $master.helper_sha256;SameMap $t.runtime $master.runtime
 SameMap $t.specification_template.env @{LANG='C.UTF-8';LC_ALL='C.UTF-8';TMPDIR='/tmp'}
 Require ($t.specification_template.run_id-ceq'<RUN_ID>'-and$t.specification_template.python_launcher-ceq$master.python_launcher) 'Template argv binding differs'
 $templates[$name]=$t
}
$baseline=Join-Path $build.windows_root 'releases/devbrain-0.7.2.zip'
$baselineSHA='6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c'
if($Names-ccontains'upgrade_smoke'){Verify $baseline $baselineSHA}
$shared=[ordered]@{
 'diagnostic-materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
 'formal-materializer-unchanged.ps1'=@{path=$formal;sha='37293adac1ea634fc9da250c80fd88bebaf0491bc1369c4c997d157818bd0c84'}
 'proposal-master.json'=@{path=$masterPath;sha=$masterSHA}
 'source-freeze.json'=@{path=$master.source_freeze;sha=$master.source_freeze_sha256}
 'app-context.json'=@{path=$appPath;sha=$appSHA}
 'app-prepare-receipt.json'=@{path=$app.setup_receipt;sha=$master.app_prepare_receipt_sha256}
 'guard-context-passed.json'=@{path=$guardPath;sha=$guardSHA}
 'guard-receipt.json'=@{path=$receiptPath;sha=$receiptSHA}
 'guard-final-report.json'=@{path=$g.final_report;sha='ad4a0f638bef723c4e8c918e2daeb4f71eac60e238d32ea454586ca53d326e8f'}
 'candidate-v8-context.json'=@{path=$candidatePath;sha='6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b'}
 'candidate-v8-observation.json'=@{path=$build.observation;sha=$build.observation_sha256}
 'runtime-only-fixtures.json'=@{path=$fixtures;sha=$master.runtime_only_fixtures.sha256}
}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$created=[ordered]@{}
foreach($name in $templates.Keys){
 $t=$templates[$name];$entry=$master.templates[$name];$label=$name.Replace('_','-')
 $run="$label-diag080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
 Require ($run.Length-le64) 'Run id too long'
 $root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Diagnostic root exists';NoReparse $root
 $null=[IO.Directory]::CreateDirectory($root);PathProof $root
 $art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs'
 $null=[IO.Directory]::CreateDirectory($art);$null=[IO.Directory]::CreateDirectory($inputs)
 $linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt=$linuxRoot+'/artifacts'
 $specText=($t.specification_template|ConvertTo-Json -Depth 40).Replace('<LINUX_RUN_ROOT>',$linuxRoot).Replace('<LINUX_ARTIFACT_ROOT>',$linuxArt).Replace('<RUN_ID>',$run)
 $spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String
 if($name-ceq'upgrade_smoke'){$spec.argv=@('--execute')+@($spec.argv)}
 Require (($spec|ConvertTo-Json -Depth 40)-notmatch'<[A-Z_]+>'-and@($spec.argv|Where-Object{$_-ceq'--execute'}).Count-eq1) 'Unresolved diagnostic spec'
 $specPath=Join-Path $art 'spec.json';NewJson $specPath $spec
 $files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
 foreach($key in $shared.Keys){$item=$shared[$key];CopyExact $item.path (Join-Path $inputs $key) $item.sha;$files["inputs/$key"]=$item.sha}
 CopyExact $entry.path (Join-Path $inputs 'unchanged-formal-template.json') $entry.sha256;$files['inputs/unchanged-formal-template.json']=$entry.sha256
 CopyExact (Join-Path $g.artifact_root 'gate.json') (Join-Path $art 'gate.json') $master.runtime_gate_sha256
 $files['artifacts/gate.json']=$master.runtime_gate_sha256
 if($name-ceq'upgrade_smoke'){
  CopyExact $baseline (Join-Path $inputs 'devbrain-0.7.2.zip') $baselineSHA;$files['inputs/devbrain-0.7.2.zip']=$baselineSHA
  foreach($rel in $build.output_sha256.Keys){$leaf=[IO.Path]::GetFileName($rel);CopyExact (RelativeFile $build.windows_root $rel) (Join-Path $inputs $leaf) $build.output_sha256[$rel];$files["inputs/$leaf"]=$build.output_sha256[$rel]}
 }
 $freezePath=Join-Path $root 'prepared-input-freeze.json'
 NewJson $freezePath @{schema_version=1;scope='devbrain_independent_diagnostic_inputs';run_id=$run;files=$files;helper_sha256=$master.helper_sha256;source_freeze_sha256=$master.source_freeze_sha256;guard_receipt_sha256=$receiptSHA;error_inventory_only=$true;formal_UI_pass_claimed=$false;full_backend_pass_claimed=$false;release_qualified=$false;linux_workload_started=$false}
 $contextPath=Join-Path $workspace "evidence/080-$label-diagnostic-active-context-$stamp.json"
 $c=[ordered]@{
  schema_version=1;scope='devbrain_independent_diagnostic_context';status='prepared_not_run';phase=$name;name=$name;run_id=$run;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=$linuxArt
  windows_tools=$g.windows_tools;linux_tools=$g.linux_tools;wrapper=(Join-Path $g.windows_tools 'run-supervised-080.ps1');controller=($g.linux_tools+'/'+$t.controller_basename);controller_basename=$t.controller_basename;controller_sha256=$master.helper_sha256[$t.controller_basename];base_python=$t.base_python;python_launcher=$master.python_launcher;source_root=$master.source_root;runtime=$master.runtime
  specification=$specPath;specification_sha256=(HashFile $specPath);required_artifacts=$spec.required_artifacts;input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);input_file_count=$files.Count;frozen_input_count=$files.Count
  helper_sha256=$master.helper_sha256;reviewed_helper_sha256=$master.helper_sha256;helper_file_count=38;toolbundle_freeze=$g.freeze_manifest;toolbundle_freeze_sha256=$g.freeze_sha256
  app_snapshot=$master.source_snapshot;source_snapshot=$master.source_snapshot;app_freeze=$master.source_freeze;app_freeze_sha256=$master.source_freeze_sha256;source_freeze_sha256=$master.source_freeze_sha256;app_file_count=198;source_final=$false;source_finalized=$false;app_prepare_receipt=$master.app_prepare_receipt;app_prepare_receipt_sha256=$master.app_prepare_receipt_sha256
  gate_sha256=$master.runtime_gate_sha256;runtime_gate_sha256=$master.runtime_gate_sha256;guard_context=$guardPath;guard_context_sha256=$guardSHA;guard_receipt=$receiptPath;guard_receipt_sha256=$receiptSHA;guard_final_report=$g.final_report;guard_final_report_sha256=$shared['guard-final-report.json'].sha;guard_test_count=604
  candidate_directory=$master.candidate_binding.directory;candidate_build_context=$candidatePath;candidate_build_context_sha256=$shared['candidate-v8-context.json'].sha;candidate_updater_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py'];candidate_zip_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip'];candidate_manifest_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json']
  timeout_seconds=$t.timeout_seconds;cleanup_grace_seconds=30;wsl_crash_directory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes';private_root='/home/piotr/.cache/devbrain-regressions-080'
  launch_permitted=$false;requires_root_host_go=$true;linux_workload_started=$false;preparation_only=$true;error_inventory_only=$true;application_qualified=$false;release_qualified=$false;production_modified=$false;production_remains_stopped=$true;credentials_read_during_staging=$false
  current_ui_passed=$false;current_backend_actual_pass=$false;full_suite_attestation=$null;full_suite_attestation_sha256=$null;missing_formal_prerequisites=@('backend1561+canonicalattestation','UX381','whole6COPY','interactive5tasks+3OSphotos+visual_acceptance_true');formal_release_admission_unchanged=$true;diagnostic_result_must_not_be_substituted_for_formal_release_gate=$true
  is_frozen_execution_spec=$true;materialization_required=$false;source_and_helper_hashes_verified=$true;acceptance=$t.acceptance;template_path=$entry.path;template_sha256=$entry.sha256;created_utc=[DateTimeOffset]::UtcNow.ToString('o')
  actual_windows_exit_code=$null;actual_windows_exec_session=$null;cleanup_complete=$false
 }
 $c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$c.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory=$c.wsl_crash_directory}
 Artifacts $files $root
 foreach($helper in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $helper) $master.helper_sha256[$helper]}
 Verify $masterPath $masterSHA;Verify $guardPath $guardSHA;Verify $appPath $appSHA;Artifacts $build.output_sha256 $build.windows_root
 NewJson $contextPath $c
 $created[$name]=@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$run;specification=$specPath;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;status=$c.status;launch_permitted=$false}
}
$output=Join-Path $workspace "evidence/080-independent-diagnostic-contexts-$stamp.json"
NewJson $output @{schema_version=1;scope='devbrain_independent_error_inventory_contexts';status='prepared_not_run';contexts=$created;source_snapshot=$master.source_snapshot;source_freeze_sha256=$master.source_freeze_sha256;helper_count=38;guard_context_sha256=$guardSHA;error_inventory_only=$true;formal_release_admission_unchanged=$true;current_ui_passed=$false;linux_workload_started=$false;production_modified=$false;release_qualified=$false;eight_hour_test_included=$false}
@{master=$output;sha256=(HashFile $output);contexts=$created;linux_workload_started=$false}|ConvertTo-Json -Depth 8

