[CmdletBinding()]
param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256)
# Windows filesystem preparation only; no test/service/model process is launched.
if(-not $Stage){Write-Output 'NOT_RUN: actual604 guard context, receipt and final-report SHAs are required. New UI is pending, not presumed passed.';return}
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

$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
Verify $guardPath $GuardContextSha256
$g=ReadMap $guardPath
Require ($g.status -ceq 'passed' -and $g.actual_windows_exit_code -eq 0 -and $g.actual_test_count -eq 604 -and $g.helper_file_count -eq 38 -and $g.guard_module_count -eq 12) 'Actual604 qualification is incomplete'
Require ($g.run_id -cmatch '^guards-sidebar-resize080-[0-9]{8}T[0-9]{6}Z$') 'Unexpected guard run'
$receipt=GoodReceipt (Join-Path $g.artifact_root 'receipt.json') $GuardReceiptSha256
Require ($receipt.run_id -ceq $g.run_id -and $g.receipt_sha256 -ceq $GuardReceiptSha256) 'Guard receipt run mismatch'
Verify $g.final_report $GuardFinalReportSha256
$guardFinal=ReadMap $g.final_report
Require ($guardFinal.run_id -ceq $g.run_id -and $guardFinal.tests -eq 604 -and $guardFinal.modules -eq 12 -and $guardFinal.helpers -eq 38 -and $guardFinal.failures -eq 0 -and $guardFinal.errors -eq 0 -and $guardFinal.skipped -eq 0) 'Guard result mismatch'
$results=ReadMap (Join-Path $g.artifact_root 'regressions-results.json')
Require ($results.phase -ceq 'guards' -and $results.run_id -ceq $g.run_id -and $results.counts.collected -eq 604 -and $results.counts.passed -eq 604 -and $results.counts.failures -eq 0 -and $results.counts.errors -eq 0 -and $results.counts.skipped -eq 0 -and $results.modules.Count -eq 12) 'Raw guard collection/results mismatch'
Require ($results.counts.missing -eq 0 -and $results.counts.duplicates -eq 0 -and $results.counts.unexpected_skips -eq 0 -and $results.counts.expected_skips.Count -eq 0) 'Guard collection has missing, duplicate or skipped cases'
Verify $g.freeze_manifest $g.freeze_sha256
$freeze=ReadMap $g.freeze_manifest
Require ($freeze.files.Count -eq 56 -and $freeze.helper_files.Count -eq 38 -and $freeze.test_modules.Count -eq 12) 'Tool freeze inventory mismatch'
ArtifactHashes $freeze.files $g.windows_root
SameMap $freeze.helper_files $g.reviewed_helper_sha256
SameMap $freeze.helper_files $g.helper_sha256
$guardSource=ReadMap (Join-Path $g.artifact_root 'regression-source.json')
SameMap $guardSource.guard_sources.helper_sha256 $freeze.helper_files

$sourceSHA='ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'
$prepareSHA=$g.app_prepare_receipt_sha256
Require ($prepareSHA -cmatch '^[0-9a-f]{64}$') 'Guard must bind actual new preparation receipt'
Require ($g.app_run_id -ceq 'app080-20261108T222731Z' -and $g.app_freeze_sha256 -ceq $sourceSHA -and $g.app_prepare_receipt_sha256 -ceq $prepareSHA) 'Guard did not qualify the new prepared source'
Verify $g.app_freeze $sourceSHA
Verify $g.app_prepare_receipt $prepareSHA
$appPath=Join-Path $workspace 'evidence/080-app-ux-snapshot-active-context.json'
SourceProof $appPath
$app=ReadMap $appPath
Require ($app.run_id -ceq $g.app_run_id -and $app.status -ceq 'prepared_passed' -and $app.actual_windows_exit_code -eq 0 -and $app.python_launcher -ceq $g.python_launcher -and $app.source_root -ceq $g.source_root -and $app.setup_receipt_sha256 -ceq $prepareSHA -and $app.freeze_sha256 -ceq $sourceSHA) 'Current app preparation differs from guard source'
Require ($app.qualified_package_pin_count -eq 59 -and $app.pins_unchanged -eq $true -and $app.linux_source_matches_freeze -eq $true) 'Qualified dependencies or source changed'
$appFreeze=ReadMap $g.app_freeze
Require ($appFreeze.files.Count -eq 209 -and $appFreeze.app_files -eq 198) 'App inventory mismatch'
ArtifactHashes $appFreeze.files $app.bundle_root

