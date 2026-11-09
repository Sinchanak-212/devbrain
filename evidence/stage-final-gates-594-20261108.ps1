[CmdletBinding()]
param(
 [switch]$Stage,
 [string]$FixtureReport,
 [string]$FixtureReportSha256
)
# Filesystem preparation only. No processes, services, accounts, or model requests.
if(-not $Stage){Write-Output 'NOT_RUN: supply -Stage and the actual five-fixture report with its SHA256. This script never launches workloads.';return}
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
$masterPath=Join-Path $workspace 'evidence/080-finalsource-gate-templates-594-deploy-20261108.json'
$masterSHA='610110f2c035789cc1ef6bbc47c0046d689dc161ee66362798563cce04c57ab9'
$guardSHA='20ec03224dab3da992557d5c8f5a5ddf28dd2f9ed6b8f85e4a2dd5a80e960c82'
$guardFreezeSHA='d9d0145a00ea7cb27f79305ac5655938f80fb7571572f44317b94cbdca711bb9'
$sourceSHA='5ea43988e1943c783e802acbe5a39fdfcc3318d41655ed244716a69a0d71b28f'
$manifestSHA='4edb72e49dbf851d7ccf3597d9b240c105ff0547218b2b2c022dac7233763d8c'
$fixtureExpected=Join-Path $workspace 'evidence/080-controlled-fixtures-deploy-final-20261108.json'
Require ([IO.Path]::GetFullPath($FixtureReport) -ceq $fixtureExpected) 'Only the current final fixture report is admissible'
Verify $FixtureReport $FixtureReportSha256
Verify $masterPath $masterSHA
$master=ReadMap $masterPath
$templates=[ordered]@{}
foreach($name in @('fullbackend','native','copilot','ollama20','frontend')){
 $path=Join-Path $master.template_root "$name.template.json"
 Verify $path $master.files["$name.template.json"]
 $templates[$name]=ReadMap $path
}
$base=$templates.fullbackend
$guardContext=ReadMap $base.final_guard_binding.context
Require ($guardContext.status -ceq 'passed' -and $guardContext.actual_windows_exit_code -eq 0 -and $guardContext.actual_test_count -eq 594) 'Actual guard run incomplete'
Verify $guardContext.final_report '0ecfdd12104145b7b44f0fe7fdc483edebd2a3efbac4f4e906b2ffe092229453'
$guardFinal=ReadMap $guardContext.final_report
Require ($guardFinal.tests -eq 594 -and $guardFinal.modules -eq 12 -and $guardFinal.helpers -eq 38 -and $guardFinal.failures -eq 0 -and $guardFinal.errors -eq 0 -and $guardFinal.skipped -eq 0) 'Guard collection/result mismatch'
$guardReceiptPath=Join-Path $guardContext.artifact_root 'receipt.json'
$guardReceipt=GoodReceipt $guardReceiptPath $guardSHA
Verify $guardContext.toolbundle_freeze $guardFreezeSHA
$toolFreeze=ReadMap $guardContext.toolbundle_freeze
Require ($toolFreeze.helper_files.Count -eq 38 -and $toolFreeze.files.Count -eq 55) 'Tool freeze inventory mismatch'
ArtifactHashes $toolFreeze.files $guardContext.windows_root
SameMap $toolFreeze.helper_files $base.final_guard_binding.helper_sha256
$helperMap=$toolFreeze.helper_files
foreach($name in $helperMap.Keys){Verify (Join-Path $guardContext.windows_tools $name) $helperMap[$name]}
$guardSourcePath=Join-Path $guardContext.artifact_root 'regression-source.json'
$guardSource=ReadMap $guardSourcePath
SameMap $guardSource.guard_sources.helper_sha256 $helperMap
foreach($t in $templates.Values){SameMap $t.final_guard_binding.helper_sha256 $helperMap; Require ($t.source_freeze_sha256 -ceq $sourceSHA -and $t.python_launcher -ceq $base.python_launcher) 'Template source/runtime divergence'}

