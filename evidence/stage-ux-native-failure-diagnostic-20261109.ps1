#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage)
if(-not $Stage){Write-Output 'NOT_RUN: Windows staging only; no Linux preparation or tests are launched.';return}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$physicalBase='C:\Users\piotr\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\DevBrain\qualification'
# Reuse the exact already reviewed path/copy/publication functions.
$sourceHelper=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $sourceHelper -Algorithm SHA256).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical stage helper changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($sourceHelper,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Stage helper syntax changed'}
$nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($nodes.Count-ne1){throw 'Path helper inventory differs'};. ([scriptblock]::Create($nodes[0].Extent.Text))
foreach($name in @('NoReparse','HashFile','SourceProof')){
 $nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($nodes.Count-ne1){throw 'Canonical function missing'};. ([scriptblock]::Create($nodes[0].Extent.Text))
}
$reviewedStage=Join-Path $workspace 'evidence/stage-ux-sidebar-resize-604-20261108.ps1'
if((HashFile $reviewedStage)-cne'8a4eb75de06a55e5e40c3db58739d8b90079381c23fa6b6962550b29c861ff5c'){throw 'Reviewed stage source changed'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($reviewedStage,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Reviewed stage syntax changed'}
foreach($name in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts')){
 $nodes=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$false))
 if($nodes.Count-ne1){throw 'Reviewed function missing'};. ([scriptblock]::Create($nodes[0].Extent.Text))
}
$contextPath=Join-Path $workspace 'evidence/080-ux-native-failure-diagnostic-context-20261109.json'
Require (-not(Test-Path -LiteralPath $contextPath)) 'Fresh UX diagnostic context required'
$appPath=Join-Path $workspace 'evidence/080-app-native-failure-diagnostic-prepared-context-20261109.json'
$appSHA='387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92';Verify $appPath $appSHA;$app=ReadMap $appPath
Require ($app.status-ceq'prepared_passed_diagnostic_only'-and$app.runtime_prepared-eq$true-and$app.actual_windows_exec_session-eq43687-and$app.actual_windows_exit_code-eq0-and$app.cleanup_complete-eq$true-and$app.pins_unchanged-eq$true-and$app.qualified_package_pin_count-eq59-and$app.linux_source_matches_freeze-eq$true-and$app.release_qualified-eq$false) 'Actual fresh App prepare incomplete'
Verify $app.setup_receipt 'fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd'
Verify $app.final_report 'b3882183d0921fa8f305de86f27ce3af3fc42b9d9a7211d9ee68b5208e543bed'
Verify $app.freeze_manifest '9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9'
$pr=ReadMap $app.setup_receipt;$ar=ReadMap $app.final_report;$af=ReadMap $app.freeze_manifest
Require ($pr.passed-eq$true-and$pr.cleanup_complete-eq$true-and$pr.forced_cleanup-eq$false-and$pr.controller_exit_verified-eq$true-and$pr.proxy_exit_code-eq0-and$pr.cleanup_grace_seconds-ge30-and$pr.sleep_inhibition.restored-eq$true-and@($pr.errors).Count-eq0-and@($pr.new_kernel_fatals).Count-eq0-and@($pr.new_wsl_dumps).Count-eq0-and$pr.initial_boot_id-ceq$pr.final_boot_id-and$ar.native_failure-eq$false-and$ar.in_run_boot_unchanged-eq$true) 'Prepare cleanup/platform proof incomplete'
Artifacts $af.files $app.bundle_root
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json';$guardSHA='9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6';Verify $guardPath $guardSHA;$g=ReadMap $guardPath
Require ($g.helper_sha256.Count-eq38-and$g.status-ceq'passed') 'Canonical runtime instrumentation incomplete'
foreach($n in $g.helper_sha256.Keys){Verify (RelativeFile $g.windows_tools $n) $g.helper_sha256[$n]}
$oldApp=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json';Verify $oldApp 'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
$run='ux-uxfailure080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh UX root exists';NoReparse $root
foreach($sub in @('artifacts','inputs','tools')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$art=Join-Path $root artifacts;$tools=Join-Path $root tools;$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt=$linuxRoot+'/artifacts';$linuxTools=$linuxRoot+'/tools'
$files=[ordered]@{};$helpers=[ordered]@{}
foreach($name in $g.helper_sha256.Keys){
 $src=RelativeFile $g.windows_tools $name;$dst=RelativeFile $tools $name
 if($name-ceq'run-regressions-080.py'){
  $old=[IO.File]::ReadAllText($src);Require ([regex]::Matches($old,'--maxfail=1').Count-eq1-and-not$old.Contains('--maxfail=0')) 'Controller delta not unique'
  $new=$old.Replace('--maxfail=1','--maxfail=0');Require ($new.Replace('--maxfail=0','--maxfail=1')-ceq$old) 'Controller not reversible'
  [IO.File]::WriteAllText($dst,$new,[Text.UTF8Encoding]::new($false))
  $a=[IO.File]::ReadAllBytes($src);$b=[IO.File]::ReadAllBytes($dst);Require ($a.Length-eq$b.Length) 'Controller length changed'
  $delta=@(for($j=0;$j-lt$a.Length;$j++){if($a[$j]-ne$b[$j]){$j}})
  Require ($delta.Count-eq1-and$a[$delta[0]]-eq49-and$b[$delta[0]]-eq48) 'Not exact one ASCII1 to0'
  Verify $dst 'f8bbfbfee3a465f1b521a005a04c6441154186acda20a7102adc747a10737218'
 }else{CopyExact $src $dst $g.helper_sha256[$name]}
 $helpers[$name]=HashFile $dst;$files['tools/'+$name]=$helpers[$name]
}
Require (@($helpers.Keys|Where-Object{$helpers[$_]-ceq$g.helper_sha256[$_]}).Count-eq37) 'Other helpers changed'
$bindings=[ordered]@{
 'app-context.json'=@{path=$appPath;sha=$appSHA};'app-source-freeze.json'=@{path=$app.freeze_manifest;sha=$app.freeze_sha256}
 'app-prepare-receipt.json'=@{path=$app.setup_receipt;sha=$app.setup_receipt_sha256};'app-prepare-final.json'=@{path=$app.final_report;sha=$app.final_report_sha256}
 'app-prepared-input-freeze.json'=@{path=$app.input_freeze;sha=$app.input_freeze_sha256}
 'canonical-guard-context.json'=@{path=$guardPath;sha=$guardSHA};'canonical-guard-receipt.json'=@{path=$g.receipt;sha=$g.receipt_sha256}
 'canonical-toolbundle-freeze.json'=@{path=$g.freeze_manifest;sha=$g.freeze_sha256};'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
}
foreach($n in $bindings.Keys){$v=$bindings[$n];CopyExact $v.path (Join-Path $root ('inputs/'+$n)) $v.sha;$files['inputs/'+$n]=$v.sha}
CopyExact (Join-Path $g.artifact_root gate.json) (Join-Path $art gate.json) $g.gate_sha256;$files['artifacts/gate.json']=$g.gate_sha256
$modules=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);$td=Join-Path $app.bundle_root 'devbrain/tests'
foreach($pat in @('test_terminal*.py','test_workspace*.py','test_cockpit*.py','test_graph*.py','test_tui*.py','test_*tui*.py')){foreach($v in Get-ChildItem -LiteralPath $td -Filter $pat -File){[void]$modules.Add('tests/'+$v.Name)}}
foreach($n in @('test_api_workspace_e2e.py','test_api_worker.py','test_api_panels.py','test_client_runtime.py','test_runtime_pane.py')){Require (Test-Path -LiteralPath (Join-Path $td $n)) 'Required UX module missing';[void]$modules.Add('tests/'+$n)}
Require ($modules.Count-eq28-and$modules.Contains('tests/test_terminal_latency080.py')-and$modules.Contains('tests/test_terminal_workspace_e2e.py')) 'Whole UX module discovery contract differs'
$spec=@{run_id=$run;env=@{LANG='C.UTF-8';LC_ALL='C.UTF-8'};python_launcher=$app.python_launcher;required_artifacts=@('gate.json','regression-source.json','regressions-results.json','controller-report.json','supervisor-report.json','ux-collection.json','ux.xml')
 argv=@('--execute','--phase','ux','--run-id',$run,'--artifact-root',$linuxArt,'--source-root',$app.source_root,'--private-root','/home/piotr/.cache/devbrain-regressions-080','--arcade-dist','/home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1')}
$specPath=Join-Path $art spec.json;NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
$helperPath=Join-Path $root diagnostic-helpers.json
NewJson $helperPath @{schema_version=1;scope='diagnostic_collect_all_not_release_qualification';run_id=$run;helper_sha256=$helpers;baseline_helper_sha256=$g.helper_sha256;changed_helper='run-regressions-080.py';exact_delta='one ASCII --maxfail=1 to --maxfail=0';unchanged_helper_count=37;release_qualified=$false}
$files['diagnostic-helpers.json']=HashFile $helperPath
$freezePath=Join-Path $root diagnostic-input-freeze.json
NewJson $freezePath @{schema_version=1;scope='fresh_prototype_UX_diagnostic_frozen_inputs';run_id=$run;files=$files;helper_sha256=$helpers;source_freeze_sha256=$app.freeze_sha256;application_qualified=$false;release_qualified=$false}
$c=@{
 schema_version=1;scope='fresh_prototype_complete_UX_diagnostic_only';status='prepared_diagnostic_not_run_pending_root_GO';run_id=$run;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=$linuxArt
 windows_tools=$tools;linux_tools=$linuxTools;controller=($linuxTools+'/run-regressions-080.py');controller_sha256=$helpers['run-regressions-080.py'];base_python=$pr.runtime.python_executable;runtime=$pr.runtime
 specification=$specPath;specification_sha256=(HashFile $specPath);input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);frozen_input_count=$files.Count
 helper_sha256=$helpers;baseline_helper_sha256=$g.helper_sha256;helper_count=38;unchanged_helper_count=37;toolbundle_freeze=$helperPath;toolbundle_freeze_sha256=(HashFile $helperPath)
 app_context=$appPath;app_context_sha256=$appSHA;app_run_id=$app.run_id;app_freeze=$app.freeze_manifest;app_freeze_sha256=$app.freeze_sha256;source_freeze_sha256=$app.freeze_sha256;source_root=$app.source_root;python_launcher=$app.python_launcher
 app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$app.setup_receipt_sha256;app_prepare_final_report=$app.final_report;app_prepare_final_report_sha256=$app.final_report_sha256;app_prepare_actual_windows_exec_session=43687;app_prepare_actual_windows_exit_code=0
 guard_context=$guardPath;guard_context_sha256=$guardSHA;guard_receipt=$g.receipt;guard_receipt_sha256=$g.receipt_sha256;guard_instrumentation_only=$true;old_guard_does_not_qualify_new_App=$true
 modules=@($modules|Sort-Object);expected_module_count=28;actual_collection_authoritative=$true;expected_nodeid_count=$null;expected_test_count=$null;normal_conftest=$true;deselection_allowed=$false;skip_allowance=0
 pytest_maxfail=0;diagnostic_only=$true;full_suite_pass=$false;current_backend_passed=$false;current_ui_passed=$false;acceptance_passed=$false;source_final=$false;application_qualified=$false;release_qualified=$false
 timeout_seconds=1800;cleanup_grace_seconds=30;wsl_crash_directory=$g.wsl_crash_directory;actual_windows_exec_session=$null;actual_windows_exit_code=$null;cleanup_complete=$false;linux_workload_started=$false;launch_requires_root_GO=$true;preparation_only=$true
 eight_hour_started=$false;models_auth_or_production_database_requested=$false;created_utc=[DateTime]::UtcNow.ToString('o')
}
$c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=1800;CleanupGraceSeconds=30;WslCrashDirectory=$c.wsl_crash_directory}
Artifacts $files $root;Verify $appPath $appSHA;Verify $oldApp 'd0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c'
foreach($n in $g.helper_sha256.Keys){Verify (RelativeFile $g.windows_tools $n) $g.helper_sha256[$n]}
NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$run;windows_root=$root;source_freeze=$app.freeze_sha256;controller_sha256=$c.controller_sha256;spec_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;files=$files.Count;helpers=38;unchanged=37;modules=28;nodeid_count_assumed=$false;linux_started=$false;release_qualified=$false}|ConvertTo-Json -Depth 4