# These unchanged process-supervision fixtures remain evidence only for their
# own source160614/594 instrument; no new application result is inferred.
$fixturePath=Join-Path $workspace 'evidence/080-controlled-fixtures-deploy-final-20261108.json'
$fixtureSHA='d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c'
Verify $fixturePath $fixtureSHA
$fixtures=ReadMap $fixturePath
Require ($fixtures.status -ceq 'passed_runtime_supervision_only' -and $fixtures.passed -eq $true -and $fixtures.safe_next_workload -eq $true -and $fixtures.runtime_supervision_qualification_passed -eq $true -and $fixtures.fixture_count -eq 5 -and $fixtures.fixture_oracles_passed -eq 5) 'Runtime-only fixtures incomplete'
Require ($fixtures.guard_case_count -eq 594 -and $fixtures.source_run_id -ceq 'app080-20261108T160614Z' -and $fixtures.guard_receipt_sha256 -ceq '20ec03224dab3da992557d5c8f5a5ddf28dd2f9ed6b8f85e4a2dd5a80e960c82' -and $fixtures.application_qualification -eq $false -and $fixtures.fixture_imports_application_or_ui -eq $false) 'Runtime fixture source boundary changed'
foreach($key in @('all_actual_root_tool_exits_verified','all_actual_windows_drivers_exited','all_owned_scopes_empty_verified','all_quiet_windows_at_least_30_seconds','boot_unchanged','power_unchanged','sleep_restored')){Require ($fixtures[$key] -eq $true) ('Incomplete runtime fixture proof: '+$key)}
$priorPath=Join-Path $workspace 'evidence/080-guards-deploy-final-active-context-20261108.json'
SourceProof $priorPath
$prior=ReadMap $priorPath
Verify $prior.freeze_manifest 'd9d0145a00ea7cb27f79305ac5655938f80fb7571572f44317b94cbdca711bb9'
$priorFreeze=ReadMap $prior.freeze_manifest
foreach($name in @('supervise-080.py','run-supervised-080.ps1','qualification-power-080.ps1','validate-stability-080.py','test_supervision080_fixture.py','run-parent-loss080.ps1','watch-parent-loss080.py')){
 Require ($freeze.helper_files[$name] -ceq $priorFreeze.helper_files[$name]) ('Runtime fixture implementation changed: '+$name)
 Verify (Join-Path $prior.windows_tools $name) $priorFreeze.helper_files[$name]
}
foreach($trial in $fixtures.actual_trials){Verify $trial.oracle $trial.oracle_sha256}