# Verify the real current application and completed evidence. No credential files are read.
$app=ReadMap (Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json')
Require ($app.run_id -ceq 'app080-20261108T160614Z' -and $app.status -ceq 'prepared_passed' -and $app.actual_windows_exit_code -eq 0) 'Current application preparation is not complete'
Verify $base.source_freeze $sourceSHA
$source=ReadMap $base.source_freeze
$appFiles=@($source.files.Keys | Where-Object {$_ -clike 'devbrain/*'})
Require ($appFiles.Count -eq 198) 'Application file count changed'
foreach($name in $appFiles){Verify (RelativeFile $app.bundle_root $name) $source.files[$name]}
Verify $base.app_prepare_receipt $base.app_prepare_receipt_sha256
$prep=ReadMap $base.app_prepare_receipt
Require ($prep.passed -eq $true) 'Application setup receipt failed'
$uxReceipt=GoodReceipt $base.ux_binding.receipt $base.ux_binding.receipt_sha256
$uxContext=ReadMap $base.ux_binding.context
Require ($uxContext.actual_windows_exit_code -eq 0) 'UX Windows process did not exit successfully'
$uiReceipt=GoodReceipt $base.ui_binding.receipt $base.ui_binding.receipt_sha256
Verify $base.ui_binding.final_report $base.ui_binding.final_report_sha256
$ui=ReadMap $base.ui_binding.final_report
Require ($ui.actual_windows_exit_code -eq 0 -and $ui.agent_acceptance_passed -eq $true -and $ui.five_tasks_passed -eq $true -and $ui.three_real_geometries_passed -eq $true -and $ui.oauth_sync_and_release_passed -eq $true -and $ui.cleanup_complete -eq $true) 'Final UI/OAuth cleanup incomplete'
Require ($ui.source_freeze_sha256 -ceq $sourceSHA -and $ui.human_acceptance_passed -eq $false) 'UI source or operator binding mismatch'
Verify $base.candidate_binding.observation $base.candidate_binding.observation_sha256
$build=ReadMap $base.candidate_binding.context
Require ($build.actual_windows_exit_code -eq 0 -and $build.cleanup_complete -eq $true) 'Candidate build did not complete'
foreach($name in $base.candidate_binding.output_sha256.Keys){
 Verify (Join-Path $base.candidate_binding.candidate_directory ([IO.Path]::GetFileName($name))) $base.candidate_binding.output_sha256[$name]
}

# All five fresh oracles must already be final. Expected negative raw verdicts remain negative.
$f=ReadMap $FixtureReport
Require ($f.schema_version -eq 1 -and $f.scope -ceq 'devbrain_latest_five_runtime_supervision_fixtures_final' -and $f.status -ceq 'passed_runtime_supervision_only') 'Wrong fixture report kind/status'
foreach($key in @('passed','safe_next_workload','runtime_supervision_qualification_passed','all_actual_root_tool_exits_verified','all_actual_windows_drivers_exited','all_owned_scopes_empty_verified','all_quiet_windows_at_least_30_seconds','boot_unchanged','power_unchanged','sleep_restored','negative_raw_failures_preserved')){
 Require ($f[$key] -eq $true) "Incomplete fixture proof: $key"
}
foreach($key in @('application_qualification','ui_qualification_passed','software_qualification_passed','release_qualified','historical_results_pooled','new_native_failure')){
 Require ($f[$key] -eq $false) "Invalid fixture qualification claim: $key"
}
Require ($f.fixture_count -eq 5 -and $f.fixture_oracles_passed -eq 5 -and $f.helper_count -eq 38 -and $f.guard_case_count -eq 594 -and $f.guard_module_count -eq 12) 'Fixture count/tooling mismatch'
Require ($f.guard_receipt_sha256 -ceq $guardSHA -and $f.toolbundle_freeze_sha256 -ceq $guardFreezeSHA -and $f.source_freeze_sha256 -ceq $sourceSHA -and $f.source_run_id -ceq $app.run_id -and $f.app_prepare_receipt_sha256 -ceq $base.app_prepare_receipt_sha256) 'Fixture source/guard binding mismatch'
Verify $f.fixture_manifest $manifestSHA
$fixtureManifest=ReadMap $f.fixture_manifest
SameMap $fixtureManifest.helper_sha256 $helperMap
Require ($f.fixture_manifest_sha256 -ceq $manifestSHA -and @($f.actual_trials).Count -eq 5) 'Missing final trials'
$seen=@{}
$expectedDriver=@{normal=0;nonzero=1;timeout=1;orphan=1;'parent-loss'=0}
$expectedController=@{normal=0;nonzero=7;timeout=-15;orphan=0;'parent-loss'=-15}
$oracleInputs=[ordered]@{}
foreach($trial in $f.actual_trials){
 $mode=[string]$trial.mode
 Require ($expectedDriver.ContainsKey($mode) -and -not $seen.ContainsKey($mode)) 'Unknown or duplicate fixture mode'
 $seen[$mode]=$true
 $scenario=@($fixtureManifest.scenarios | Where-Object {$_.mode -ceq $mode})
 Require ($scenario.Count -eq 1 -and $trial.run_id -ceq $scenario[0].run_id -and $trial.artifact_root -ceq $scenario[0].artifact_root) 'Fixture scenario identity mismatch'
 Require ($trial.root_tool_actual_exit_code -eq 0 -and $trial.root_exec_session -gt 0 -and $trial.actual_windows_driver_exit -eq $expectedDriver[$mode] -and $trial.controller_returncode -eq $expectedController[$mode]) 'Fixture actual process exits mismatch'
 Require ($trial.driver_actual_exit_verified -eq $true -and $trial.windows_driver.pid -gt 0 -and -not [string]::IsNullOrEmpty($trial.windows_driver.started_utc)) 'Missing retained driver identity'
 foreach($key in @('passed','safe_next_workload','scope_empty_verified')){Require ($trial[$key] -eq $true) "Trial not complete: $mode/$key"}
 Require ($trial.scope_quiet_seconds -ge 30) 'Insufficient scope observation'
 if($mode -ceq 'parent-loss'){Require ($trial.external_post_oracle_exit_seconds -ge 30 -and $trial.raw_receipt_present -eq $false) 'Parent-loss observation incomplete'}
 else{Require ($trial.outer_quiet_seconds -ge 30 -and $trial.raw_receipt_present -eq $true) 'Outer observation incomplete'}
 if($mode -ceq 'normal'){Require ($trial.raw_receipt_passed -eq $true -and $trial.raw_supervisor_passed -eq $true) 'Normal fixture raw failure'}
 else{Require ($trial.raw_supervisor_passed -eq $false -and $trial.raw_receipt_passed -ne $true) 'Negative fixture raw result was rewritten'}
 $expectedOracle=Join-Path $trial.artifact_root $(if($mode -ceq 'parent-loss'){'fixture-oracle-audit.json'}else{'fixture-oracle.json'})
 Require ($trial.oracle -ceq $expectedOracle) 'Oracle path is not inside the exact scenario root'
 Verify $trial.oracle $trial.oracle_sha256
 $oracle=ReadMap $trial.oracle
 $processorSHA=if($mode -ceq 'parent-loss'){'d30d9f3bb629084ace0fb19ebef9bdd660f2f9f107b8ff2fcf53311cddf169e1'}else{'20cffa1a809c4ab6856475f026c4f10a244abff12450d2f6b2aac28d3e9005a5'}
 Require ($oracle.passed -eq $true -and $oracle.safe_next_workload -eq $true -and $oracle.processor_sha256 -ceq $processorSHA -and $trial.processor_sha256 -ceq $processorSHA -and $oracle.guard_receipt_sha256 -ceq $guardSHA -and $oracle.helper_count_verified -eq 38) 'Oracle binding incomplete'
 Require ($oracle.run_id -ceq $trial.run_id -and $oracle.root_exec_session -eq $trial.root_exec_session -and $oracle.actual_windows_driver_exit -eq $trial.actual_windows_driver_exit -and $oracle.driver_actual_exit_verified -eq $true) 'Oracle process result diverged'
 ArtifactHashes $oracle.artifact_sha256 $trial.artifact_root
 $oracleInputs["fixture-$mode-oracle.json"]=@{path=$trial.oracle;sha=$trial.oracle_sha256}
}
Require ($seen.Count -eq 5) 'Five unique trials required'

# No new directory or file was created before the complete admission above.
$sharedInputs=[ordered]@{
 'template-master.json'=@{path=$masterPath;sha=$masterSHA}
 'toolbundle-freeze.json'=@{path=$guardContext.toolbundle_freeze;sha=$guardFreezeSHA}
 'guard-receipt.json'=@{path=$guardReceiptPath;sha=$guardSHA}
 'guard-final-report.json'=@{path=$guardContext.final_report;sha='0ecfdd12104145b7b44f0fe7fdc483edebd2a3efbac4f4e906b2ffe092229453'}
 'guard-source.json'=@{path=$guardSourcePath;sha=(HashFile $guardSourcePath)}
 'source-freeze.json'=@{path=$base.source_freeze;sha=$sourceSHA}
 'app-prepare-receipt.json'=@{path=$base.app_prepare_receipt;sha=$base.app_prepare_receipt_sha256}
 'ux-receipt.json'=@{path=$base.ux_binding.receipt;sha=$base.ux_binding.receipt_sha256}
 'ui-receipt.json'=@{path=$base.ui_binding.receipt;sha=$base.ui_binding.receipt_sha256}
 'ui-final-report.json'=@{path=$base.ui_binding.final_report;sha=$base.ui_binding.final_report_sha256}
 'candidate-build-observation.json'=@{path=$base.candidate_binding.observation;sha=$base.candidate_binding.observation_sha256}
 'candidate-manifest.json'=@{path=(Join-Path $base.candidate_binding.candidate_directory 'devbrain-update-0.8.0-manifest.json');sha=$base.candidate_binding.manifest_sha256}
 'controlled-fixtures-final.json'=@{path=$FixtureReport;sha=$FixtureReportSha256}
 'controlled-fixtures-manifest.json'=@{path=$f.fixture_manifest;sha=$manifestSHA}
 'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
}
foreach($key in $oracleInputs.Keys){$sharedInputs[$key]=$oracleInputs[$key]}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$created=[ordered]@{}
foreach($name in $templates.Keys){
 $t=$templates[$name]
 $runId="$name-deploy-final080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
 $root=Join-Path $physicalBase $runId
 $linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
 Require (-not (Test-Path -LiteralPath $root)) 'Fresh qualification root already exists'
 NoReparse $root
 [void][IO.Directory]::CreateDirectory($root);Physical $root
 $artifacts=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs'
 [void][IO.Directory]::CreateDirectory($artifacts);Physical $artifacts
 [void][IO.Directory]::CreateDirectory($inputs);Physical $inputs
 $linuxArtifacts="$linuxRoot/artifacts"
 $specText=($t.specification_template | ConvertTo-Json -Depth 25).Replace('<RUN_ID>',$runId).Replace('<LINUX_ARTIFACT_ROOT>',$linuxArtifacts)
 Require ($specText -notmatch '<RUN_ID>|<LINUX_ARTIFACT_ROOT>') 'Unresolved specification placeholder'
 $spec=$specText | ConvertFrom-Json -AsHashtable -DateKind String
 $specPath=Join-Path $artifacts 'spec.json';NewJson $specPath $spec
 $files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
 $gateSource=Join-Path $guardContext.artifact_root 'gate.json'
 CopyExact $gateSource (Join-Path $artifacts 'gate.json') $base.runtime_gate_sha256
 $files['artifacts/gate.json']=$base.runtime_gate_sha256
 foreach($key in $sharedInputs.Keys){
  $item=$sharedInputs[$key];$target=Join-Path $inputs $key
  $isWorkspace=$item.path.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)
  CopyExact $item.path $target $item.sha $isWorkspace
  $files["inputs/$key"]=$item.sha
 }
 $templatePath=Join-Path $master.template_root "$name.template.json"
 CopyExact $templatePath (Join-Path $inputs 'template.json') $master.files["$name.template.json"] $true
 $files['inputs/template.json']=$master.files["$name.template.json"]
 $freezePath=Join-Path $root 'prepared-input-freeze.json'
 NewJson $freezePath ([ordered]@{schema_version=1;scope='devbrain_prepared_final_gate_inputs';run_id=$runId;files=$files;helper_sha256=$helperMap;source_freeze_sha256=$sourceSHA;guard_receipt_sha256=$guardSHA;controlled_fixtures_report_sha256=$FixtureReportSha256;linux_workload_started=$false})
 $contextPath=Join-Path $workspace "evidence/080-$name-deploy-active-context-20261108.json"
 $ctx=[ordered]@{
  schema_version=1;scope='devbrain_final_gate_context';status='prepared_not_run_pending_root_serial_handoff';phase=$name;run_id=$runId
  windows_root=$root;linux_root=$linuxRoot;artifact_root=$artifacts;linux_artifact_root=$linuxArtifacts
  windows_tools=$guardContext.windows_tools;linux_tools=$guardContext.linux_tools;controller=($guardContext.linux_tools+'/'+$t.controller_basename);controller_sha256=$helperMap[$t.controller_basename]
  specification=$specPath;specification_sha256=(HashFile $specPath);input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath)
  helper_sha256=$helperMap;reviewed_helper_sha256=$helperMap;helper_file_count=38
  toolbundle_freeze=$guardContext.toolbundle_freeze;toolbundle_freeze_sha256=$guardFreezeSHA
  guard_context=$base.final_guard_binding.context;guard_receipt=$guardReceiptPath;guard_receipt_sha256=$guardSHA;guard_test_count=594;guard_module_count=12;guard_actual_windows_exit_code=0
  base_python=$base.base_python;python_launcher=$base.python_launcher;source_root=$base.source_root;runtime=$guardReceipt.runtime
  source_final=$true;app_snapshot=$app.run_id;app_run_id=$app.run_id;app_freeze=$base.source_freeze;source_freeze_sha256=$sourceSHA;app_freeze_sha256=$sourceSHA;app_file_count=198
  app_prepare_receipt=$base.app_prepare_receipt;app_prepare_receipt_sha256=$base.app_prepare_receipt_sha256;gate_sha256=$base.runtime_gate_sha256
  final_ux_receipt_sha256=$base.ux_binding.receipt_sha256;final_ui_receipt_sha256=$base.ui_binding.receipt_sha256;final_ui_report_sha256=$base.ui_binding.final_report_sha256
  candidate_directory=$base.candidate_binding.candidate_directory;candidate_updater_sha256=$base.candidate_binding.updater_sha256;candidate_zip_sha256=$base.candidate_binding.zip_sha256;candidate_manifest_sha256=$base.candidate_binding.manifest_sha256;candidate_build_observation_sha256=$base.candidate_binding.observation_sha256
  timeout_seconds=$t.timeout_seconds;cleanup_grace_seconds=30;wsl_crash_directory=$guardContext.wsl_crash_directory;private_root='/home/piotr/.cache/devbrain-regressions-080'
  acceptance=$t.acceptance;required_artifacts=$spec.required_artifacts;launch_permitted=$false;requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true
  new_controlled_fixtures_passed=$true;latest_fixture_passed=$true;latest_fixture_count=5;latest_fixture_report=$FixtureReport;latest_fixture_report_sha256=$FixtureReportSha256
  controlled_fixture_handoff=$FixtureReport;controlled_fixture_handoff_sha256=$FixtureReportSha256
  linux_workload_started=$false;preparation_only=$true;release_qualified=$false;historical_results_reused=$false;credentials_read_during_staging=$false
  source_and_helper_hashes_verified=$true;canonical_handle_proofs_passed=$true;destination_reparse_checks_passed=$true
  template_path=$templatePath;template_sha256=$master.files["$name.template.json"];prepared_utc=[DateTime]::UtcNow.ToString('o')
 }
 if($name -ceq 'fullbackend'){$ctx.expected_test_count=1508;$ctx.full_test_directory='tests';$ctx.skip_allowance=0;$ctx.deselection_allowed=$false;$ctx.collection_authoritative=$true;$ctx.attestation_required_after_actual_receipt=$true}
 # Recheck copied bytes and referenced immutable tools before publishing the context.
 ArtifactHashes $files $root
 foreach($helper in $helperMap.Keys){Verify (Join-Path $guardContext.windows_tools $helper) $helperMap[$helper]}
 Verify $FixtureReport $FixtureReportSha256
 NewJson $contextPath $ctx
 $created[$name]=@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$runId;specification=$specPath;specification_sha256=$ctx.specification_sha256;input_freeze_sha256=$ctx.input_freeze_sha256}
}
$output=Join-Path $workspace 'evidence/080-five-final-deploy-gate-contexts-20261108.json'
NewJson $output ([ordered]@{schema_version=1;scope='devbrain_five_final_gate_contexts';status='prepared_not_run_pending_root_serial_handoff';source_snapshot=$app.run_id;source_freeze_sha256=$sourceSHA;helper_count=38;guard_test_count=594;guard_receipt_sha256=$guardSHA;controlled_fixtures_report=$FixtureReport;controlled_fixtures_report_sha256=$FixtureReportSha256;execution_order=@('fullbackend','native','copilot','ollama20','frontend');contexts=$created;linux_workload_started=$false;launch_permitted=$false;release_qualified=$false})
[ordered]@{master=$output;sha256=(HashFile $output);contexts=$created;linux_workload_started=$false}|ConvertTo-Json -Depth 8

