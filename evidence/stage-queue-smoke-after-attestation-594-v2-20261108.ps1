#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$AttestationContextSha256,[string]$AttestationSha256,[string]$ObservationSha256)
if(-not $Stage){Write-Output 'NOT_RUN: filesystem preparation only, after actual completed backend attestation; this script never launches a process.';return}
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
$masterPath=Join-Path $workspace 'evidence/080-remaining-final-gate-proposals-38-assistantpref-v4-20261108.json'
Verify $masterPath '9a6f1f845eb4bbe14791b46b67e6f8af43fcc17bf37f97ad74798d09672a5c63'
$master=ReadMap $masterPath
$envelopePath=Join-Path $workspace 'evidence/080-standalone-full-suite-attestation-envelope-v2-20261108.json'
Verify $envelopePath $AttestationContextSha256
$envelope=ReadMap $envelopePath
Require ($envelope.status-ceq'passed'-and$envelope.actual_windows_exit_code-eq0-and$envelope.actual_windows_exec_session-eq78778-and$envelope.cleanup_complete-eq$true) 'Root has not observed final standalone exit and cleanup'
Require ($envelope.backend_run_id-ceq'fullbackend-deploy-final080-20261108T171720Z-28700701'-and$envelope.source_freeze_sha256-ceq$master.source_freeze_sha256-and$envelope.helper_sha256.Count-eq38) 'Attestation source/backend identity differs'
SameMap $envelope.helper_sha256 $master.helper_sha256
Require ($envelope.attestation_sha256-ceq$AttestationSha256-and$envelope.observation_sha256-ceq$ObservationSha256) 'Root context differs from exact output/observation digests'
$attestationPath=$envelope.canonical_output
$observationPath=Join-Path $envelope.artifact_root 'attestation-observation.json'
Verify $attestationPath $AttestationSha256;Verify $observationPath $ObservationSha256
Verify $envelope.final_report $envelope.final_report_sha256
$observation=ReadMap $observationPath;$suite=ReadMap $attestationPath
Require ($observation.scope-ceq'devbrain_standalone_attestation_process_observation'-and$observation.passed-eq$true-and$observation.cleanup_complete-eq$true-and$observation.attestation_validated-eq$true-and$observation.actual_proxy_exit-eq0-and$observation.actual_exit_verified-eq$true-and$observation.stdio_complete-eq$true) 'Standalone observation did not pass'
Require ($observation.registered_controller-eq$false-and$observation.manual_pid_birth_cleanup_admission_required-eq$false-and$observation.post_exit_observed_seconds-ge30-and@($observation.errors).Count-eq0-and$observation.initial_boot_id-ceq$observation.final_boot_id) 'Standalone exit/native observation incomplete'
Require ($observation.output_path-ceq$attestationPath-and$observation.output_sha256['final-full-suite.json']-ceq$AttestationSha256) 'Standalone output binding differs'
Require ($suite.schema_version-eq1-and$suite.scope-ceq'devbrain_final_full_suite_attestation'-and$suite.final_full_suite_pass-eq$true-and$suite.run_id-ceq$envelope.backend_run_id-and$suite.artifact_root-ceq'/mnt/c/Users/piotr/AppData/Local/Packages/OpenAI.Codex_2p2nqsd0c76g0/LocalCache/Local/DevBrain/qualification/fullbackend-deploy-final080-20261108T171720Z-28700701/artifacts') 'Wrong canonical full-suite attestation'
Require ($suite.counts.collected-eq1508-and$suite.counts.passed-eq1508) 'Whole1508 suite required'
foreach($n in @('skipped','failures','errors','unexpected_skips','duplicates','missing')){Require ($suite.counts[$n]-eq0) 'Suite contains nonpassing cases'}
Require ($suite.counts.expected_skips.Count-eq0-and$suite.counts.observed_skips.Count-eq0) 'No skip allowance'
$backendPath=Join-Path $workspace 'evidence/080-fullbackend-deploy-active-context-20261108.json'
Verify $backendPath '7e4e1c2ac76bdce83075577763dbb5ed46ff172b9c1ddc1afadbe8266142bafb'
$backend=ReadMap $backendPath
Require ($backend.status-ceq'passed'-and$backend.actual_windows_exit_code-eq0-and$backend.actual_windows_exec_session-eq46894-and$backend.cleanup_complete-eq$true) 'Backend actual exit incomplete'
$receiptSHA='9240e55ef83bbde4bbf66b8906066e582844bf73874c273720de8c8b27bb606d'
Verify $backend.receipt $receiptSHA
$receipt=ReadMap $backend.receipt
Require ($suite.external_receipt_sha256-ceq$receiptSHA-and$receipt.passed-eq$true-and$receipt.cleanup_complete-eq$true-and$receipt.forced_cleanup-eq$false-and$receipt.native_failure-eq$false) 'Backend receipt differs or failed'
Artifacts $receipt.artifact_sha256 $backend.artifact_root
Artifacts $suite.artifact_sha256 $backend.artifact_root
$frozen=ReadMap (Join-Path $backend.artifact_root 'frozen-source.json')
SameMap $suite.source_hashes $frozen.source_hashes
SameMap $suite.runtime $backend.runtime
Require ($suite.isolated_package.origin-ceq($backend.source_root+'/src/devbrain/__init__.py')) 'Wrong original qualified source origin'
$fixtures=Join-Path $workspace 'evidence/080-controlled-fixtures-deploy-final-20261108.json'
Verify $fixtures 'd466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c'
$fixture=ReadMap $fixtures
Require ($fixture.passed-eq$true-and$fixture.safe_next_workload-eq$true-and$fixture.fixture_oracles_passed-eq5-and$fixture.helper_count-eq38-and$fixture.guard_receipt_sha256-ceq$master.guard_receipt_sha256) 'Current five-fixture qualification absent'
$guardPath=Join-Path $backend.windows_tools '../artifacts/receipt.json'
Verify $guardPath $master.guard_receipt_sha256
$guard=ReadMap $guardPath
Require ($guard.passed-eq$true-and$guard.cleanup_complete-eq$true) 'Tool guards failed'
$source=ReadMap $backend.app_freeze;Verify $backend.app_freeze $master.source_freeze_sha256
$appRoot=Split-Path $backend.app_freeze -Parent
$appFiles=@($source.files.Keys|Where-Object{$_-clike'devbrain/*'})
Require ($appFiles.Count-eq198) 'Current app inventory differs'
foreach($rel in $appFiles){Verify (RelativeFile (Join-Path $appRoot 'bundle') $rel) $source.files[$rel]}
foreach($name in $master.helper_sha256.Keys){Verify (Join-Path $backend.windows_tools $name) $master.helper_sha256[$name]}
$old=[ordered]@{}
foreach($name in @('queue_copy','upgrade_smoke')){
 $entry=$master.proposals[$name];Verify $entry.context $entry.context_sha256;$c=ReadMap $entry.context
 Verify $c.input_freeze $c.input_freeze_sha256;Verify $c.specification $c.specification_sha256
 $freeze=ReadMap $c.input_freeze;Artifacts $freeze.files $c.windows_root
 SameMap $c.helper_sha256 $master.helper_sha256
 Require ($c.source_root-ceq$backend.source_root-and$c.python_launcher-ceq$backend.python_launcher-and$c.source_freeze_sha256-ceq$master.source_freeze_sha256) 'Proposal source/runtime differs'
 $old[$name]=$c
}
# All required completed proof checks above are read-only. Start fresh filesystem staging now.
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ');$created=[ordered]@{}
foreach($name in $old.Keys){
 $c=$old[$name];$entry=$master.proposals[$name];$oldRoot=$c.windows_root;$oldRun=$c.run_id;$oldLinux=$c.linux_root
 $label=if($name-ceq'queue_copy'){'queue-copy'}else{'updater-smoke'}
 $run="$label-deploy-final080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
 Require ($run.Length-le64) 'Run id too long'
 $root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root already exists';NoReparse $root
 [void][IO.Directory]::CreateDirectory($root);PathProof $root
 $art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs';[void][IO.Directory]::CreateDirectory($art);[void][IO.Directory]::CreateDirectory($inputs)
 PathProof $art;PathProof $inputs
 $linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt="$linuxRoot/artifacts"
 $spec=ReadMap $c.specification
 $specText=($spec|ConvertTo-Json -Depth 40).Replace($oldLinux,$linuxRoot).Replace($oldRun,$run)
 $spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String
 Require (@($spec.argv|Where-Object{$_-ceq'--execute'}).Count-eq0) 'Proposal already includes execute'
 $spec.argv=@('--execute')+@($spec.argv);$spec.run_id=$run
 $specPath=Join-Path $art 'spec.json';NewJson $specPath $spec
 $files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
 $shared=[ordered]@{
  'previous-proposal.json'=@{path=$entry.context;sha=$entry.context_sha256}
  'previous-spec.json'=@{path=$c.specification;sha=$c.specification_sha256}
  'previous-freeze.json'=@{path=$c.input_freeze;sha=$c.input_freeze_sha256}
  'proposal-master.json'=@{path=$masterPath;sha='9a6f1f845eb4bbe14791b46b67e6f8af43fcc17bf37f97ad74798d09672a5c63'}
  'standalone-context-passed.json'=@{path=$envelopePath;sha=$AttestationContextSha256}
  'standalone-observation.json'=@{path=$observationPath;sha=$ObservationSha256}
  'standalone-final-report.json'=@{path=$envelope.final_report;sha=$envelope.final_report_sha256}
  'backend-context-passed.json'=@{path=$backendPath;sha='7e4e1c2ac76bdce83075577763dbb5ed46ff172b9c1ddc1afadbe8266142bafb'}
  'backend-receipt.json'=@{path=$backend.receipt;sha=$receiptSHA}
  'controlled-fixtures-final.json'=@{path=$fixtures;sha='d466c012f3bbfa8134154c85d510b82d758f8422c4facdedf986482b26d3260c'}
  'source-freeze.json'=@{path=$backend.app_freeze;sha=$master.source_freeze_sha256}
  'guard-receipt.json'=@{path=$guardPath;sha=$master.guard_receipt_sha256}
  'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
 }
 foreach($key in $shared.Keys){$s=$shared[$key];CopyExact $s.path (Join-Path $inputs $key) $s.sha;$files["inputs/$key"]=$s.sha}
 CopyExact (Join-Path $backend.artifact_root 'gate.json') (Join-Path $art 'gate.json') $c.runtime_gate_sha256;$files['artifacts/gate.json']=$c.runtime_gate_sha256
 CopyExact $attestationPath (Join-Path $art 'final-full-suite.json') $AttestationSha256;$files['artifacts/final-full-suite.json']=$AttestationSha256
 if($name-ceq'upgrade_smoke'){
  $previousFreeze=ReadMap $c.input_freeze
  foreach($rel in @($previousFreeze.files.Keys|Where-Object{$_-clike'releases/*'})){
   $target=RelativeFile $root $rel;$parent=Split-Path $target -Parent;NoReparse $parent;[void][IO.Directory]::CreateDirectory($parent);PathProof $parent
   CopyExact (RelativeFile $oldRoot $rel) $target $previousFreeze.files[$rel];$files[$rel]=$previousFreeze.files[$rel]
  }
  Require (@($files.Keys|Where-Object{$_-clike'releases/*'}).Count-eq5) 'Exact v4 release4 plus immutable072 required'
 }
 $freezePath=Join-Path $root 'prepared-input-freeze.json'
 NewJson $freezePath @{schema_version=1;scope='devbrain_queue_or_smoke_prepared_inputs';run_id=$run;files=$files;helper_sha256=$master.helper_sha256;source_freeze_sha256=$master.source_freeze_sha256;full_suite_attestation_sha256=$AttestationSha256;standalone_observation_sha256=$ObservationSha256;controlled_fixtures_report_sha256=$master.controlled_fixtures_report_sha256;linux_workload_started=$false}
 $c.previous_context=$entry.context;$c.previous_context_sha256=$entry.context_sha256
 $c.run_id=$run;$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=$art;$c.linux_artifact_root=$linuxArt
 $c.specification=$specPath;$c.specification_sha256=HashFile $specPath;$c.input_freeze=$freezePath;$c.input_freeze_sha256=HashFile $freezePath;$c.input_file_count=$files.Count
 $c.required_artifacts=$spec.required_artifacts;$c.is_frozen_execution_spec=$true;$c.execute_omitted=$false

 $c.reviewed_helper_sha256=$master.helper_sha256;$c.helper_file_count=38
 $c.app_snapshot=$backend.app_snapshot;$c.app_run_id=$backend.app_run_id;$c.app_freeze=$backend.app_freeze;$c.app_freeze_sha256=$backend.app_freeze_sha256;$c.app_file_count=198;$c.source_final=$true
 $c.app_prepare_receipt=$backend.app_prepare_receipt;$c.app_prepare_receipt_sha256=$backend.app_prepare_receipt_sha256;$c.gate_sha256=$backend.gate_sha256
 $c.guard_context=$backend.guard_context;$c.guard_receipt=$backend.guard_receipt;$c.guard_test_count=594;$c.guard_module_count=12;$c.guard_actual_windows_exit_code=0
 $c.wsl_crash_directory=$backend.wsl_crash_directory;$c.final_ux_receipt_sha256=$backend.final_ux_receipt_sha256;$c.final_ui_receipt_sha256=$backend.final_ui_receipt_sha256;$c.final_ui_report_sha256=$backend.final_ui_report_sha256
 $c.phase=$label;$c.candidate_directory=$backend.candidate_directory
 $c.requires_root_serial_handoff=$true;$c.new_controlled_fixtures_passed=$true;$c.latest_fixture_passed=$true;$c.latest_fixture_count=5;$c.latest_fixture_report=$fixtures;$c.latest_fixture_report_sha256=$master.controlled_fixtures_report_sha256
 $c.controlled_fixture_handoff=$fixtures;$c.controlled_fixture_handoff_sha256=$master.controlled_fixtures_report_sha256

 $c.status='prepared_not_run_pending_root_serial_handoff';$c.launch_permitted=$false;$c.linux_workload_started=$false;$c.preparation_only=$true
 $c.full_suite_attestation=$attestationPath;$c.full_suite_attestation_sha256=$AttestationSha256;$c.standalone_observation_sha256=$ObservationSha256
 $c.current_backend_actual_pass=$true
 $c.prerequisite_proofs.full_suite=@{path=$attestationPath;sha256=$AttestationSha256;passed=$true;cases=1508;source_root=$backend.source_root;original_backend_root=$backend.artifact_root}
 $c.prerequisite_proofs.full_backend_receipt=@{path=$backend.receipt;sha256=$receiptSHA;passed=$true;actual_windows_exit_code=0;actual_windows_exec_session=46894}
 $c.missing_required_proofs=@($c.missing_required_proofs|Where-Object{$_-cne'full_suite'})
 $c.remaining_launch_prerequisites=$c.missing_required_proofs
 $c.launch_requires_explicit_serial_handoff=$true
 $c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$c.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes'}
 $c.data_dir=if($name-ceq'queue_copy'){"/home/piotr/.cache/devbrain-qualification-080/$run/queue-copy"}else{$null}
 $c.created_utc=[DateTimeOffset]::UtcNow.ToString('o')
 if($name-ceq'queue_copy'){$c.backup_file_read_or_hashed_during_materialization=$false;$c.production_retry_permitted=$false}
 $contextPath=Join-Path $workspace "evidence/080-$label-deploy-active-context-20261108.json"
 Artifacts $files $root;foreach($helper in $master.helper_sha256.Keys){Verify (Join-Path $backend.windows_tools $helper) $master.helper_sha256[$helper]}
 Verify $envelopePath $AttestationContextSha256
 NewJson $contextPath $c
 $created[$name]=@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$run;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;launch_permitted=$false;remaining_launch_prerequisites=$c.remaining_launch_prerequisites}
}
$out=Join-Path $workspace 'evidence/080-queue-smoke-deploy-contexts-20261108.json'
NewJson $out @{schema_version=1;scope='devbrain_queue_smoke_contexts';status='prepared_not_run';contexts=$created;source_freeze_sha256=$master.source_freeze_sha256;full_suite_attestation_sha256=$AttestationSha256;standalone_observation_sha256=$ObservationSha256;controlled_fixtures_report_sha256=$master.controlled_fixtures_report_sha256;linux_workload_started=$false;production_modified=$false}
@{master=$out;sha256=(HashFile $out);contexts=$created;linux_workload_started=$false}|ConvertTo-Json -Depth 8

