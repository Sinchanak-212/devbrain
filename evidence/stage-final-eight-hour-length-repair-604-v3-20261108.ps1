#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$ProofManifest,[string]$ProofManifestSha256)
if(-not $Stage){Write-Output 'NOT_RUN: requires every completed release gate; filesystem staging only, no process launch.';return}
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
Verify $ProofManifest $ProofManifestSha256;$proof=ReadMap $ProofManifest
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
 native=@{helper_count=38;scope='devbrain_native_account_validation';status='native_account_completed_pending_attestation'}
 copilot=@{helper_count=38;scope='devbrain_copilot_account_validation';status='copilot_account_completed_pending_attestation'}
 recall=@{helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 frontend=@{helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 queue_copy=@{helper_count=38;scope='devbrain_historical_queue_copy_replay';status='queue_copy_completed_pending_external_watch'}
 upgrade_smoke=@{helper_count=38;scope='devbrain_upgrade_smoke_controller';status='upgrade_smoke_completed_pending_attestation'}
}
Require ($proof.gates.Count-eq$expected.Count) 'All eight current functional gate proofs required'
foreach($name in $expected.Keys){Require ($proof.gates.Contains($name)) "Missing prerequisite $name";foreach($key in @('context_sha256','receipt_sha256','final_report_sha256')){Require ($proof.gates[$name][$key]-cmatch'^[0-9a-f]{64}$') "Pending prerequisite $name/$key"}}
$gates=[ordered]@{};foreach($name in $expected.Keys){$gates[$name]=CompletedGate $name $proof.gates[$name] $expected[$name]}
$ux=BoundResult $gates.ux 'regressions-results.json';Counts $ux.counts 377
Require ($ux.modules.Count-eq28-and$ux.individual_test_selectors.Count-eq0-and$ux.normal_conftest-eq$true) 'Whole UX377/28 required'
$ui=BoundResult $gates.interactive 'interactive-results.json'
Require ($ui.agent_acceptance_passed-eq$true-and$ui.human_acceptance_passed-eq$false-and$ui.baseline_only-eq$false-and$ui.observations.Count-eq8-and$ui.oauth_cache_sync.passed-eq$true-and$ui.oauth_cache_release.passed-eq$true) 'Actual agent UI/OAuth proof incomplete'
foreach($key in @('task:start','task:switch','task:source','task:connection','task:reconnect','geometry:80x24','geometry:120x36','geometry:180x55')){Require ($ui.observations.Contains($key)-and$ui.observations[$key].status-ceq'passed') 'Missing actual UI task/geometry'}
Require ($gates.interactive.final.Contains('visual_acceptance_passed')-and$gates.interactive.final.visual_acceptance_passed-is[bool]-and$gates.interactive.final.visual_acceptance_passed-eq$true) 'Actual root visual acceptance required'
Require ($gates.interactive.final.photos.Count-eq3) 'Three actual Windows captures required'
foreach($photo in $gates.interactive.final.photos){Require ($photo.window_only-eq$true-and$photo.actual_windows_terminal-eq$true-and$photo.root_personally_visually_reviewed-eq$true-and$photo.readonly_observer_exit_verified-eq$true) 'Unreviewed or incomplete OS photo';Verify $photo.png $photo.png_sha256}
$native=BoundResult $gates.native 'native-results.json'
Require ($native.status-ceq'passed'-and$native.phases.Count-eq3-and$native.exact_packet_ack_verified-eq$true-and$native.owned_database_removed-eq$true-and$native.previous_ack_invalidated[1]-eq$true-and$native.previous_ack_invalidated[2]-eq$true) 'Native three-phase ACK/invalidation proof incomplete'
$clients=@('codex','claude','codex');for($i=0;$i-lt3;$i++){Require ($native.phases[$i].client-ceq$clients[$i]-and$native.phases[$i].status-ceq'passed'-and$native.phases[$i].fresh_process-eq$true-and$native.phases[$i].answer_matches_expected-eq$true-and$native.oauth_phase_sync[$i].passed-eq$true) 'Native phase did not pass'}
Require ($gates.native.controller.oauth_cache_sync.passed-eq$true-and$gates.native.controller.oauth_lease_release.passed-eq$true) 'Final OAuth synchronization failed'
$copilot=BoundResult $gates.copilot 'copilot-results.json'
Require ($copilot.status-ceq'passed'-and$copilot.helper_returncode-eq0-and$copilot.api_key_provided-eq$false) 'Real account-only Copilot proof missing'
foreach($key in @('actual_model_ack_verified','file_read_verified','protocol_order_verified','project_unchanged','response_contains_marker','only_owned_database_removed','oauth_store_reused')){Require ($copilot[$key]-eq$true) 'Copilot functional proof incomplete'}
$recall=BoundResult $gates.recall 'recall-results.json';$progress=BoundResult $gates.recall 'recall/checkpoint.json'
Require ($recall.status-ceq'passed'-and$recall.golden_count-eq20-and$recall.attempted-eq20-and$recall.scenarios.Count-eq20-and$recall.required_accuracy-eq0.9-and$recall.factual_accuracy-ge0.9-and$recall.critical_facts_passed-eq$true) 'Real unchanged20-case recall threshold not met'
Require ($progress.completed_cases-eq20-and$progress.monitoring.stopped-eq$true-and$progress.monitoring.samples-gt0-and@($progress.monitoring.errors).Count-eq0) 'Recall monitoring did not finish'
Require ($gates.recall.receipt.artifact_sha256.Contains('recall/cases.jsonl')-and$gates.recall.receipt.artifact_sha256.Contains('recall/resources.jsonl')) 'Recall checkpoint/monitor not receipt-bound'
$cases=@(Get-Content -LiteralPath (Join-Path $gates.recall.context.artifact_root 'recall/cases.jsonl')|ForEach-Object{$_|ConvertFrom-Json -AsHashtable -DateKind String})
Require ($cases.Count-eq20-and@($cases.id|Sort-Object -Unique).Count-eq20-and@((Compare-Object @($cases.id|Sort-Object) @($recall.scenarios.id|Sort-Object))).Count-eq0) 'Recall case identity/completion differs'
foreach($row in $recall.scenarios){Require ($row.status-cin@('passed','failed')-and$row.answer.status-cin@('complete','partial')) 'Recall contains unavailable/unattempted case';if($row.critical){Require ($row.status-ceq'passed') 'Critical recall failed'}}
foreach($row in $cases){Require ($row.status-cin@('passed','failed')-and$row.answer_status-cin@('complete','partial')-and$row.checkpoint_source-ceq'original_score_answer') 'Recall scorer checkpoint differs'}
Require ($recall.deterministic_checks.Count-gt0) 'Missing deterministic checks';foreach($v in $recall.deterministic_checks.Values){Require ($v-eq$true) 'Deterministic recall check failed'}
$front=BoundResult $gates.frontend 'regressions-results.json';$frontExpected=[ordered]@{}
foreach($rel in $source.files.Keys){if($rel-cmatch'^devbrain/frontend/(.+)$'){$frontExpected[$Matches[1]]=$source.files[$rel]}}
Require ($frontExpected.Count-gt0-and$front.status-ceq'passed'-and$front.synthetic_browser_mocks-eq$true-and$front.frozen_web_static_modified-eq$false-and$front.filters.Count-eq0) 'Frontend whole synthetic phase incomplete'
SameMap $gates.frontend.controller.frontend_source_hashes $frontExpected;SameMap $front.source_hashes $frontExpected
foreach($part in @('unit','browser')){Require ($front[$part].passed-gt0) 'Frontend contains no cases';foreach($key in @('failures','errors','skipped')){Require ($front[$part][$key]-eq0) 'Frontend case did not pass'}}
foreach($step in @('install','unit','build','browser','audit_all','audit_runtime')){Require ($front.steps[$step].returncode-eq0) "Frontend step failed: $step"}
Require ($front.steps.server_shutdown.actual_exit_verified-eq$true) 'Frontend server did not exit'
$queue=$gates.queue_copy.controller
Require ($queue.all_six_replayed-eq$true-and$queue.jobs.Count-eq6-and@($queue.jobs.id|Sort-Object -Unique).Count-eq6-and$queue.production_modified-eq$false-and$queue.unrelated_jobs_unchanged-eq$true-and$queue.engine_actual_exit_verified-eq$true) 'Exact six-job isolated replay incomplete'
SameMap $queue.duplicate_counts_before $queue.duplicate_counts_after
Require (@($queue.jobs|Where-Object{$_.kind-ceq'import'}).Count-eq3-and@($queue.jobs|Where-Object{$_.kind-ceq'extract'}).Count-eq3) 'Historical job set differs'
foreach($job in $queue.jobs){Require ($job.state-ceq'completed'-and$job.attempts-eq($job.previous_attempts+1)) 'Historical copy job not completed exactly once'}
$smoke=$gates.upgrade_smoke.controller
Require ($smoke.from_version-ceq'0.7.2'-and$smoke.to_version-ceq'0.8.0'-and$smoke.updater_sha256-ceq$master.candidate_updater_sha256-and$smoke.release_zip_sha256-ceq$master.candidate_zip_sha256-and$smoke.manifest_sha256-ceq$master.candidate_manifest_sha256) 'Current v7 upgrade smoke differs'
foreach($key in @('all_sources_match_candidate_zip','database_backup_exact_private_and_excludes_credentials','backup_uses_independent_072_wheel_on_qualified_base','real_072_backup_restore_and_080_readback','only_controller_owned_engine_was_used','owned_process_cleanup_complete','only_owned_database_removed','restored_database_removed')){Require ($smoke.checks[$key]-eq$true) "Smoke check missing: $key"}
Require ($smoke.checks.profiles_keys_auth_config_models_permissions_preserved-gt0-and$smoke.checks.reapply_preserves_bytes_modes_mtimes_inodes-gt0-and$smoke.engine.actual_exit_verified-eq$true-and$smoke.engine.forced_cleanup-eq$false) 'Smoke preservation/engine exit incomplete'

# No source/private-data mutation or process execution. Everything below is NEW filesystem metadata.
$entry=$master.templates.soak;Verify $entry.path $entry.sha256;$proposal=ReadMap $entry.path;$spec=$proposal.specification_template
function ArgValue([string]$Name){$indices=@(for($i=0;$i-lt$spec.argv.Count;$i++){if($spec.argv[$i]-ceq$Name){$i}});Require ($indices.Count-eq1-and$indices[0]+1-lt$spec.argv.Count) "Missing/duplicate argument: $Name";return $spec.argv[$indices[0]+1]}
Require ((ArgValue '--duration')-ceq'28800'-and(ArgValue '--cycle-seconds')-ceq'900'-and(ArgValue '--cleanup-grace')-ceq'30'-and(ArgValue '--source-root')-ceq$backend.source_root) 'Eight-hour workload contract differs'
Require ((ArgValue '--chat-model')-ceq'qwen3.5:9b'-and(ArgValue '--embedding-model')-ceq'qwen3-embedding:0.6b'-and(ArgValue '--ollama-url')-ceq'http://127.0.0.1:11434'-and@($spec.argv|Where-Object{$_-ceq'--enable-local-models'}).Count-eq1) 'Exact local models required'
Require (@($spec.argv|Where-Object{$_-ceq'--execute'}).Count-eq0-and$spec.python_launcher-ceq$backend.python_launcher-and$proposal.timeout_seconds-eq32400) 'Proposal executable or runtime changed'
Require (@(Compare-Object @($spec.required_artifacts|Sort-Object) @('gate.json','final-full-suite.json','controller-report.json','supervisor-report.json','gpu-samples.jsonl'|Sort-Object)).Count-eq0) 'GPU/external artifacts missing'
SameMap $spec.env @{LANG='C.UTF-8';LC_ALL='C.UTF-8';TMPDIR='/tmp'}
# Every pending or failed prerequisite above fails before this first filesystem mutation.
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ');$run="soak-length-repair-final080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root already exists';NoReparse $root
[void][IO.Directory]::CreateDirectory($root);PathProof $root;$art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs'
[void][IO.Directory]::CreateDirectory($art);[void][IO.Directory]::CreateDirectory($inputs);PathProof $art;PathProof $inputs
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt="$linuxRoot/artifacts"
$specText=($spec|ConvertTo-Json -Depth 40).Replace('<LINUX_RUN_ROOT>',$linuxRoot).Replace('<RUN_ID>',$run)
$spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String;$spec.argv=@('--execute')+@($spec.argv);$spec.run_id=$run
Require (($spec|ConvertTo-Json -Depth 40)-notmatch'<[A-Z_]+>') 'Unresolved specification placeholder'
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
$shared=[ordered]@{
 'complete-proof-manifest.json'=@{path=$ProofManifest;sha=$ProofManifestSha256};'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
 'proposal-master.json'=@{path=$masterPath;sha=$masterSHA};'soak-template.json'=@{path=$entry.path;sha=$entry.sha256}
 'standalone-context-passed.json'=@{path=$envelopePath;sha=$AttestationContextSha256};'standalone-observation.json'=@{path=$observationPath;sha=$ObservationSha256};'standalone-final-report.json'=@{path=$standaloneFinalPath;sha=$standaloneEntry.final_report_sha256}
 'backend-context-passed.json'=@{path=$backendPath;sha=$backendEntry.context_sha256};'backend-receipt.json'=@{path=$backend.receipt;sha=$receiptSHA};'backend-final-report.json'=@{path=$backend.final_report;sha=$backendEntry.final_report_sha256}
 'runtime-fixtures594.json'=@{path=$fixtures;sha=$master.runtime_only_fixtures.sha256};'source-freeze.json'=@{path=$master.source_freeze;sha=$master.source_freeze_sha256};'app-prepare-receipt.json'=@{path=$master.app_prepare_receipt;sha=$master.app_prepare_receipt_sha256}
 'guard-context-passed.json'=@{path=$guardEntry.context;sha=$guardEntry.context_sha256};'guard-receipt.json'=@{path=$guardPath;sha=$guardEntry.receipt_sha256};'guard-final-report.json'=@{path=$g.final_report;sha=$guardEntry.final_report_sha256}
 'candidate-v7-context.json'=@{path=$candidate.context;sha=$candidate.context_sha256};'candidate-v7-observation.json'=@{path=$candidate.observation;sha=$candidate.observation_sha256}
}
foreach($name in $gates.Keys){$x=$gates[$name];$shared["$name-context-passed.json"]=@{path=$x.context_path;sha=$x.entry.context_sha256};$shared["$name-receipt.json"]=@{path=$x.receipt_path;sha=$x.entry.receipt_sha256};$shared["$name-final-report.json"]=@{path=$x.context.final_report;sha=$x.entry.final_report_sha256}}
foreach($name in $shared.Keys){$s=$shared[$name];CopyExact $s.path (Join-Path $inputs $name) $s.sha;$files["inputs/$name"]=$s.sha}
CopyExact (Join-Path $backend.artifact_root 'gate.json') (Join-Path $art 'gate.json') $master.runtime_gate_sha256;$files['artifacts/gate.json']=$master.runtime_gate_sha256
CopyExact $attestationPath (Join-Path $art 'final-full-suite.json') $AttestationSha256;$files['artifacts/final-full-suite.json']=$AttestationSha256
$freezePath=Join-Path $root 'prepared-input-freeze.json';NewJson $freezePath @{schema_version=1;scope='devbrain_length_repair_eight_hour_inputs';run_id=$run;files=$files;helper_sha256=$master.helper_sha256;source_freeze_sha256=$master.source_freeze_sha256;proof_manifest_sha256=$ProofManifestSha256;full_suite_attestation_sha256=$AttestationSha256;linux_workload_started=$false}
$c=[ordered]@{
 schema_version=1;scope='devbrain_final_eight_hour_preparation';status='prepared_not_run_pending_root_serial_handoff';phase='soak';run_id=$run;windows_root=$root;linux_root=$linuxRoot;artifact_root=$art;linux_artifact_root=$linuxArt
 windows_tools=$g.windows_tools;linux_tools=$g.linux_tools;controller=($g.linux_tools+'/soak-workload-080.py');controller_sha256=$master.helper_sha256['soak-workload-080.py'];base_python=$proposal.base_python;python_launcher=$master.python_launcher;source_root=$master.source_root;runtime=$master.runtime
 specification=$specPath;specification_sha256=(HashFile $specPath);required_artifacts=$spec.required_artifacts;input_freeze=$freezePath;input_freeze_sha256=(HashFile $freezePath);input_file_count=$files.Count;frozen_input_count=$files.Count
 helper_sha256=$master.helper_sha256;reviewed_helper_sha256=$master.helper_sha256;helper_file_count=38;toolbundle_freeze=$g.freeze_manifest;toolbundle_freeze_sha256=$g.freeze_sha256
 app_snapshot=$master.source_snapshot;app_run_id=$master.source_snapshot;app_freeze=$master.source_freeze;app_freeze_sha256=$master.source_freeze_sha256;source_freeze_sha256=$master.source_freeze_sha256;app_file_count=198;source_final=$true;app_prepare_receipt=$master.app_prepare_receipt;app_prepare_receipt_sha256=$master.app_prepare_receipt_sha256
 gate_sha256=$master.runtime_gate_sha256;runtime_gate_sha256=$master.runtime_gate_sha256;guard_context=$guardEntry.context;guard_context_sha256=$guardEntry.context_sha256;guard_receipt=$guardPath;guard_receipt_sha256=$guardEntry.receipt_sha256;guard_test_count=604;guard_module_count=12;guard_actual_windows_exit_code=0
 candidate_directory=$candidate.directory;candidate_updater_sha256=$master.candidate_updater_sha256;candidate_zip_sha256=$master.candidate_zip_sha256;candidate_manifest_sha256=$master.candidate_manifest_sha256;candidate_build_observation_sha256=$candidate.observation_sha256
 latest_fixture_report=$fixtures;latest_fixture_report_sha256=$master.runtime_only_fixtures.sha256;latest_fixture_passed=$true;latest_fixture_count=5;fixture_qualification_scope='unchanged_runtime_instrumentation_only';fixture_application_qualification=$false;fixture_guard_case_count=594
 timeout_seconds=32400;cleanup_grace_seconds=30;wsl_crash_directory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes';data_dir="/home/piotr/.cache/devbrain-regressions-080/$run"
 full_suite_attestation=$attestationPath;full_suite_attestation_sha256=$AttestationSha256;standalone_observation_sha256=$ObservationSha256;current_backend_actual_pass=$true;full_backend_cases=1557;prerequisite_proofs=[ordered]@{}
 final_ux_receipt_sha256=$gates.ux.entry.receipt_sha256;final_ui_receipt_sha256=$gates.interactive.entry.receipt_sha256;final_ui_report_sha256=$gates.interactive.entry.final_report_sha256
 launch_permitted=$false;linux_workload_started=$false;requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true;preparation_only=$true;qualified=$false;production_modified=$false;soak_started=$false;eight_hour_qualification=$false;all_actual_prerequisites_bound=$true;is_frozen_execution_spec=$true;materialization_required=$false;acceptance=$proposal.acceptance;created_utc=[DateTimeOffset]::UtcNow.ToString('o')
}
$c.prerequisite_proofs.full_suite=@{path=$attestationPath;sha256=$AttestationSha256;passed=$true;cases=1557;source_root=$master.source_root;original_backend_root=$backend.artifact_root}
$c.prerequisite_proofs.full_backend_receipt=@{path=$backend.receipt;sha256=$receiptSHA;passed=$true;actual_windows_exit_code=0;actual_windows_exec_session=$backend.actual_windows_exec_session}
foreach($name in $gates.Keys){$x=$gates[$name];$c.prerequisite_proofs[$name]=@{path=$x.receipt_path;sha256=$x.entry.receipt_sha256;passed=$true;context=$x.context_path;context_sha256=$x.entry.context_sha256;final_report=$x.context.final_report;final_report_sha256=$x.entry.final_report_sha256}}
$c.acceptance.full_suite_attestation_sha256=$AttestationSha256;$c.acceptance.minimum_completed_cycles=32;$c.acceptance.minimum_real_chat_queries=32;$c.acceptance.minimum_real_embedding_queries=32;$c.acceptance.sleep_inhibition_only_for_trial=$true
$c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=32400;CleanupGraceSeconds=30;WslCrashDirectory=$c.wsl_crash_directory}
$c.final_attestation_argv=@($c.python_launcher,'-I','-B',($c.linux_tools+'/attest-full-suite-080.py'),'--mode','soak','--artifact-root',$linuxArt,'--source-root',$c.source_root,'--output',($linuxArt+'/final-eight-hour.json'))
$c.final_attestation_requires_actual_soak_receipt=$true;$c.final_attestation_is_future_direct_process=$true
Artifacts $files $root;foreach($name in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $name) $master.helper_sha256[$name]};Verify $ProofManifest $ProofManifestSha256
$contextPath=Join-Path $workspace 'evidence/080-eight-hour-length-repair-active-context-20261108.json';NewJson $contextPath $c
@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$run;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;status=$c.status;launch_permitted=$false;linux_workload_started=$false}|ConvertTo-Json
