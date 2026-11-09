#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$AppContext,[string]$AppContextSha256,[string]$UxContext,[string]$UxContextSha256)
if(-not $Stage){'NOT_RUN: prototype UI diagnostic filesystem proposal; root reviews before staging, auth or DB.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
$canonical=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $canonical).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical path support changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($canonical,[ref]$t,[ref]$e)
if($e.Count){throw 'Path support parse failed'}
$node=@($a.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($node.Count-ne1){throw 'Path support type inventory changed'};. ([scriptblock]::Create($node[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){$node=@($a.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false));if($node.Count-ne1){throw 'Path support function inventory changed'};. ([scriptblock]::Create($node[0].Extent.Text))}
$formal=Join-Path $workspace 'evidence/stage-five-sidebar-final-gates-after-ui-20261108.ps1'
if((Get-FileHash -LiteralPath $formal).Hash.ToLowerInvariant()-cne'37293adac1ea634fc9da250c80fd88bebaf0491bc1369c4c997d157818bd0c84'){throw 'Pure proof helper source changed'}
$t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($formal,[ref]$t,[ref]$e)
if($e.Count){throw 'Proof support parse failed'}
foreach($name in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts')){$node=@($a.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false));if($node.Count-ne1){throw 'Proof support function inventory changed'};. ([scriptblock]::Create($node[0].Extent.Text))}
$newSource='9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9'
Verify $AppContext $AppContextSha256;$app=ReadMap $AppContext
Require ($app.status-ceq'prepared_passed_diagnostic_only'-and$app.runtime_prepared-eq$true-and$app.actual_windows_exit_code-eq0-and$app.actual_windows_exec_session-eq43687) 'Actual fresh prototype preparation is required'
Require ($app.freeze_sha256-ceq$newSource-and$app.app_files-eq198-and$app.total_files-eq209-and$app.qualified_package_pin_count-eq59-and$app.pins_unchanged-eq$true-and$app.linux_source_matches_freeze-eq$true) 'Prototype installation/source/pins differ'
Require ($app.source_final-eq$false-and$app.release_qualified-eq$false-and$app.application_qualified-eq$false) 'Prototype must remain explicitly unqualified'
Verify $app.freeze_manifest $newSource;$af=ReadMap $app.freeze_manifest;Artifacts $af.files $app.bundle_root
Verify $app.setup_receipt $app.setup_receipt_sha256;$prep=ReadMap $app.setup_receipt
Require ($prep.passed-eq$true-and$prep.cleanup_complete-eq$true-and$prep.forced_cleanup-eq$false-and$prep.controller_exit_verified-eq$true-and$prep.proxy_exit_code-eq0-and$prep.runtime_verified_after_cleanup-eq$true-and$prep.cleanup_grace_seconds-ge30-and$prep.sleep_inhibition.restored-eq$true) 'Proven 47f preparation cleanup is incomplete'
foreach($k in @('errors','new_wsl_dumps','new_kernel_fatals')){Require (@($prep[$k]).Count-eq0) 'Preparation error or native event'}
Verify $app.final_report $app.final_report_sha256;$preparedFinal=ReadMap $app.final_report
Require ($preparedFinal.native_failure-eq$false-and$preparedFinal.passed-eq$true-and$preparedFinal.preparation_passed-eq$true-and$preparedFinal.scope_empty_verified-eq$true-and$preparedFinal.cleanup_grace_seconds-ge30-and$preparedFinal.power_unchanged-eq$true-and$preparedFinal.sleep_inhibition_restored-eq$true) 'Preparation final ownership/power/native verdict missing'
Require ($prep.initial_boot_id-ceq$prep.final_boot_id-and$preparedFinal.run_id-ceq$app.run_id-and$preparedFinal.actual_windows_exec_session-eq43687-and$preparedFinal.actual_windows_exit_code-eq0-and$preparedFinal.receipt_sha256-ceq$app.setup_receipt_sha256-and$preparedFinal.receipt-ceq$app.setup_receipt) 'Preparation actual proof binding differs'
Artifacts $preparedFinal.raw_artifact_sha256 $app.artifact_root
SameMap $prep.runtime $app.runtime
$workloadPath=Join-Path (Split-Path $app.setup_receipt -Parent) 'workload-report.json'
Verify $workloadPath $prep.workload_report_sha256;$workload=ReadMap $workloadPath
$installedSource=@{};foreach($key in $af.files.Keys){if($key.StartsWith('devbrain/')){$installedSource[$key.Substring(9)]=$af.files[$key]}}
Require ($installedSource.Count-eq198-and$workload.installed_identity.origin-ceq($app.source_root+'/src/devbrain/__init__.py')) 'Prepared installed source origin differs'
SameMap $workload.source_manifest $installedSource
Verify $UxContext $UxContextSha256;$ux=ReadMap $UxContext
Require ($ux.actual_windows_exec_session-gt0-and$ux.actual_windows_exit_code-eq0-and$ux.cleanup_complete-eq$true-and$ux.source_freeze_sha256-ceq$newSource-and$ux.actual_test_count-gt0) 'Fresh same-source UX actual exit evidence is required'
Verify $ux.receipt $ux.receipt_sha256;$ur=ReadMap $ux.receipt
Require ($ur.passed-eq$true-and$ur.cleanup_complete-eq$true-and$ur.forced_cleanup-eq$false-and$ur.native_failure-eq$false-and$ur.scope_empty_verified-eq$true-and$ur.scope_cleanup_grace_seconds-ge30-and$ur.cleanup_grace_seconds-ge30-and$ur.sleep_inhibition.restored-eq$true) 'Fresh UX independent cleanup missing'
foreach($k in @('errors','new_wsl_dumps','new_kernel_fatals')){Require (@($ur[$k]).Count-eq0) 'Fresh UX native error'}
Artifacts $ur.artifact_sha256 $ux.artifact_root
$us=ReadMap (Join-Path $ux.artifact_root 'regression-source.json')
$expectedUXSource=@{}
foreach($key in $installedSource.Keys){if($key-cin@('pyproject.toml','uv.lock')-or$key.StartsWith('src/')-or$key.StartsWith('tests/')-or$key.StartsWith('data/')){if($key-notmatch'(^|/)__pycache__/|\.py[co]$'){$expectedUXSource[$key]=$installedSource[$key]}}}
Require ($expectedUXSource.Count-gt0) 'Expected UX source map is empty';SameMap $us.source_hashes $expectedUXSource
$uxRaw=ReadMap (Join-Path $ux.artifact_root 'regressions-results.json')
Require ($uxRaw.phase-ceq'ux'-and$uxRaw.run_id-ceq$ux.run_id-and$uxRaw.status-ceq'passed'-and$uxRaw.normal_conftest-eq$true-and$uxRaw.modules.Count-eq28-and$uxRaw.individual_test_selectors.Count-eq0-and$uxRaw.skips_permitted-eq0) 'Whole canonical UX module scope differs'
Require ($uxRaw.counts.collected-eq$ux.actual_test_count-and$uxRaw.counts.passed-eq$ux.actual_test_count-and$uxRaw.counts.failures-eq0-and$uxRaw.counts.errors-eq0-and$uxRaw.counts.skipped-eq0-and$uxRaw.counts.missing-eq0-and$uxRaw.counts.duplicates-eq0-and$uxRaw.counts.unexpected_skips-eq0-and$uxRaw.counts.expected_skips.Count-eq0) 'Actual complete UX result is not clean'
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
$guardSha='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6'
Verify $guardPath $guardSha;$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.cleanup_complete-eq$true) 'Historical unchanged-helper guard result missing'
Verify $g.receipt '9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
Verify $g.freeze_manifest $g.freeze_sha256;$gf=ReadMap $g.freeze_manifest;Artifacts $gf.files $g.windows_root
Require ($gf.helper_files.Count-eq38) 'Canonical UI helper inventory changed';SameMap $gf.helper_files $g.helper_sha256
foreach($name in $g.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $name) $g.helper_sha256[$name]}
SameMap $app.canonical_regression_helper_sha256 $g.helper_sha256
SameMap $app.runtime $ur.runtime
$masterPath=Join-Path $workspace 'evidence/080-interactive-sidebar-resize-agent-templates-20261108.json'
Verify $masterPath '4d5597f51bc8ebb0da7b286a1a8b167a0bf088f150649726e39078edc325ceb3';$master=ReadMap $masterPath
foreach($entry in $master.files.GetEnumerator()){Verify $entry.Key $entry.Value}
$templatePath=Join-Path $workspace 'evidence/interactive-sidebar-resize-agent-templates-20261108/interactive.context.template.json'
$protocolPath=Join-Path $workspace 'evidence/interactive-sidebar-resize-agent-templates-20261108/operator-protocol.json'
$c=ReadMap $templatePath;SameMap $c.helper_sha256 $g.helper_sha256
Verify $c.reviewed_agent_driver $c.reviewed_agent_driver_sha256
$viewerSource=Join-Path $workspace 'evidence/attach-real-wt-diagnostic-20261109.py'
$viewerSha='eeb43f1818b182fc301d8e2b846c75b29ed853a6d2ed0d8f6a7f71033223cda0';Verify $viewerSource $viewerSha
$run='diag-prototype-realwt080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Never overwrite a diagnostic UI trial';NoReparse $root
foreach($sub in @('artifacts','inputs','real-wt-viewer')){$null=[IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$art=Join-Path $root 'artifacts';$files=[ordered]@{}
function CopyInput([string]$Source,[string]$Name,[string]$Sha){CopyExact $Source (RelativeFile $root $Name) $Sha;$files[$Name]=$Sha}
foreach($entry in @(@($AppContext,'inputs/prototype-prepare-context.json',$AppContextSha256),@($app.setup_receipt,'inputs/prototype-prepare-receipt.json',$app.setup_receipt_sha256),@($app.final_report,'inputs/prototype-prepare-final.json',$app.final_report_sha256),@($app.freeze_manifest,'inputs/prototype-source-freeze.json',$newSource),@($UxContext,'inputs/prototype-UX-context.json',$UxContextSha256),@($ux.receipt,'inputs/prototype-UX-receipt.json',$ux.receipt_sha256),@($guardPath,'inputs/historical-604-helper-context.json',$guardSha),@($g.freeze_manifest,'inputs/unchanged-38-helper-freeze.json',$g.freeze_sha256),@($templatePath,'inputs/historical-syntax-template.json',(HashFile $templatePath)),@($protocolPath,'inputs/operator-protocol.json',(HashFile $protocolPath)),@((Join-Path $g.artifact_root 'gate.json'),'artifacts/gate.json',$g.gate_sha256),@($c.reviewed_agent_driver,'artifacts/agent-pty-relay-pixels.py',$c.reviewed_agent_driver_sha256),@($viewerSource,'real-wt-viewer/attach-real-wt-diagnostic.py',$viewerSha),@($PSCommandPath,'inputs/prototype-diagnostic-materializer.ps1',(HashFile $PSCommandPath)))){CopyInput $entry[0] $entry[1] $entry[2]}
$spec=ReadMap $c.specification_template;$oldSpec=ReadMap $c.specification_template
Require ($spec.argv.Count-eq23-and$spec.argv[19]-ceq'--operator'-and$spec.argv[20]-ceq'agent'-and$spec.argv[21]-ceq'--duration'-and$spec.argv[22]-ceq'1800') 'Unchanged canonical UI contract differs'
$spec.run_id=$run;$spec.python_launcher=$app.python_launcher;$spec.argv[2]=$run;$spec.argv[4]=$linuxRoot+'/artifacts';$spec.argv[6]=$app.source_root
for($i=0;$i-lt23;$i++){if($i-notin@(2,4,6)){Require ($spec.argv[$i]-ceq$oldSpec.argv[$i]) 'Profile/model/account/client arguments changed'}}
SameMap $spec.env $oldSpec.env
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
$missing=@('new-source complete backend/full-suite attestation','new-source frontend/native3/Copilot/Ollama20/updater-copy/copy6 gates','new-source formal5tasks+3actualOSimages+visual acceptance','continuous8h explicitly not authorized')
$admission=@{schema_version=1;purpose='prototype_alpha_UI_error_inventory_not_release_admission';run_id=$run;source_freeze_sha256=$newSource;historical604_is_unchanged_helper_coverage_only=$true;historical604_source_freeze_sha256='ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703';old1561_381_copy6_V8_not_new_source_coverage=$true;fresh_prototype_prepare_passed=$true;fresh_prototype_UX_actual_test_count=$ux.actual_test_count;fresh_prototype_UX_passed=$true;missing_formal_prerequisites=$missing;backend_current_source_pass_claimed=$false;candidate_current_source_built_claimed=$false;source_final=$false;application_qualified=$false;release_qualified=$false;actual_start_requires_root_GO_and_exclusive_native_account_lease=$true;one_explicit_Codex_Start_only=$true;same_accounts_profiles_models=$true;WT_primary_admitted_before_Start_required=$true;optional_tasks_sizes_do_not_become_accepted_if_unobserved=$true;normal_finish_before_seconds=1650;controller_hard_duration_seconds=1800;account_access_during_staging=$false;models_or_DB_started_during_staging=$false;eight_hour_authorized=$false}
$admissionPath=Join-Path $root 'inputs/diagnostic-admission.json';NewJson $admissionPath $admission;$files['inputs/diagnostic-admission.json']=HashFile $admissionPath
$viewerPlan=@{schema_version=1;scope='prototype_actual_WT_attach_only_plan';run_id=$run;viewer=($linuxRoot+'/real-wt-viewer/attach-real-wt-diagnostic.py');viewer_sha256=$viewerSha;python_launcher=$app.python_launcher;canonical_controller=($g.linux_tools+'/run-interactive-ux080.py');canonical_controller_sha256=$g.helper_sha256['run-interactive-ux080.py'];manifest='RUNTIME_PRIVATE_READY_MANIFEST_REQUIRED';sizes=@('80x24','120x36','180x55');initial_size='120x36';actual_registered_WT_writer_before_one_Start_required=$true;automatic_start=$false;canonical_entrypoint_spoofed=$false;automatic_visual_pass=$false;OS_capture_claimed=$false;source_freeze_sha256=$newSource;application_qualified=$false}
$viewerPlanPath=Join-Path $root 'real-wt-viewer/real-wt-plan.json';NewJson $viewerPlanPath $viewerPlan;$files['real-wt-viewer/real-wt-plan.json']=HashFile $viewerPlanPath
$freezePath=Join-Path $root 'prepared-input-freeze.json';Artifacts $files $root
NewJson $freezePath @{schema_version=1;run_id=$run;files=$files;helper_sha256=$g.helper_sha256;source_freeze_sha256=$newSource;status='prepared_not_run';diagnostic_only=$true;previous_results_pooled=$false;application_qualified=$false;release_qualified=$false}
$c.run_id=$run;$c.status='prepared_not_run';$c.scope='prototype_real_WT_UI_diagnostic_context';$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=$art;$c.linux_artifact_root=$linuxRoot+'/artifacts'
$c.source_root=$app.source_root;$c.python_launcher=$app.python_launcher;$c.source_freeze=$app.freeze_manifest;$c.source_freeze_sha256=$newSource;$c.app_prepare_receipt=$app.setup_receipt;$c.app_prepare_receipt_sha256=$app.setup_receipt_sha256;$c.app_run_id=$app.run_id
$c.source_snapshot=$app.run_id;$c.app_snapshot=$app.run_id;$c.runtime=$app.runtime
$c.windows_tools=$g.windows_tools;$c.linux_tools=$g.linux_tools;$c.wrapper=Join-Path $g.windows_tools 'run-supervised-080.ps1';$c.controller=$g.linux_tools+'/run-interactive-ux080.py';$c.controller_name='run-interactive-ux080.py';$c.controller_sha256=$g.helper_sha256['run-interactive-ux080.py'];$c.base_python=$app.runtime.python_executable
$c.toolbundle_freeze=$g.freeze_manifest;$c.toolbundle_freeze_sha256=$g.freeze_sha256;$c.helper_file_count=38;$c.helper_sha256=$g.helper_sha256;$c.reviewed_helper_sha256=$g.helper_sha256;$c.gate_sha256=$g.gate_sha256
$c.specification=$specPath;$c.specification_sha256=HashFile $specPath;$c.required_artifacts=$spec.required_artifacts;$c.input_freeze=$freezePath;$c.input_freeze_sha256=HashFile $freezePath;$c.frozen_input_count=$files.Count;$c.execution_argv_materialized=$true;$c.materialization_required=$false
foreach($prefix in @('backend','ux','queue')){foreach($suffix in @('context','context_sha256','receipt_sha256')){$c[$prefix+'_prerequisite_'+$suffix]=$null};$c[$prefix+'_prerequisite_passed']=$false}
foreach($key in @($c.Keys|Where-Object{$_-like'candidate_*'})){$c[$key]=$null}
foreach($key in @('full_suite_attestation','full_suite_attestation_sha256','backend_prerequisite_expected_count','ux_prerequisite_expected_count','queue_prerequisite_expected_jobs')){$c[$key]=$null}
$c.candidate_binding_current_source=$false;$c.backend_current_source_passed=$false;$c.current_ui_passed=$false
$c.guard_context=$guardPath;$c.guard_context_sha256=$guardSha;$c.guard_receipt=$g.receipt;$c.guard_receipt_sha256='9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84';$c.guard_passed=$true;$c.historical_guard_source_freeze_sha256='ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703';$c.guard_is_helper_only_not_new_App_coverage=$true
$c.prototype_UX_context=$UxContext;$c.prototype_UX_context_sha256=$UxContextSha256;$c.prototype_UX_actual_test_count=$ux.actual_test_count;$c.prototype_UX_passed_diagnostic_only=$true
$c.launch_requires_backend_pass=$false;$c.launch_requires_ux_pass=$false;$c.launch_requires_queue_pass=$false;$c.diagnostic_only=$true;$c.purpose=$admission.purpose;$c.formal_release_admission=$false;$c.missing_formal_prerequisites=$missing
$c.application_qualified=$false;$c.release_qualified=$false;$c.source_final=$false;$c.source_finalized=$false;$c.source_qualification_pending=$true;$c.preparation_only=$true;$c.launch_permitted=$false;$c.linux_workload_started=$false;$c.actual_windows_exec_session=$null;$c.actual_windows_exit_code=$null;$c.cleanup_complete=$false
$c.diagnostic_admission=$admissionPath;$c.diagnostic_admission_sha256=HashFile $admissionPath;$c.real_WT_viewer_plan=$viewerPlanPath;$c.real_WT_viewer_plan_sha256=HashFile $viewerPlanPath;$c.real_WT_viewer_sha256=$viewerSha;$c.real_WT_before_Start_required=$true;$c.one_explicit_Codex_Start_only=$true;$c.normal_finish_before_seconds=1650
$c.ready_file=Join-Path $art 'interactive-ready.json';$c.agent_pty_relay_pixels=Join-Path $art 'agent-pty-relay-pixels.py';$c.agent_pty_relay_pixels_sha256=$c.reviewed_agent_driver_sha256;$c.active_agent_pty_relay=$linuxRoot+'/artifacts/agent-pty-relay-pixels.py'
$c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$c.linux_artifact_root;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=1980;CleanupGraceSeconds=30;WslCrashDirectory=$g.wsl_crash_directory}
$contextPath=Join-Path $workspace ('evidence/080-prototype-real-wt-diagnostic-ui-prepared-context-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'.json')
NewJson $contextPath $c
@{prepared_context=$contextPath;sha256=HashFile $contextPath;run_id=$run;input_freeze_sha256=HashFile $freezePath;canonical_helpers=38;diagnostic_only=$true;new_source_qualified=$false;auth_or_DB_or_Linux_started=$false}|ConvertTo-Json -Depth 5