# Reuse the whole-suite argv contract, without claiming the old run applies.
$oldBackendPath=Join-Path $workspace 'evidence/080-fullbackend-deploy-active-context-20261108.json'
Verify $oldBackendPath '7e4e1c2ac76bdce83075577763dbb5ed46ff172b9c1ddc1afadbe8266142bafb'
$old=ReadMap $oldBackendPath
Verify $old.specification $old.specification_sha256
$spec=ReadMap $old.specification
Require ($spec.argv.Count -eq 15 -and @($spec.argv|Where-Object{$_ -ceq '--expected-skips' -or $_ -ceq '--phase'}).Count -eq 0) 'Unexpected full-suite argument contract'
Require ($spec.env.TMPDIR -ceq '/tmp' -and $spec.env.LANG -ceq 'C.UTF-8' -and $spec.env.LC_ALL -ceq 'C.UTF-8' -and $spec.env.Count -eq 3) 'Unexpected full-suite environment'
$contextPath=Join-Path $workspace 'evidence/080-fullbackend-sidebar-resize-active-context-20261108.json'
Require (-not (Test-Path -LiteralPath $contextPath)) 'Do not overwrite old backend contexts'
$runId='fullbackend-sidebar-resize080-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $runId
Require (-not (Test-Path -LiteralPath $root)) 'Fresh backend root required'
NoReparse $root
foreach($sub in @('artifacts','inputs')){$null=[IO.Directory]::CreateDirectory((Join-Path $root $sub));Physical (Join-Path $root $sub)}
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/')
$artifacts=Join-Path $root 'artifacts'
$files=@{}
function CopyInput([string]$Source,[string]$Relative,[string]$Expected){
 $target=RelativeFile $root $Relative
 CopyExact $Source $target $Expected ([IO.Path]::GetFullPath($Source).StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase))
 $files[$Relative]=$Expected
}
CopyInput (Join-Path $g.artifact_root 'gate.json') 'artifacts/gate.json' $g.gate_sha256
$inputs=@(
 @($guardPath,'guard-context.json',$GuardContextSha256),
 @((Join-Path $g.artifact_root 'receipt.json'),'guard-receipt.json',$GuardReceiptSha256),
 @($g.final_report,'guard-final-report.json',$GuardFinalReportSha256),
 @($g.freeze_manifest,'toolbundle-freeze.json',$g.freeze_sha256),
 @($appPath,'app-context.json',(HashFile $appPath)),
 @($g.app_freeze,'app-source-freeze.json',$sourceSHA),
 @($g.app_prepare_receipt,'app-prepare-receipt.json',$prepareSHA),
 @((Join-Path $g.windows_root 'inputs/candidate-build-context.json'),'candidate-build-context.json',$freeze.files['inputs/candidate-build-context.json']),
 @((Join-Path $g.windows_root 'inputs/candidate-build-observation.json'),'candidate-build-observation.json',$freeze.files['inputs/candidate-build-observation.json']),
 @($fixturePath,'runtime-only-five594.json',$fixtureSHA),
 @($prior.freeze_manifest,'runtime-fixture-verifier594-freeze.json',(HashFile $prior.freeze_manifest)),
 @($old.specification,'historical-full-suite-argv.json',$old.specification_sha256)
)
foreach($entry in $inputs){CopyInput $entry[0] ('inputs/'+$entry[1]) $entry[2]}
$spec.run_id=$runId
$spec.python_launcher=$g.python_launcher
for($i=0;$i -lt $spec.argv.Count;$i++){
 $value=[string]$spec.argv[$i]
 if($value -ceq $old.run_id){$value=$runId}
 elseif($value -ceq $old.source_root){$value=$g.source_root}
 elseif($value.StartsWith($old.linux_root+'/')){$value=$linuxRoot+$value.Substring($old.linux_root.Length)}
 $spec.argv[$i]=$value
}
Require ($spec.argv[0] -ceq '--execute' -and $spec.argv[2] -ceq $runId -and $spec.argv[4] -ceq ($linuxRoot+'/artifacts') -and $spec.argv[6] -ceq $g.source_root -and $spec.argv[8] -ceq ($linuxRoot+'/artifacts/gate.json')) 'Full-suite argv binding failed'
$specPath=Join-Path $artifacts 'spec.json'
NewJson $specPath $spec
$files['artifacts/spec.json']=HashFile $specPath
ArtifactHashes $files $root
$inputFreeze=Join-Path $root 'prepared-inputs.json'
NewJson $inputFreeze @{schema_version=1;run_id=$runId;status='prepared_not_run';files=$files;helper_sha256=$freeze.helper_files;source_freeze_sha256=$sourceSHA;guard_receipt_sha256=$GuardReceiptSha256;runtime_fixture_receipt_sha256=$fixtures.guard_receipt_sha256;application_qualification=$false;ui_or_ux_pass_inferred=$false}
$gate=ReadMap (Join-Path $g.artifact_root 'gate.json')
$context=@{
 schema_version=1;scope='devbrain_complete_backend_preparation';phase='fullbackend';status='prepared_not_run';run_id=$runId;windows_root=$root;linux_root=$linuxRoot;artifact_root=$artifacts;linux_artifact_root=($linuxRoot+'/artifacts')
 windows_tools=$g.windows_tools;linux_tools=$g.linux_tools;controller=($g.linux_tools+'/run-full-suite-080.py');controller_sha256=$freeze.helper_files['run-full-suite-080.py'];base_python=$g.base_python;python_launcher=$g.python_launcher;source_root=$g.source_root;runtime=$gate.runtime
 specification=$specPath;specification_sha256=(HashFile $specPath);required_artifacts=$spec.required_artifacts;input_freeze=$inputFreeze;input_freeze_sha256=(HashFile $inputFreeze);frozen_input_count=$files.Count
 timeout_seconds=7200;cleanup_grace_seconds=30;wsl_crash_directory=$g.wsl_crash_directory;helper_file_count=38;helper_sha256=$freeze.helper_files;reviewed_helper_sha256=$freeze.helper_files;toolbundle_freeze=$g.freeze_manifest;toolbundle_freeze_sha256=$g.freeze_sha256
 app_run_id=$app.run_id;app_snapshot=$app.run_id;app_freeze=$g.app_freeze;app_freeze_sha256=$sourceSHA;source_freeze_sha256=$sourceSHA;app_file_count=198;app_prepare_receipt=$g.app_prepare_receipt;app_prepare_receipt_sha256=$prepareSHA;source_final=$false
 guard_context=$guardPath;guard_context_sha256=$GuardContextSha256;guard_receipt=(Join-Path $g.artifact_root 'receipt.json');guard_receipt_sha256=$GuardReceiptSha256;guard_test_count=604;guard_module_count=12;guard_actual_windows_exit_code=0;gate_sha256=$g.gate_sha256
 candidate_directory=(Join-Path $g.windows_root 'candidate');candidate_updater_sha256=$g.updater_sha256;candidate_zip_sha256=$g.candidate_zip_sha256;candidate_manifest_sha256=$g.candidate_manifest_sha256;candidate_build_observation_sha256=$g.candidate_build_observation_sha256
 expected_test_count=1561;collection_authoritative=$true;full_test_directory='tests';deselection_allowed=$false;skip_allowance=0;expected_skips=@{};attestation_required_after_actual_receipt=$true;full_suite_attestation_pending=$true
 latest_fixture_report=$fixturePath;latest_fixture_report_sha256=$fixtureSHA;latest_fixture_count=5;latest_fixture_passed=$true;fixture_qualification_scope='unchanged_runtime_instrumentation_only';fixture_source_run_id=$fixtures.source_run_id;fixture_guard_case_count=594;fixture_guard_receipt_sha256=$fixtures.guard_receipt_sha256;fixture_application_qualification=$false
 current_ui_passed=$false;current_ux_passed=$false;final_ui_receipt_sha256=$null;final_ui_report_sha256=$null;final_ux_receipt_sha256=$null;historical_application_results_reused=$false
 source_and_helper_hashes_verified=$true;canonical_handle_proofs_passed=$true;destination_reparse_checks_passed=$true;credentials_read_during_staging=$false;linux_workload_started=$false;launch_permitted=$false;requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true;preparation_only=$true;application_qualified=$false;release_qualified=$false;actual_windows_exit_code=$null;cleanup_complete=$false;receipt_sha256=$null
}
NewJson $contextPath $context
@{context=$contextPath;context_sha256=(HashFile $contextPath);run_id=$runId;specification_sha256=(HashFile $specPath);input_freeze_sha256=(HashFile $inputFreeze);expected_cases=1561;source_final=$false;new_ui_or_ux_inferred=$false;linux_started=$false}|ConvertTo-Json -Depth 5

