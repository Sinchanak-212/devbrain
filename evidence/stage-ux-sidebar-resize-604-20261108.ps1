#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256,[long]$GuardActualWindowsExecSession,[string]$CandidateContextSha256)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only for UX381 execution metadata; this script never launches a process.';return}
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



$masterPath=Join-Path $workspace 'evidence/080-ux-sidebar-resize-604-templates-20261108.json';$masterSHA='c6e226ee4f4e232f08b91d123bd5514391aeb1dd87badac9ad551b7537fe8b0e';Verify $masterPath $masterSHA;$m=ReadMap $masterPath
foreach($p in $m.files.Keys){Verify $p $m.files[$p]}
$contextTemplate=Join-Path $workspace 'evidence/ux-sidebar-resize-604-templates-20261108/ux.context.template.json';$specTemplate=Join-Path $workspace 'evidence/ux-sidebar-resize-604-templates-20261108/ux.spec.template.json'
$c=ReadMap $contextTemplate;$spec=ReadMap $specTemplate
$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json';$guardSHA=$GuardContextSha256;Verify $guardPath $guardSHA;$g=ReadMap $guardPath
$receiptSHA=$GuardReceiptSha256;$reportSHA=$GuardFinalReportSha256
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$GuardActualWindowsExecSession-gt0-and$g.actual_windows_exec_session-eq$GuardActualWindowsExecSession-and$g.actual_test_count-eq604-and$g.cleanup_complete-eq$true-and$g.run_id-cmatch'^guards-sidebar-resize080-[0-9]{8}T[0-9]{6}Z$') 'New604 actual exit missing'
Verify $g.receipt $receiptSHA;Verify $g.final_report $reportSHA;Require ($g.receipt_sha256-ceq$receiptSHA-and$g.final_report_sha256-ceq$reportSHA) 'Guard completed proof differs'
$r=ReadMap $g.receipt
Require ($r.passed-eq$true-and$r.controller_exit_verified-eq$true-and$r.supervisor_exit_verified-eq$true-and$r.child_returncode-eq0-and$r.supervisor_returncode-eq0-and$r.cleanup_complete-eq$true-and$r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.scope_empty_verified-eq$true-and$r.scope_cleanup_grace_seconds-ge30-and$r.cleanup_grace_seconds-ge30-and@($r.errors).Count-eq0-and$r.sleep_inhibition.restored-eq$true) 'Guard cleanup incomplete'
Artifacts $r.artifact_sha256 $g.artifact_root;Verify $g.freeze_manifest $g.freeze_sha256;$f=ReadMap $g.freeze_manifest
Require ($f.files.Count-eq56-and$f.helper_files.Count-eq38-and$f.test_modules.Count-eq12) 'Wrong current guard bundle'
Artifacts $f.files $g.windows_root;SameMap $f.helper_files $g.helper_sha256;SameMap $f.helper_files $g.reviewed_helper_sha256;SameMap $f.helper_files $c.expected_unchanged_helper_sha256
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json';$appSHA='d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c';Verify $appPath $appSHA;$app=ReadMap $appPath
Require ($app.status-ceq'prepared_passed'-and$app.actual_windows_exit_code-eq0-and$app.run_id-ceq$m.source_snapshot-and$app.freeze_sha256-ceq$m.source_freeze_sha256-and$app.source_root-ceq$c.source_root-and$app.python_launcher-ceq$c.python_launcher-and$g.source_root-ceq$app.source_root-and$g.python_launcher-ceq$app.python_launcher) 'Current prepared source differs'
Verify $app.freeze_manifest $m.source_freeze_sha256;Verify $app.setup_receipt $m.app_prepare_receipt_sha256;$af=ReadMap $app.freeze_manifest
Require ($af.files.Count-eq209-and@($af.files.Keys|Where-Object{$_-clike'devbrain/*'}).Count-eq198) 'Source inventory differs';Artifacts $af.files $app.bundle_root
$buildPath=$c.candidate_build_context;$buildSHA=$CandidateContextSha256;Verify $buildPath $buildSHA;$b=ReadMap $buildPath
Require ($b.actual_windows_exit_code-eq0-and$b.cleanup_complete-eq$true-and$b.source_freeze_sha256-ceq$m.source_freeze_sha256) 'Actual v8 build absent'
Verify $b.observation $b.observation_sha256;Artifacts $b.output_sha256 $b.windows_root
Require ($g.updater_sha256-ceq$b.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py']-and$g.candidate_zip_sha256-ceq$b.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip']-and$g.candidate_manifest_sha256-ceq$b.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json']) 'Guard qualified a different candidate'
Verify $c.runtime_fixture_report $c.runtime_fixture_report_sha256;$fixtures=ReadMap $c.runtime_fixture_report
Require ($fixtures.passed-eq$true-and$fixtures.safe_next_workload-eq$true-and$fixtures.fixture_oracles_passed-eq5-and$fixtures.application_qualification-eq$false) 'Runtime-only fixture proof incomplete'
Verify $fixtures.guard_receipt $fixtures.guard_receipt_sha256;$fr=ReadMap $fixtures.guard_receipt;$fa=Split-Path $fixtures.guard_receipt -Parent;Artifacts $fr.artifact_sha256 $fa;$fs=ReadMap (Join-Path $fa 'regression-source.json')
foreach($n in @('supervise-080.py','run-supervised-080.ps1','qualification-power-080.ps1','validate-stability-080.py','test_supervision080_fixture.py','run-parent-loss080.ps1','watch-parent-loss080.py')){Require ($fs.guard_sources.helper_sha256[$n]-ceq$f.helper_files[$n]) 'Fixture runtime instrumentation changed'}
Require ($c.expected_nodeid_count-eq381-and$c.expected_module_count-eq28-and$c.modules.Count-eq28-and$c.skip_allowance-eq0-and$c.deselection_allowed-eq$false-and$c.normal_conftest-eq$true-and$spec.argv.Count-eq13-and$spec.argv[0]-ceq'--execute'-and$spec.argv[1]-ceq'--phase'-and$spec.argv[2]-ceq'ux'-and$spec.argv[4]-ceq'<FRESH_UX_RUN_ID>'-and$spec.argv[6]-ceq'<FRESH_LINUX_ARTIFACT_ROOT>'-and$spec.argv[8]-ceq$app.source_root-and$spec.python_launcher-ceq$app.python_launcher) 'Whole UX contract differs'
SameMap $spec.env @{LANG='C.UTF-8';LC_ALL='C.UTF-8'}
Require (@(Compare-Object @($spec.required_artifacts|Sort-Object) @($c.required_artifacts|Sort-Object)).Count-eq0-and$spec.required_artifacts.Count-eq7) 'UX artifact contract differs'
$contextPath=Join-Path $workspace 'evidence/080-ux-sidebar-resize-active-context-20261108.json';Require (-not(Test-Path -LiteralPath $contextPath)) 'Do not overwrite prior UX context'
$run='ux-sidebar-resize080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root exists';NoReparse $root
foreach($sub in @('artifacts','inputs')){[void][IO.Directory]::CreateDirectory((Join-Path $root $sub));PathProof (Join-Path $root $sub)}
$art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs';$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt="$linuxRoot/artifacts"
$shared=[ordered]@{
 'template-master.json'=@{path=$masterPath;sha=$masterSHA};'context-template.json'=@{path=$contextTemplate;sha=$m.files[$contextTemplate]};'spec-template.json'=@{path=$specTemplate;sha=$m.files[$specTemplate]};'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
 'guard-context.json'=@{path=$guardPath;sha=$guardSHA};'guard-receipt.json'=@{path=$g.receipt;sha=$receiptSHA};'guard-final-report.json'=@{path=$g.final_report;sha=$reportSHA};'toolbundle-freeze.json'=@{path=$g.freeze_manifest;sha=$g.freeze_sha256}
 'app-context.json'=@{path=$appPath;sha=$appSHA};'source-freeze.json'=@{path=$app.freeze_manifest;sha=$app.freeze_sha256};'app-prepare-receipt.json'=@{path=$app.setup_receipt;sha=$app.setup_receipt_sha256}
 'candidate-v8-context.json'=@{path=$buildPath;sha=$buildSHA};'candidate-v8-observation.json'=@{path=$b.observation;sha=$b.observation_sha256};'runtime-five594.json'=@{path=$c.runtime_fixture_report;sha=$c.runtime_fixture_report_sha256}
}
$files=[ordered]@{};foreach($name in $shared.Keys){$s=$shared[$name];CopyExact $s.path (Join-Path $inputs $name) $s.sha;$files["inputs/$name"]=$s.sha}
CopyExact (Join-Path $g.artifact_root 'gate.json') (Join-Path $art 'gate.json') $g.gate_sha256;$files['artifacts/gate.json']=$g.gate_sha256
$spec.run_id=$run;$spec.argv[4]=$run;$spec.argv[6]=$linuxArt
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files['artifacts/spec.json']=HashFile $specPath
$freezePath=Join-Path $root 'prepared-input-freeze.json';NewJson $freezePath @{schema_version=1;scope='devbrain_current_sidebar_resize_ux_inputs';run_id=$run;files=$files;helper_sha256=$f.helper_files;source_freeze_sha256=$app.freeze_sha256;guard_receipt_sha256=$receiptSHA;linux_workload_started=$false}
$c.status='prepared_not_run_pending_root_serial_handoff';$c.phase='ux';$c.run_id=$run;$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=$art;$c.linux_artifact_root=$linuxArt
$c.windows_tools=$g.windows_tools;$c.linux_tools=$g.linux_tools;$c.controller=$g.linux_tools+'/run-regressions-080.py';$c.controller_sha256=$f.helper_files['run-regressions-080.py'];$c.base_python=$g.base_python;$c.runtime=(ReadMap (Join-Path $art 'gate.json')).runtime
$c.specification=$specPath;$c.specification_sha256=HashFile $specPath;$c.input_freeze=$freezePath;$c.input_freeze_sha256=HashFile $freezePath;$c.input_file_count=$files.Count;$c.frozen_input_count=$files.Count
$c.helper_sha256=$f.helper_files;$c.reviewed_helper_sha256=$f.helper_files;$c.helper_file_count=38;$c.toolbundle_freeze=$g.freeze_manifest;$c.toolbundle_freeze_sha256=$g.freeze_sha256
$c.app_snapshot=$app.run_id;$c.app_run_id=$app.run_id;$c.app_freeze=$app.freeze_manifest;$c.app_freeze_sha256=$app.freeze_sha256;$c.app_file_count=198;$c.app_prepare_actual_windows_exit_code=0
$c.guard_context=$guardPath;$c.guard_context_sha256=$guardSHA;$c.guard_receipt=$g.receipt;$c.guard_receipt_sha256=$receiptSHA;$c.guard_final_report=$g.final_report;$c.guard_final_report_sha256=$reportSHA;$c.guard_actual_windows_exit_code=0;$c.guard_test_count=604;$c.guard_module_count=12;$c.gate_sha256=$g.gate_sha256
$c.candidate_build_context_sha256=$buildSHA;$c.candidate_directory=$b.candidate_directory;$c.candidate_updater_sha256=$g.updater_sha256;$c.candidate_zip_sha256=$g.candidate_zip_sha256;$c.candidate_manifest_sha256=$g.candidate_manifest_sha256;$c.candidate_build_observation_sha256=$b.observation_sha256
$c.latest_fixture_report=$c.runtime_fixture_report;$c.latest_fixture_report_sha256=$c.runtime_fixture_report_sha256;$c.latest_fixture_count=5;$c.latest_fixture_passed=$true;$c.fixture_qualification_scope='unchanged_runtime_instrumentation_only';$c.fixture_application_qualification=$false
$c.wsl_crash_directory=$g.wsl_crash_directory;$c.materialization_required=$false;$c.materialization_prerequisites=@('Root serial handoff after ongoing backend/copy cleanup');$c.preparation_only=$true;$c.requires_root_serial_handoff=$true;$c.launch_requires_explicit_serial_handoff=$true;$c.actual_windows_exit_code=$null;$c.cleanup_complete=$false;$c.receipt_sha256=$null
$c.current_backend_actual_pass=$false;$c.full_suite_attestation=$null;$c.full_suite_attestation_sha256=$null;$c.application_qualified=$false;$c.is_frozen_execution_spec=$true;$c.source_final=$false;$c.expected_test_count=381
$c.created_utc=[DateTimeOffset]::UtcNow.ToString('o');$c.template_master=$masterPath;$c.template_master_sha256=$masterSHA;$c.original_template_context=$contextTemplate;$c.original_template_context_sha256=$m.files[$contextTemplate]
$c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$c.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory=$c.wsl_crash_directory}
Artifacts $files $root;foreach($name in $f.helper_files.Keys){Verify (Join-Path $g.windows_tools $name) $f.helper_files[$name]};Verify $guardPath $guardSHA
NewJson $contextPath $c
@{context=$contextPath;context_sha256=(HashFile $contextPath);root=$root;run_id=$run;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;files=$files.Count;helpers=38;modules=28;expected_cases=381;launch_permitted=$false;linux_workload_started=$false}|ConvertTo-Json
