#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Stage,[string]$ProofManifest,[string]$ProofManifestSha256)
if(-not $Stage){Write-Output 'NOT_RUN: requires every completed release gate; filesystem staging only, no process launch.';return}
$AttestationContextSha256='5187c6ae216993d2e75bf58159b2ded53e3d7ddff686aa40d6ec89171a55620d'
$AttestationSha256='68ada7d441f2f9996884d239b36c5a37f91c74a2aa941d4f3bbd961c410a1af8'
$ObservationSha256='e94ed36ff87eee41c0b24cd709c3d8538fc8fb69b538337dd2604b81e342c466'
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
CleanReceipt $guard $guard.run_id;Artifacts $guard.artifact_sha256 (Split-Path $guardPath -Parent)
$guardSource=ReadMap (Join-Path (Split-Path $guardPath -Parent) 'regression-source.json')
SameMap $guardSource.guard_sources.helper_sha256 $master.helper_sha256
$guardResult=ReadMap (Join-Path (Split-Path $guardPath -Parent) 'regressions-results.json');Counts $guardResult.counts 594
Require ($guardResult.modules.Count-eq12) 'Current twelve-module guards required'
Verify $backend.app_prepare_receipt $master.app_prepare_receipt_sha256
foreach($pair in @(@('devbrain-update-0.8.0.py',$master.candidate_updater_sha256),@('devbrain-0.8.0.zip',$master.candidate_zip_sha256),@('devbrain-update-0.8.0-manifest.json',$master.candidate_manifest_sha256))){Verify (Join-Path $backend.candidate_directory $pair[0]) $pair[1]}
function CompletedGate([string]$Name,$Entry,$Expected){
 $path=Join-Path $workspace ('evidence/'+$Expected.context)
 Verify $path $Entry.context_sha256;$c=ReadMap $path
 Require ($c.status-ceq'passed'-and$c.actual_windows_exit_code-eq0-and$c.cleanup_complete-eq$true-and$c.run_id-ceq$Expected.run_id) "Actual final gate absent: $Name"
 Require ($c.source_root-ceq$backend.source_root-and$c.python_launcher-ceq$backend.python_launcher) "Wrong original qualified source/launcher: $Name"
 $sourceSHA=if($c.Contains('source_freeze_sha256')){$c.source_freeze_sha256}else{$c.app_freeze_sha256}
 Require ($sourceSHA-ceq$master.source_freeze_sha256) "Wrong source freeze: $Name"
 $rp=Join-Path $c.artifact_root 'receipt.json';Verify $rp $Entry.receipt_sha256
 Require ($c.receipt_sha256-ceq$Entry.receipt_sha256) "Context/receipt mismatch: $Name"
 Verify $c.final_report $Entry.final_report_sha256;Require ($c.final_report_sha256-ceq$Entry.final_report_sha256) 'Final report digest differs'
 $final=ReadMap $c.final_report
 Require ($final.status-ceq'passed'-and$final.run_id-ceq$c.run_id-and$final.actual_windows_exit_code-eq0-and$final.actual_windows_exec_session-gt0-and$final.cleanup_complete-eq$true-and$final.receipt_sha256-ceq$Entry.receipt_sha256) "Final process handoff missing: $Name"
 $r=ReadMap $rp;CleanReceipt $r $c.run_id;Artifacts $r.artifact_sha256 $c.artifact_root
 $helpers=if($c.Contains('helper_sha256')){$c.helper_sha256}else{$c.reviewed_helper_sha256}
 Require ($helpers.Count-eq$Expected.helper_count) 'Wrong instrumentation generation'
 foreach($key in $helpers.Keys){Verify (Join-Path $c.windows_tools $key) $helpers[$key]}
 foreach($key in $r.helper_sha256_start.Keys){Require ($helpers.Contains($key)-and$helpers[$key]-ceq$r.helper_sha256_start[$key]) 'Receipt helpers not from qualified instrumentation'}
 if($Expected.helper_count-eq38){SameMap $helpers $master.helper_sha256}
 else{
  # UI/UX legitimately ran on qualified529. Bind its own guard; never relabel it as38.
  Require ($c.guard_receipt_sha256-ceq'9f6c16a82b820b06135ecb073ba85223f002a5b31cacf8276ec06996d43782d2') 'Historical instrumentation lacks its exact guard'
  Verify $c.guard_receipt $c.guard_receipt_sha256;$gr=ReadMap $c.guard_receipt;CleanReceipt $gr $gr.run_id
  $ga=Split-Path $c.guard_receipt -Parent;Artifacts $gr.artifact_sha256 $ga
  $gs=ReadMap (Join-Path $ga 'regression-source.json');SameMap $gs.guard_sources.helper_sha256 $helpers
 }
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
$expected=[ordered]@{
 ux=@{context='080-ux-assistantpref-active-context-20261108.json';run_id='ux-assistantpref080-20261108T161042Z';helper_count=36;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 interactive=@{context='080-interactive-assistantpref-agent-active-context-20261108.json';run_id='interactive-assistantpref080-20261108T161042Z';helper_count=36;scope='devbrain_interactive_ux';status='interactive_ux_completed_pending_external_watch'}
 native=@{context='080-native-deploy-active-context-20261108.json';run_id='native-deploy-final080-20261108T171720Z-f7a8d934';helper_count=38;scope='devbrain_native_account_validation';status='native_account_completed_pending_attestation'}
 copilot=@{context='080-copilot-deploy-active-context-20261108.json';run_id='copilot-deploy-final080-20261108T171720Z-df34868a';helper_count=38;scope='devbrain_copilot_account_validation';status='copilot_account_completed_pending_attestation'}
 recall=@{context='080-ollama20-deploy-active-context-20261108.json';run_id='ollama20-deploy-final080-20261108T171720Z-4ec44bba';helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 frontend=@{context='080-frontend-deploy-active-context-20261108.json';run_id='frontend-deploy-final080-20261108T171720Z-4b8f555c';helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
 queue_copy=@{context='080-queue-copy-deploy-active-context-20261108.json';run_id='queue-copy-deploy-final080-20261108T174737Z-b0ea6966';helper_count=38;scope='devbrain_historical_queue_copy_replay';status='queue_copy_completed_pending_external_watch'}
 upgrade_smoke=@{context='080-updater-smoke-deploy-active-context-20261108.json';run_id='updater-smoke-deploy-final080-20261108T174737Z-3efd226e';helper_count=38;scope='devbrain_upgrade_smoke_controller';status='upgrade_smoke_completed_pending_attestation'}
}
Verify $ProofManifest $ProofManifestSha256;$proof=ReadMap $ProofManifest
Require ($proof.schema_version-eq1-and$proof.scope-ceq'devbrain_final_eight_hour_prerequisites'-and$proof.source_freeze_sha256-ceq$master.source_freeze_sha256-and$proof.full_suite_attestation_sha256-ceq$AttestationSha256-and$proof.guard_receipt_sha256-ceq$master.guard_receipt_sha256) 'Wrong final proof manifest'
Require ($proof.gates.Count-eq$expected.Count) 'Every actual pre-soak gate required'
# Missing future hashes fail before even creating the new run directory.
foreach($name in $expected.Keys){Require ($proof.gates.Contains($name)) "Missing prerequisite $name";foreach($key in @('context_sha256','receipt_sha256','final_report_sha256')){Require ($proof.gates[$name][$key]-cmatch'^[0-9a-f]{64}$') "Pending prerequisite $name/$key"}}
$gates=[ordered]@{};foreach($name in $expected.Keys){$gates[$name]=CompletedGate $name $proof.gates[$name] $expected[$name]}
$ux=BoundResult $gates.ux 'regressions-results.json';Counts $ux.counts 377
Require ($ux.modules.Count-eq28-and$ux.individual_test_selectors.Count-eq0-and$ux.normal_conftest-eq$true) 'Whole UX377/28 required'
$ui=BoundResult $gates.interactive 'interactive-results.json'
Require ($ui.agent_acceptance_passed-eq$true-and$ui.human_acceptance_passed-eq$false-and$ui.baseline_only-eq$false-and$ui.observations.Count-eq8-and$ui.oauth_cache_sync.passed-eq$true-and$ui.oauth_cache_release.passed-eq$true) 'Actual agent UI/OAuth proof incomplete'
foreach($key in @('task:start','task:switch','task:source','task:connection','task:reconnect','geometry:80x24','geometry:120x36','geometry:180x55')){Require ($ui.observations.Contains($key)-and$ui.observations[$key].status-ceq'passed') 'Missing actual UI task/geometry'}
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
Require ($smoke.from_version-ceq'0.7.2'-and$smoke.to_version-ceq'0.8.0'-and$smoke.updater_sha256-ceq$master.candidate_updater_sha256-and$smoke.release_zip_sha256-ceq$master.candidate_zip_sha256-and$smoke.manifest_sha256-ceq$master.candidate_manifest_sha256) 'Final v4 upgrade smoke differs'
foreach($key in @('all_sources_match_candidate_zip','database_backup_exact_private_and_excludes_credentials','backup_uses_independent_072_wheel_on_qualified_base','real_072_backup_restore_and_080_readback','only_controller_owned_engine_was_used','owned_process_cleanup_complete','only_owned_database_removed','restored_database_removed')){Require ($smoke.checks[$key]-eq$true) "Smoke check missing: $key"}
Require ($smoke.checks.profiles_keys_auth_config_models_permissions_preserved-gt0-and$smoke.checks.reapply_preserves_bytes_modes_mtimes_inodes-gt0-and$smoke.engine.actual_exit_verified-eq$true-and$smoke.engine.forced_cleanup-eq$false) 'Smoke preservation/engine exit incomplete'
# Verify the frozen proposal and its exact existing workload contract. No controller changes.
$entry=$master.proposals.soak;Verify $entry.context $entry.context_sha256;$c=ReadMap $entry.context
Verify $c.input_freeze $c.input_freeze_sha256;Verify $c.specification $c.specification_sha256
$oldFreeze=ReadMap $c.input_freeze;Artifacts $oldFreeze.files $c.windows_root;SameMap $c.helper_sha256 $master.helper_sha256
Verify $c.prerequisite_proofs.candidate_build.path $master.candidate_build_observation_sha256
$spec=ReadMap $c.specification
function ArgValue([string]$Name){$indices=@(for($i=0;$i-lt$spec.argv.Count;$i++){if($spec.argv[$i]-ceq$Name){$i}});Require ($indices.Count-eq1-and$indices[0]+1-lt$spec.argv.Count) "Missing/duplicate argument: $Name";return $spec.argv[$indices[0]+1]}
Require ((ArgValue '--duration')-ceq'28800'-and(ArgValue '--cycle-seconds')-ceq'900'-and(ArgValue '--cleanup-grace')-ceq'30'-and(ArgValue '--source-root')-ceq$backend.source_root) 'Eight-hour workload contract differs'
Require ((ArgValue '--chat-model')-ceq'qwen3.5:9b'-and(ArgValue '--embedding-model')-ceq'qwen3-embedding:0.6b'-and(ArgValue '--ollama-url')-ceq'http://127.0.0.1:11434'-and@($spec.argv|Where-Object{$_-ceq'--enable-local-models'}).Count-eq1) 'Exact local models required'
Require (@($spec.argv|Where-Object{$_-ceq'--execute'}).Count-eq0-and$spec.python_launcher-ceq$backend.python_launcher-and$c.timeout_seconds-eq32400) 'Proposal already executable or timeout/venv differs'
Require (@(Compare-Object @($spec.required_artifacts|Sort-Object) @('gate.json','final-full-suite.json','controller-report.json','supervisor-report.json','gpu-samples.jsonl'|Sort-Object)).Count-eq0) 'Missing required GPU or external artifact'
SameMap $spec.env @{LANG='C.UTF-8';LC_ALL='C.UTF-8';TMPDIR='/tmp'}
# ALL admission above is read-only. A pending/missing/failed gate cannot reach this point.
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ');$run="soak-deploy-final080-$stamp-"+[Guid]::NewGuid().ToString('N').Substring(0,8)
$root=Join-Path $physicalBase $run;Require (-not(Test-Path -LiteralPath $root)) 'Fresh root already exists';NoReparse $root
[void][IO.Directory]::CreateDirectory($root);PathProof $root
$art=Join-Path $root 'artifacts';$inputs=Join-Path $root 'inputs';[void][IO.Directory]::CreateDirectory($art);[void][IO.Directory]::CreateDirectory($inputs);PathProof $art;PathProof $inputs
$linuxRoot='/mnt/c/'+$root.Substring(3).Replace('\','/');$linuxArt="$linuxRoot/artifacts"
$specText=($spec|ConvertTo-Json -Depth 50).Replace($c.linux_root,$linuxRoot).Replace($c.run_id,$run)
$spec=$specText|ConvertFrom-Json -AsHashtable -DateKind String;$spec.argv=@('--execute')+@($spec.argv);$spec.run_id=$run
$specPath=Join-Path $art 'spec.json';NewJson $specPath $spec;$files=[ordered]@{'artifacts/spec.json'=(HashFile $specPath)}
$shared=[ordered]@{
 'complete-proof-manifest.json'=@{path=$ProofManifest;sha=$ProofManifestSha256}
 'materializer.ps1'=@{path=$PSCommandPath;sha=(HashFile $PSCommandPath)}
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
}
foreach($name in $gates.Keys){$g=$gates[$name];$shared["$name-context-passed.json"]=@{path=$g.context_path;sha=$g.entry.context_sha256};$shared["$name-receipt.json"]=@{path=$g.receipt_path;sha=$g.entry.receipt_sha256};$shared["$name-final-report.json"]=@{path=$g.context.final_report;sha=$g.entry.final_report_sha256}}
foreach($key in $shared.Keys){$s=$shared[$key];CopyExact $s.path (Join-Path $inputs $key) $s.sha;$files["inputs/$key"]=$s.sha}
CopyExact (Join-Path $backend.artifact_root 'gate.json') (Join-Path $art 'gate.json') $c.runtime_gate_sha256;$files['artifacts/gate.json']=$c.runtime_gate_sha256
CopyExact $attestationPath (Join-Path $art 'final-full-suite.json') $AttestationSha256;$files['artifacts/final-full-suite.json']=$AttestationSha256
$freezePath=Join-Path $root 'prepared-input-freeze.json'
NewJson $freezePath @{schema_version=1;scope='devbrain_final_eight_hour_prepared_inputs';run_id=$run;files=$files;helper_sha256=$master.helper_sha256;source_freeze_sha256=$master.source_freeze_sha256;proof_manifest_sha256=$ProofManifestSha256;full_suite_attestation_sha256=$AttestationSha256;linux_workload_started=$false}
$c.previous_context=$entry.context;$c.previous_context_sha256=$entry.context_sha256
$c.run_id=$run;$c.windows_root=$root;$c.linux_root=$linuxRoot;$c.artifact_root=$art;$c.linux_artifact_root=$linuxArt
$c.specification=$specPath;$c.specification_sha256=HashFile $specPath;$c.input_freeze=$freezePath;$c.input_freeze_sha256=HashFile $freezePath;$c.input_file_count=$files.Count
$c.required_artifacts=$spec.required_artifacts;$c.is_frozen_execution_spec=$true;$c.execute_omitted=$false;$c.materialization_required=$false
$c.reviewed_helper_sha256=$master.helper_sha256;$c.helper_file_count=38;$c.app_snapshot=$backend.app_snapshot;$c.app_run_id=$backend.app_run_id;$c.app_freeze=$backend.app_freeze;$c.app_freeze_sha256=$backend.app_freeze_sha256;$c.app_file_count=198;$c.source_final=$true
$c.app_prepare_receipt=$backend.app_prepare_receipt;$c.app_prepare_receipt_sha256=$backend.app_prepare_receipt_sha256;$c.gate_sha256=$backend.gate_sha256
$c.guard_context=$backend.guard_context;$c.guard_receipt=$backend.guard_receipt;$c.guard_test_count=594;$c.guard_module_count=12;$c.guard_actual_windows_exit_code=0
$c.wsl_crash_directory=$backend.wsl_crash_directory;$c.final_ux_receipt_sha256=$backend.final_ux_receipt_sha256;$c.final_ui_receipt_sha256=$backend.final_ui_receipt_sha256;$c.final_ui_report_sha256=$backend.final_ui_report_sha256
$c.phase='soak';$c.candidate_directory=$backend.candidate_directory;$c.requires_root_serial_handoff=$true;$c.new_controlled_fixtures_passed=$true;$c.latest_fixture_passed=$true;$c.latest_fixture_count=5
$c.latest_fixture_report=$fixtures;$c.latest_fixture_report_sha256=$master.controlled_fixtures_report_sha256;$c.controlled_fixture_handoff=$fixtures;$c.controlled_fixture_handoff_sha256=$master.controlled_fixtures_report_sha256
$c.status='prepared_not_run_pending_root_serial_handoff';$c.launch_permitted=$false;$c.linux_workload_started=$false;$c.preparation_only=$true;$c.qualified=$false
$c.full_suite_attestation=$attestationPath;$c.full_suite_attestation_sha256=$AttestationSha256;$c.standalone_observation_sha256=$ObservationSha256;$c.current_backend_actual_pass=$true
$c.prerequisite_proofs.full_suite=@{path=$attestationPath;sha256=$AttestationSha256;passed=$true;cases=1508;source_root=$backend.source_root;original_backend_root=$backend.artifact_root}
$c.prerequisite_proofs.full_backend_receipt=@{path=$backend.receipt;sha256=$receiptSHA;passed=$true;actual_windows_exit_code=0;actual_windows_exec_session=46894}
foreach($name in $gates.Keys){$g=$gates[$name];$c.prerequisite_proofs[$name]=@{path=$g.receipt_path;sha256=$g.entry.receipt_sha256;passed=$true;context=$g.context_path;context_sha256=$g.entry.context_sha256;final_report=$g.context.final_report;final_report_sha256=$g.entry.final_report_sha256;original_helper_count=$g.helper_map.Count}}
$c.missing_required_proofs=@();$c.remaining_launch_prerequisites=@('explicit_root_serial_handoff');$c.launch_requires_explicit_serial_handoff=$true
$c.launch_parameters_without_Execute=@{ArtifactRoot=$art;LinuxArtifactRoot=$linuxArt;PythonExecutable=$c.base_python;Controller=$c.controller;ControllerArgumentsFile=$specPath;RunId=$run;TimeoutSeconds=$c.timeout_seconds;CleanupGraceSeconds=30;WslCrashDirectory='C:\Users\piotr\AppData\Local\Temp\wsl-crashes'}
$c.data_dir="/home/piotr/.cache/devbrain-regressions-080/$run";$c.created_utc=[DateTimeOffset]::UtcNow.ToString('o')
$c.all_actual_prerequisites_bound=$true;$c.soak_started=$false;$c.eight_hour_qualification=$false;$c.production_modified=$false
$c.acceptance.continuous_seconds=28800;$c.acceptance.cycle_seconds=900;$c.acceptance.minimum_completed_cycles=32;$c.acceptance.minimum_real_chat_queries=32;$c.acceptance.minimum_real_embedding_queries=32
$c.acceptance.gpu_interval_seconds=5;$c.acceptance.gpu_query_timeout_seconds=3;$c.acceptance.gpu_max_gap_seconds=15;$c.acceptance.account_queries_inside_loop=0
$c.acceptance.final_attestation_required=$true;$c.acceptance.sleep_inhibition_only_for_trial=$true;$c.acceptance.no_interrupted_run_pooling=$true;$c.acceptance.full_suite_attestation_sha256=$AttestationSha256
$c.final_attestation_argv=@($c.python_launcher,'-I','-B',($c.linux_tools+'/attest-full-suite-080.py'),'--mode','soak','--artifact-root',$linuxArt,'--source-root',$c.source_root,'--output',($linuxArt+'/final-eight-hour.json'))
$c.final_attestation_is_future_direct_process=$true;$c.final_attestation_requires_actual_soak_receipt=$true
Artifacts $files $root;foreach($helper in $master.helper_sha256.Keys){Verify (Join-Path $backend.windows_tools $helper) $master.helper_sha256[$helper]}
Verify $ProofManifest $ProofManifestSha256;foreach($name in $gates.Keys){$g=$gates[$name];Verify $g.context_path $g.entry.context_sha256;Verify $g.receipt_path $g.entry.receipt_sha256}
$contextPath=Join-Path $workspace 'evidence/080-eight-hour-deploy-active-context-20261108.json';NewJson $contextPath $c
@{context=$contextPath;sha256=(HashFile $contextPath);run_id=$run;specification_sha256=$c.specification_sha256;input_freeze_sha256=$c.input_freeze_sha256;status=$c.status;launch_permitted=$false;linux_workload_started=$false}|ConvertTo-Json -Depth 5
