#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$UiContext,[string]$UiContextSha256,[string]$UiReceiptSha256,[string]$UiFinalReportSha256)
if(-not $Stage){Write-Output 'NOT_RUN: requires actual current UI PASS; prepares five contexts only, never launches workloads.';return}
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

$masterPath=Join-Path $workspace 'evidence/080-length-repair-remaining-gate-templates-604-20261108.json'
$masterSHA='c9576982a7b550b0991dd6edfccf98cc87abd3c776ad572da4f4730e1c3b0a0c'
Verify $masterPath $masterSHA;$master=ReadMap $masterPath
Require ($master.source_snapshot-ceq'app080-20261108T202627Z'-and$master.source_freeze_sha256-ceq'1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14'-and$master.helper_count-eq38) 'Wrong current source/helper template'
Verify $master.input_freeze $master.input_freeze_sha256;$templateFreeze=ReadMap $master.input_freeze;Artifacts $templateFreeze.files $master.windows_root;SameMap $templateFreeze.helper_sha256 $master.helper_sha256
$ProofManifest=Join-Path $workspace 'evidence/080-length-repair-eight-hour-proof-manifest-after-ux-20261108.json'
$ProofManifestSha256='e494c73a75c42a658fdca6f66a02dfc38e6db43686cb27f9e0e46e2a3d37a4ed'
Verify $ProofManifest $ProofManifestSha256;$proof=ReadMap $ProofManifest
foreach($value in @($UiContextSha256,$UiReceiptSha256,$UiFinalReportSha256)){Require ($value-cmatch'^[0-9a-f]{64}$') 'Actual UI proof hashes required'}
Require ($UiContext-and$UiContext.StartsWith($workspace+'\evidence\',[StringComparison]::OrdinalIgnoreCase)) 'Current public UI context required'
Verify $UiContext $UiContextSha256;$uiContext=ReadMap $UiContext
$proof.gates.interactive=@{context=$UiContext;context_sha256=$UiContextSha256;receipt_sha256=$UiReceiptSha256;final_report_sha256=$UiFinalReportSha256;run_id=$uiContext.run_id}
Require ($proof.schema_version-eq1-and$proof.scope-ceq'devbrain_length_repair_eight_hour_prerequisites'-and$proof.source_freeze_sha256-ceq$master.source_freeze_sha256-and$proof.template_master_sha256-ceq$masterSHA) 'Wrong current proof manifest'
function ProofContext($Entry,[string]$Name){
 Require ($Entry.context-and$Entry.context.StartsWith($workspace+'\evidence\',[StringComparison]::OrdinalIgnoreCase)) "Missing public context: $Name"
 Verify $Entry.context $Entry.context_sha256;$c=ReadMap $Entry.context
 Require ($c.status-ceq'passed'-and$c.actual_windows_exit_code-eq0-and$c.actual_windows_exec_session-gt0-and$c.cleanup_complete-eq$true) "Actual exit/cleanup missing: $Name"
 return $c
}
$guardEntry=$proof.guard;$g=ProofContext $guardEntry 'guard604'
Require ($g.app_freeze_sha256-ceq$master.source_freeze_sha256-and$g.source_root-ceq$master.source_root-and$g.python_launcher-ceq$master.python_launcher-and$g.actual_test_count-eq604) 'Guard is not current source-specific604'
SameMap $g.helper_sha256 $master.helper_sha256;SameMap $g.reviewed_helper_sha256 $master.helper_sha256
$guardPath=Join-Path $g.artifact_root 'receipt.json';Verify $guardPath $guardEntry.receipt_sha256;Require ($g.receipt_sha256-ceq$guardEntry.receipt_sha256) 'Guard receipt binding differs'
Verify $g.final_report $guardEntry.final_report_sha256;Require ($g.final_report_sha256-ceq$guardEntry.final_report_sha256) 'Guard final report differs'
$guard=ReadMap $guardPath;Artifacts $guard.artifact_sha256 $g.artifact_root
$gs=ReadMap (Join-Path $g.artifact_root 'regression-source.json');SameMap $gs.guard_sources.helper_sha256 $master.helper_sha256
foreach($name in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $name) $master.helper_sha256[$name]}
$backendEntry=$proof.backend;$backendPath=$backendEntry.context;$backend=ProofContext $backendEntry 'fullbackend1557'
Require ($backend.source_root-ceq$master.source_root-and$backend.python_launcher-ceq$master.python_launcher-and$backend.app_freeze_sha256-ceq$master.source_freeze_sha256-and$backend.guard_receipt_sha256-ceq$guardEntry.receipt_sha256) 'Backend source/guard binding differs'
SameMap $backend.helper_sha256 $master.helper_sha256;Require ($backend.windows_tools-ceq$g.windows_tools-and$backend.linux_tools-ceq$g.linux_tools) 'Backend tooling root differs'
$receiptSHA=$backendEntry.receipt_sha256;Verify $backend.receipt $receiptSHA;Require ($backend.receipt_sha256-ceq$receiptSHA) 'Backend receipt differs'
Verify $backend.final_report $backendEntry.final_report_sha256;Require ($backend.final_report_sha256-ceq$backendEntry.final_report_sha256) 'Backend final report differs'
$receipt=ReadMap $backend.receipt;Artifacts $receipt.artifact_sha256 $backend.artifact_root
$standaloneEntry=$proof.standalone;$envelopePath=$standaloneEntry.context;$envelope=ProofContext $standaloneEntry 'standalone1557'
$AttestationContextSha256=$standaloneEntry.context_sha256;$AttestationSha256=$standaloneEntry.attestation_sha256;$ObservationSha256=$standaloneEntry.observation_sha256
Require ($envelope.backend_run_id-ceq$backend.run_id-and$envelope.source_freeze_sha256-ceq$master.source_freeze_sha256) 'Standalone backend/source differs'
SameMap $envelope.helper_sha256 $master.helper_sha256
$attestationPath=Join-Path $backend.artifact_root 'final-full-suite.json';Require ($envelope.canonical_output-ceq$attestationPath-and$envelope.attestation_sha256-ceq$AttestationSha256-and$envelope.observation_sha256-ceq$ObservationSha256) 'Canonical current backend attestation required'
$observationPath=Join-Path $envelope.artifact_root 'attestation-observation.json';Verify $attestationPath $AttestationSha256;Verify $observationPath $ObservationSha256
$standaloneFinalPath=$standaloneEntry.final_report;Verify $standaloneFinalPath $standaloneEntry.final_report_sha256;$standaloneFinal=ReadMap $standaloneFinalPath
Require ($standaloneFinal.schema_version-eq1-and$standaloneFinal.status-ceq'passed'-and$standaloneFinal.passed-eq$true-and$standaloneFinal.full_suite_attestation_passed-eq$true-and$standaloneFinal.actual_root_session-eq$envelope.actual_windows_exec_session-and$standaloneFinal.actual_exit_code-eq0-and$standaloneFinal.cleanup_complete-eq$true) 'Standalone final process report incomplete'
Require ($standaloneFinal.context_sha256-ceq$AttestationContextSha256-and$standaloneFinal.backend_context_sha256-ceq$backendEntry.context_sha256-and$standaloneFinal.backend_receipt_sha256-ceq$receiptSHA-and$standaloneFinal.source_freeze_sha256-ceq$master.source_freeze_sha256-and$standaloneFinal.canonical-ceq$attestationPath-and$standaloneFinal.canonical_sha256-ceq$AttestationSha256-and$standaloneFinal.observation_sha256-ceq$ObservationSha256) 'Standalone final report identity differs'
$observation=ReadMap $observationPath;$suite=ReadMap $attestationPath
Require ($observation.scope-ceq'devbrain_standalone_attestation_process_observation'-and$observation.passed-eq$true-and$observation.cleanup_complete-eq$true-and$observation.attestation_validated-eq$true-and$observation.actual_proxy_exit-eq0-and$observation.actual_exit_verified-eq$true-and$observation.stdio_complete-eq$true) 'Standalone observation did not pass'
Require ($observation.registered_controller-eq$false-and$observation.manual_pid_birth_cleanup_admission_required-eq$false-and$observation.post_exit_observed_seconds-ge30-and@($observation.errors).Count-eq0-and$observation.initial_boot_id-and$observation.initial_boot_id-ceq$observation.final_boot_id) 'Standalone tail/boot proof incomplete'
Require ($observation.output_path-ceq$attestationPath-and$observation.output_sha256['final-full-suite.json']-ceq$AttestationSha256) 'Standalone output digest differs'
Require ($suite.schema_version-eq1-and$suite.scope-ceq'devbrain_final_full_suite_attestation'-and$suite.final_full_suite_pass-eq$true-and$suite.run_id-ceq$backend.run_id-and$suite.artifact_root-ceq$backend.linux_artifact_root-and$suite.external_receipt_sha256-ceq$receiptSHA) 'Wrong full-suite attestation identity'
Artifacts $suite.artifact_sha256 $backend.artifact_root;$frozen=ReadMap (Join-Path $backend.artifact_root 'frozen-source.json');SameMap $suite.source_hashes $frozen.source_hashes;SameMap $suite.runtime $master.runtime
Require ($suite.isolated_package.origin-ceq($master.source_root+'/src/devbrain/__init__.py')) 'Wrong original qualified source origin'
$source=ReadMap $master.source_freeze;Verify $master.source_freeze $master.source_freeze_sha256;$appRoot=Split-Path $master.source_freeze -Parent
$appFiles=@($source.files.Keys|Where-Object{$_-clike'devbrain/*'});Require ($appFiles.Count-eq198) 'Source inventory changed'
foreach($rel in $appFiles){Verify (RelativeFile (Join-Path $appRoot 'bundle') $rel) $source.files[$rel]}
Verify $master.app_prepare_receipt $master.app_prepare_receipt_sha256
# Runtime-only five fixtures retain original594 provenance; only unchanged instrumentation is reused.
$fixtures=$master.runtime_only_fixtures.path;Verify $fixtures $master.runtime_only_fixtures.sha256;$fixture=ReadMap $fixtures
Require ($fixture.passed-eq$true-and$fixture.safe_next_workload-eq$true-and$fixture.fixture_oracles_passed-eq5-and$fixture.application_qualification-eq$false-and$fixture.fixture_imports_application_or_ui-eq$false) 'Runtime-only five fixtures incomplete'
Verify $fixture.guard_receipt $fixture.guard_receipt_sha256;$fixtureGuard=ReadMap $fixture.guard_receipt;$fixtureArt=Split-Path $fixture.guard_receipt -Parent
Artifacts $fixtureGuard.artifact_sha256 $fixtureArt;$fixtureSource=ReadMap (Join-Path $fixtureArt 'regression-source.json')
foreach($name in @('supervise-080.py','run-supervised-080.ps1','qualification-power-080.ps1','validate-stability-080.py','test_supervision080_fixture.py','run-parent-loss080.ps1','watch-parent-loss080.py')){Require ($fixtureSource.guard_sources.helper_sha256[$name]-ceq$master.helper_sha256[$name]) 'Runtime instrumentation changed since fixtures'}
foreach($trial in $fixture.actual_trials){Verify $trial.oracle $trial.oracle_sha256;Require ($trial.passed-eq$true-and$trial.driver_actual_exit_verified-eq$true-and$trial.safe_next_workload-eq$true-and$trial.scope_empty_verified-eq$true-and$trial.scope_quiet_seconds-ge30) 'Runtime fixture actual cleanup incomplete'}
$candidate=$master.candidate_binding;Verify $candidate.context $candidate.context_sha256;Verify $candidate.observation $candidate.observation_sha256;$build=ReadMap $candidate.context
Require ($build.actual_windows_exit_code-eq0-and$build.cleanup_complete-eq$true-and$build.source_freeze_sha256-ceq$master.source_freeze_sha256) 'Current v7 actual build absent'
Artifacts $candidate.output_sha256 $build.windows_root
$master.candidate_updater_sha256=$candidate.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py'];$master.candidate_zip_sha256=$candidate.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip'];$master.candidate_manifest_sha256=$candidate.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json']
Require ($g.updater_sha256-ceq$master.candidate_updater_sha256-and$g.candidate_zip_sha256-ceq$master.candidate_zip_sha256-and$g.candidate_manifest_sha256-ceq$master.candidate_manifest_sha256-and$g.candidate_build_observation_sha256-ceq$candidate.observation_sha256) 'Current604 did not qualify exact v7 candidate'
function CleanReceipt($r,[string]$Run){
 Require ($r.schema_version-eq1-and$r.scope-ceq'devbrain_external_process_watch'-and$r.run_id-ceq$Run) 'Wrong external receipt identity'
 foreach($key in @('passed','controller_exit_verified','supervisor_exit_verified','cleanup_complete','scope_initially_absent','scope_membership_verified','scope_empty_verified')){Require ($r[$key]-eq$true) "External proof incomplete: $key"}
 foreach($key in @('child_returncode','supervisor_returncode','windows_proxy_returncode')){Require ($r[$key]-eq0) "Nonzero external process: $key"}
 Require ($r.forced_cleanup-eq$false-and$r.native_failure-eq$false-and$r.explicit_tagged_cleanup_may_be_required-eq$false) 'External cleanup was uncertain or forced'
 Require ($r.cleanup_grace_seconds-ge30-and$r.scope_cleanup_grace_seconds-ge30-and$r.initial_boot_id-and$r.initial_boot_id-ceq$r.final_boot_id) 'External tail or boot proof incomplete'
 foreach($key in @('errors','new_wsl_dumps','new_kernel_fatals')){Require ($r.Contains($key)-and@($r[$key]).Count-eq0) "External fatal evidence: $key"}
 Require ($r.sleep_inhibition.acquired-eq$true-and$r.sleep_inhibition.restored-eq$true-and$r.power_monitor.changed-eq$false-and$r.power_monitor.sample_count-gt0) 'Power/sleep observation incomplete'
 SameMap $r.helper_sha256_start $r.helper_sha256_end;SameMap $r.input_sha256_start $r.input_sha256_end
 SameMap $r.runtime $suite.runtime
}
function Counts($n,[int]$Expected){
 Require ($n.collected-eq$Expected-and$n.passed-eq$Expected) 'Whole collection did not pass'
 foreach($key in @('skipped','failures','errors','unexpected_skips','duplicates','missing')){Require ($n[$key]-eq0) 'Incomplete or nonpassing collection'}
 Require ($n.expected_skips.Count-eq0-and$n.observed_skips.Count-eq0) 'Skip allowance forbidden'
}
function BoundResult($Gate,[string]$Relative){
 Require ($Gate.receipt.artifact_sha256.Contains($Relative)) "Unbound required result: $Relative"
 ReadMap (RelativeFile $Gate.context.artifact_root $Relative)
}
function CompletedGate([string]$Name,$Entry,$Expected){
 $path=$Entry.context;Require ($path.StartsWith($workspace+'\evidence\',[StringComparison]::OrdinalIgnoreCase)) 'Gate context must be public workspace evidence'
 Verify $path $Entry.context_sha256;$c=ReadMap $path
 Require ($c.status-ceq'passed'-and$c.actual_windows_exit_code-eq0-and$c.cleanup_complete-eq$true-and$c.run_id-ceq$Entry.run_id-and$Entry.run_id-cmatch'^[a-zA-Z0-9_-]+$') "Actual final gate absent: $Name"
 Require ($c.source_root-ceq$backend.source_root-and$c.python_launcher-ceq$backend.python_launcher) "Wrong original qualified source/launcher: $Name"
 $sourceSHA=if($c.Contains('source_freeze_sha256')){$c.source_freeze_sha256}else{$c.app_freeze_sha256}
 Require ($sourceSHA-ceq$master.source_freeze_sha256) "Wrong source freeze: $Name"
 $rp=Join-Path $c.artifact_root 'receipt.json';Verify $rp $Entry.receipt_sha256
 Require ($c.receipt_sha256-ceq$Entry.receipt_sha256) "Context/receipt mismatch: $Name"
 Verify $c.final_report $Entry.final_report_sha256;Require ($c.final_report_sha256-ceq$Entry.final_report_sha256) 'Final report digest differs'
 $final=ReadMap $c.final_report
 $finalStatus=if($Name-ceq'queue_copy'){'passed_focused_queue_copy_only'}else{'passed'}
 Require ($final.status-ceq$finalStatus-and$final.run_id-ceq$c.run_id-and$final.actual_windows_exit_code-eq0-and$final.actual_windows_exec_session-gt0-and$final.cleanup_complete-eq$true-and$final.receipt_sha256-ceq$Entry.receipt_sha256) "Final process handoff missing: $Name"
 $r=ReadMap $rp;CleanReceipt $r $c.run_id;Artifacts $r.artifact_sha256 $c.artifact_root
 $helpers=if($c.Contains('helper_sha256')){$c.helper_sha256}else{$c.reviewed_helper_sha256}
 Require ($helpers.Count-eq$Expected.helper_count) 'Wrong instrumentation generation'
 foreach($key in $helpers.Keys){Verify (Join-Path $c.windows_tools $key) $helpers[$key]}
 foreach($key in $r.helper_sha256_start.Keys){Require ($helpers.Contains($key)-and$helpers[$key]-ceq$r.helper_sha256_start[$key]) 'Receipt helpers not from qualified instrumentation'}
 SameMap $helpers $master.helper_sha256
 Require ($c.guard_receipt_sha256-ceq$guardEntry.receipt_sha256) 'Application proof must use current source-specific604 guard'
 $sup=ReadMap (Join-Path $c.artifact_root 'supervisor-report.json');$ctrl=ReadMap (Join-Path $c.artifact_root 'controller-report.json')
 Require ($sup.passed-eq$true-and$sup.cleanup_complete-eq$true-and$sup.forced_cleanup-eq$false-and$sup.native_failure-eq$false-and$sup.controller_exit_verified-eq$true-and$sup.child_returncode-eq0-and$sup.run_id-ceq$c.run_id-and$sup.controller_report_sha256-ceq$r.artifact_sha256['controller-report.json']) 'Linux supervisor proof incomplete'
 foreach($key in @('errors','new_wsl_dumps','new_kernel_fatals','remaining_scope_processes','remaining_tagged_processes')){Require ($sup.Contains($key)-and@($sup[$key]).Count-eq0) 'Linux leftover/fatal proof incomplete'}
 Require ($ctrl.run_id-ceq$c.run_id-and$ctrl.scope-ceq$Expected.scope-and$ctrl.status-ceq$Expected.status-and$ctrl.cleanup_complete-eq$true) "Wrong controller verdict: $Name"
 if($ctrl.Contains('forced_cleanup')){Require ($ctrl.forced_cleanup-eq$false) 'Forced controller cleanup'}
 if($ctrl.Contains('errors')){Require (@($ctrl.errors).Count-eq0) 'Controller errors'}
 if($Name-cne'upgrade_smoke'){SameMap $ctrl.source_hashes $suite.source_hashes}
 SameMap $ctrl.runtime $suite.runtime
 return @{context=$c;context_path=$path;entry=$Entry;receipt=$r;receipt_path=$rp;controller=$ctrl;final=$final;helper_map=$helpers}
}

Counts $suite.counts 1557;CleanReceipt $receipt $backend.run_id;CleanReceipt $guard $g.run_id
$guardResult=ReadMap (Join-Path $g.artifact_root 'regressions-results.json');Counts $guardResult.counts 604;Require ($guardResult.modules.Count-eq12) 'Twelve whole guard modules required'
$expected=[ordered]@{
 ux=@{helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 interactive=@{helper_count=38;scope='devbrain_interactive_ux';status='interactive_ux_completed_pending_external_watch'}
 queue_copy=@{helper_count=38;scope='devbrain_historical_queue_copy_replay';status='queue_copy_completed_pending_external_watch'}
}
$gates=[ordered]@{};foreach($name in $expected.Keys){$gates[$name]=CompletedGate $name $proof.gates[$name] $expected[$name]}
$ux=BoundResult $gates.ux 'regressions-results.json';Counts $ux.counts 377
Require ($ux.modules.Count-eq28-and$ux.individual_test_selectors.Count-eq0-and$ux.normal_conftest-eq$true) 'Whole UX377/28 required'
$ui=BoundResult $gates.interactive 'interactive-results.json'
Require ($ui.agent_acceptance_passed-eq$true-and$ui.human_acceptance_passed-eq$false-and$ui.baseline_only-eq$false-and$ui.observations.Count-eq8-and$ui.oauth_cache_sync.passed-eq$true-and$ui.oauth_cache_release.passed-eq$true) 'Actual agent UI/OAuth proof incomplete'
foreach($key in @('task:start','task:switch','task:source','task:connection','task:reconnect','geometry:80x24','geometry:120x36','geometry:180x55')){Require ($ui.observations.Contains($key)-and$ui.observations[$key].status-ceq'passed') 'Missing actual UI task/geometry'}
Require ($gates.interactive.final.photos.Count-eq3) 'Three actual Windows captures required'
foreach($photo in $gates.interactive.final.photos){Require ($photo.window_only-eq$true-and$photo.actual_windows_terminal-eq$true-and$photo.root_personally_visually_reviewed-eq$true-and$photo.readonly_observer_exit_verified-eq$true) 'Unreviewed or incomplete OS photo';Verify $photo.png $photo.png_sha256}
$queue=$gates.queue_copy.controller
Require ($queue.all_six_replayed-eq$true-and$queue.jobs.Count-eq6-and@($queue.jobs.id|Sort-Object -Unique).Count-eq6-and$queue.production_modified-eq$false-and$queue.unrelated_jobs_unchanged-eq$true-and$queue.engine_actual_exit_verified-eq$true) 'Exact six-job isolated replay incomplete'
SameMap $queue.duplicate_counts_before $queue.duplicate_counts_after
Require (@($queue.jobs|Where-Object{$_.kind-ceq'import'}).Count-eq3-and@($queue.jobs|Where-Object{$_.kind-ceq'extract'}).Count-eq3) 'Historical job set differs'
foreach($job in $queue.jobs){Require ($job.state-ceq'completed'-and$job.attempts-eq($job.previous_attempts+1)) 'Historical copy job not completed exactly once'}

# Every pending/failed prerequisite is refused before the first directory creation.
$templates=[ordered]@{}
$controllers=@{native='validate-native-account080.py';copilot='validate-copilot-account080.py';ollama20='run-regressions-080.py';frontend='run-regressions-080.py';upgrade_smoke='test_devbrain_update080_smoke.py'}
$timeouts=@{native=1200;copilot=420;ollama20=3600;frontend=2100;upgrade_smoke=1800}
foreach($name in @('native','copilot','ollama20','frontend','upgrade_smoke')){
 $entry=$master.templates[$name];Verify $entry.path $entry.sha256;$t=ReadMap $entry.path
 Require ($t.source_root-ceq$master.source_root-and$t.python_launcher-ceq$master.python_launcher-and$t.source_freeze_sha256-ceq$master.source_freeze_sha256-and$t.source_snapshot-ceq$master.source_snapshot) 'Template source differs'
 SameMap $t.reviewed_helper_sha256 $master.helper_sha256
 SameMap $t.runtime $master.runtime;Require ($t.base_python-ceq$master.runtime.python_executable-and$t.runtime_gate_sha256-ceq$master.runtime_gate_sha256) 'Template qualified runtime differs'
 Require ($t.controller_basename-ceq$controllers[$name]-and$t.controller_sha256-ceq$master.helper_sha256[$controllers[$name]]-and$t.timeout_seconds-eq$timeouts[$name]-and$t.cleanup_grace_seconds-eq30) 'Controller or timeout differs'
 Require ($t.specification_template.python_launcher-ceq$master.python_launcher-and$t.specification_template.run_id-ceq'<RUN_ID>') 'Template interpreter/run differs'
 SameMap $t.specification_template.env @{LANG='C.UTF-8';LC_ALL='C.UTF-8';TMPDIR='/tmp'}
 $executeCount=@($t.specification_template.argv|Where-Object{$_-ceq'--execute'}).Count
 Require ($executeCount-eq$(if($name-ceq'upgrade_smoke'){0}else{1})) 'Unexpected execute placeholder contract'
 $templates[$name]=$t
}
$baseline=Join-Path $build.windows_root 'releases/devbrain-0.7.2.zip';$baselineSHA='6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c';Verify $baseline $baselineSHA
$shared=[ordered]@{
 'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
 'proposal-master.json'=@{path=$masterPath;sha=$masterSHA}
 'partial-proof-manifest.json'=@{path=$ProofManifest;sha=$ProofManifestSha256}
 'standalone-context-passed.json'=@{path=$envelopePath;sha=$AttestationContextSha256}
 'standalone-observation.json'=@{path=$observationPath;sha=$ObservationSha256}
 'standalone-final-report.json'=@{path=$standaloneFinalPath;sha=$standaloneEntry.final_report_sha256}
 'backend-context-passed.json'=@{path=$backendPath;sha=$backendEntry.context_sha256}
 'backend-receipt.json'=@{path=$backend.receipt;sha=$receiptSHA}
 'backend-final-report.json'=@{path=$backend.final_report;sha=$backendEntry.final_report_sha256}
 'runtime-fixtures594.json'=@{path=$fixtures;sha=$master.runtime_only_fixtures.sha256}
 'source-freeze.json'=@{path=$master.source_freeze;sha=$master.source_freeze_sha256}
 'app-prepare-receipt.json'=@{path=$master.app_prepare_receipt;sha=$master.app_prepare_receipt_sha256}
 'guard-context-passed.json'=@{path=$guardEntry.context;sha=$guardEntry.context_sha256}
 'guard-receipt.json'=@{path=$guardPath;sha=$guardEntry.receipt_sha256}
 'guard-final-report.json'=@{path=$g.final_report;sha=$guardEntry.final_report_sha256}
 'candidate-v7-context.json'=@{path=$candidate.context;sha=$candidate.context_sha256}
 'candidate-v7-observation.json'=@{path=$candidate.observation;sha=$candidate.observation_sha256}
}
foreach($name in $gates.Keys){$x=$gates[$name];$shared["$name-context-passed.json"]=@{path=$x.context_path;sha=$x.entry.context_sha256};$shared["$name-receipt.json"]=@{path=$x.receipt_path;sha=$x.entry.receipt_sha256};$shared["$name-final-report.json"]=@{path=$x.context.final_report;sha=$x.entry.final_report_sha256}}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ');$created=[ordered]@{}
foreach($name in $templates.Keys){
 $t=$templates[$name];$entry=$master.templates[$name];$label=$name.Replace('_','-')
 $run="$label-length-final080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
 Require ($run.Length-le64) 'Run id too long'
 $root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root already exists';NoReparse $root
 [void][IO.Directory]::CreateDirectory($root);PathProof $root;$art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs'
 [void][IO.Directory]::CreateDirectory($art);[void][IO.Directory]::CreateDirectory($inputs);PathProof $art;PathProof $inputs
 $linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt="$linuxRoot/artifacts"
 $specText=($t.specification_template|ConvertTo-Json -Depth 40).Replace('<LINUX_RUN_ROOT>',$linuxRoot).Replace('<LINUX_ARTIFACT_ROOT>',$linuxArt).Replace('<RUN_ID>',$run)
 $spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String
 if($name-ceq'upgrade_smoke'){$spec.argv=@('--execute')+@($spec.argv)}
 Require (($spec|ConvertTo-Json -Depth 40)-notmatch'<[A-Z_]+>'-and@($spec.argv|Where-Object{$_-ceq'--execute'}).Count-eq1) 'Unresolved or ambiguous executable spec'
 $specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
 foreach($key in $shared.Keys){$item=$shared[$key];CopyExact $item.path (Join-Path $inputs $key) $item.sha;$files["inputs/$key"]=$item.sha}
 CopyExact $entry.path (Join-Path $inputs 'template.json') $entry.sha256;$files['inputs/template.json']=$entry.sha256
 NewJson (Join-Path $inputs 'actual-prerequisite-proof-manifest.json') $proof;$files['inputs/actual-prerequisite-proof-manifest.json']=HashFile (Join-Path $inputs 'actual-prerequisite-proof-manifest.json')
 CopyExact (Join-Path $backend.artifact_root 'gate.json') (Join-Path $art 'gate.json') $master.runtime_gate_sha256;$files['artifacts/gate.json']=$master.runtime_gate_sha256
 CopyExact $attestationPath (Join-Path $art 'final-full-suite.json') $AttestationSha256;$files['artifacts/final-full-suite.json']=$AttestationSha256
 if($name-ceq'upgrade_smoke'){
  CopyExact $baseline (Join-Path $inputs 'devbrain-0.7.2.zip') $baselineSHA;$files['inputs/devbrain-0.7.2.zip']=$baselineSHA
  foreach($rel in $candidate.output_sha256.Keys){$leaf=[IO.Path]::GetFileName($rel);CopyExact (RelativeFile $build.windows_root $rel) (Join-Path $inputs $leaf) $candidate.output_sha256[$rel];$files["inputs/$leaf"]=$candidate.output_sha256[$rel]}
 }
 $freezePath=Join-Path $root 'prepared-input-freeze.json';NewJson $freezePath @{schema_version=1;scope='devbrain_length_repair_final_gate_inputs';run_id=$run;files=$files;helper_sha256=$master.helper_sha256;source_freeze_sha256=$master.source_freeze_sha256;guard_receipt_sha256=$guardEntry.receipt_sha256;full_suite_attestation_sha256=$AttestationSha256;ui_context_sha256=$UiContextSha256;ui_receipt_sha256=$UiReceiptSha256;linux_workload_started=$false}
 $c=[ordered]@{
  schema_version=1;scope='devbrain_current_source_final_gate_context';status='prepared_not_run_pending_root_serial_handoff';phase=$name;name=$name;run_id=$run;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=$linuxArt
  windows_tools=$g.windows_tools;linux_tools=$g.linux_tools;wrapper=(Join-Path $g.windows_tools 'run-supervised-080.ps1');controller=($g.linux_tools+'/'+$t.controller_basename);controller_basename=$t.controller_basename;controller_sha256=$master.helper_sha256[$t.controller_basename];base_python=$t.base_python;python_launcher=$master.python_launcher;source_root=$master.source_root;runtime=$master.runtime
  specification=$specPath;specification_sha256=(HashFile $specPath);required_artifacts=$spec.required_artifacts;input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);input_file_count=$files.Count;frozen_input_count=$files.Count
  helper_sha256=$master.helper_sha256;reviewed_helper_sha256=$master.helper_sha256;helper_file_count=38;toolbundle_freeze=$g.freeze_manifest;toolbundle_freeze_sha256=$g.freeze_sha256
  app_snapshot=$master.source_snapshot;app_run_id=$master.source_snapshot;source_snapshot=$master.source_snapshot;app_freeze=$master.source_freeze;app_freeze_sha256=$master.source_freeze_sha256;source_freeze_sha256=$master.source_freeze_sha256;app_file_count=198;source_final=$true;source_finalized=$true;app_prepare_receipt=$master.app_prepare_receipt;app_prepare_receipt_sha256=$master.app_prepare_receipt_sha256
  gate_sha256=$master.runtime_gate_sha256;runtime_gate_sha256=$master.runtime_gate_sha256;guard_context=$guardEntry.context;guard_context_sha256=$guardEntry.context_sha256;guard_receipt=$guardPath;guard_receipt_sha256=$guardEntry.receipt_sha256;guard_final_report=$g.final_report;guard_final_report_sha256=$guardEntry.final_report_sha256;guard_test_count=604;guard_module_count=12;guard_actual_windows_exit_code=0
  candidate_directory=$candidate.directory;candidate_updater_sha256=$master.candidate_updater_sha256;candidate_zip_sha256=$master.candidate_zip_sha256;candidate_manifest_sha256=$master.candidate_manifest_sha256;candidate_build_observation_sha256=$candidate.observation_sha256
  latest_fixture_report=$fixtures;latest_fixture_report_sha256=$master.runtime_only_fixtures.sha256;latest_fixture_passed=$true;latest_fixture_count=5;fixture_qualification_scope='unchanged_runtime_instrumentation_only';fixture_application_qualification=$false;fixture_guard_case_count=594
  timeout_seconds=$t.timeout_seconds;cleanup_grace_seconds=30;wsl_crash_directory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes';private_root='/home/piotr/.cache/devbrain-regressions-080';data_dir=$null
  full_suite_attestation=$attestationPath;full_suite_attestation_sha256=$AttestationSha256;standalone_observation_sha256=$ObservationSha256;current_backend_actual_pass=$true;full_backend_cases=1557;current_ux_passed=$true;current_ui_passed=$true;prerequisite_proofs=[ordered]@{}
  final_ux_receipt_sha256=$gates.ux.entry.receipt_sha256;final_ui_receipt_sha256=$UiReceiptSha256;final_ui_report_sha256=$UiFinalReportSha256
  launch_permitted=$false;linux_workload_started=$false;requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true;preparation_only=$true;qualified=$false;application_qualified=$false;release_qualified=$false;production_modified=$false;production_remains_stopped=$true;credentials_read_during_staging=$false
  is_frozen_execution_spec=$true;materialization_required=$false;source_and_helper_hashes_verified=$true;acceptance=$t.acceptance;template_path=$entry.path;template_sha256=$entry.sha256;created_utc=[DateTimeOffset]::UtcNow.ToString('o')
 }
 $c.prerequisite_proofs.full_suite=@{path=$attestationPath;sha256=$AttestationSha256;passed=$true;cases=1557;source_root=$master.source_root;original_backend_root=$backend.artifact_root}
 $c.prerequisite_proofs.full_backend_receipt=@{path=$backend.receipt;sha256=$receiptSHA;passed=$true;actual_windows_exit_code=0;actual_windows_exec_session=$backend.actual_windows_exec_session}
 foreach($gateName in $gates.Keys){$x=$gates[$gateName];$c.prerequisite_proofs[$gateName]=@{path=$x.receipt_path;sha256=$x.entry.receipt_sha256;passed=$true;context=$x.context_path;context_sha256=$x.entry.context_sha256;final_report=$x.context.final_report;final_report_sha256=$x.entry.final_report_sha256}}
 $c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$c.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory=$c.wsl_crash_directory}
 if($name-ceq'upgrade_smoke'){$c.data_dir='/home/piotr/.cache/devbrain-upgrade-validation-080';$c.isolated_new_engine_home="/home/piotr/.cache/devbrain-upgrade-validation-080/$run-engine";$c.backup_python_from_current_smoke=$null}
 Artifacts $files $root;foreach($helper in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $helper) $master.helper_sha256[$helper]}
 Verify $UiContext $UiContextSha256;Verify $masterPath $masterSHA;Verify $ProofManifest $ProofManifestSha256;Artifacts $candidate.output_sha256 $build.windows_root;Verify $baseline $baselineSHA
 $contextPath=Join-Path $workspace "evidence/080-$label-length-final-active-context-20261108.json";NewJson $contextPath $c
 $created[$name]=@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$run;specification=$specPath;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;status=$c.status;launch_permitted=$false}
}
$output=Join-Path $workspace 'evidence/080-five-length-final-gate-contexts-20261108.json'
NewJson $output @{schema_version=1;scope='devbrain_current_source_five_final_gate_contexts';status='prepared_not_run_pending_root_serial_handoff';contexts=$created;source_snapshot=$master.source_snapshot;source_freeze_sha256=$master.source_freeze_sha256;helper_count=38;guard_receipt_sha256=$guardEntry.receipt_sha256;full_suite_attestation_sha256=$AttestationSha256;ui_context_sha256=$UiContextSha256;ui_receipt_sha256=$UiReceiptSha256;execution_order=@('native','copilot','ollama20','frontend','upgrade_smoke');linux_workload_started=$false;production_modified=$false;release_qualified=$false}
@{master=$output;sha256=(HashFile $output);contexts=$created;linux_workload_started=$false}|ConvertTo-Json -Depth 8
