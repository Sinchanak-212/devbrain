#Requires -Version 7.5
[CmdletBinding()]
param([switch]$Finalize,[switch]$FinalizeStandalone,[string]$UiContext,[string]$UiContextSha256,[string]$UiReceiptSha256,[string]$UiFinalReportSha256,[long]$UiRootActualExecSession)
if(-not($Finalize-or$FinalizeStandalone)){'NOT_RUN: prepared metadata helper. No Linux/model/8h command exists.';return}
if($Finalize-and$FinalizeStandalone){throw 'Choose one separately reviewed metadata publication'}
if($Finalize-and(-not$UiContext-or$UiContextSha256-cnotmatch'^[0-9a-f]{64}$'-or$UiReceiptSha256-cnotmatch'^[0-9a-f]{64}$'-or$UiFinalReportSha256-cnotmatch'^[0-9a-f]{64}$'-or$UiRootActualExecSession-le0)){throw 'Actual later formal UI root-exit confirmation and all hashes are mandatory before publication'}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace='C:\Users\piotr\OneDrive\Dokumenty\ChatGPT\devbrain'
$sourceHelper=Join-Path $workspace 'release-tools/stage-postbios-bundle-080.ps1'
if((Get-FileHash -LiteralPath $sourceHelper).Hash.ToLowerInvariant()-cne'6a97d4d99d66467d07916ff2f2c3cdf142cbd4f49780615ed5da6bc6602dc619'){throw 'Canonical path helper changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($sourceHelper,[ref]$tok,[ref]$err)
if($err.Count){throw 'Canonical path helper parse failed'}
$add=@($ast.FindAll({param($n)$n-is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-ceq'Add-Type'},$false))
if($add.Count-ne1){throw 'Canonical path helper inventory changed'};. ([scriptblock]::Create($add[0].Extent.Text))
foreach($n in @('NoReparse','HashFile','SourceProof')){$d=@($ast.FindAll({param($x)$x-is[Management.Automation.Language.FunctionDefinitionAst]-and$x.Name-ceq$n},$false));if($d.Count-ne1){throw 'Canonical function changed'};. ([scriptblock]::Create($d[0].Extent.Text))}
# Import reviewed PURE validation/path definitions only. Never invoke the 8h script body or -Stage.
$consumer=Join-Path $workspace 'evidence/stage-final-eight-hour-sidebar-resize-604-20261108.ps1'
if((Get-FileHash -LiteralPath $consumer).Hash.ToLowerInvariant()-cne'3527b2c82c372c4d8764d0ff3a8a4be3e84d6c1e78c503044fe94cc8af9cc5ee'){throw 'Reviewed consumer changed'}
$tok=$null;$err=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($consumer,[ref]$tok,[ref]$err)
if($err.Count){throw 'Consumer definitions parse failed'}
foreach($n in @('Require','PathProof','ReadMap','Verify','NewJson','CopyExact','RelativeFile','SameMap','Artifacts','ProofContext','BoundResult','CleanReceipt','Counts','CompletedGate')){
 $d=@($ast.FindAll({param($x)$x-is[Management.Automation.Language.FunctionDefinitionAst]-and$x.Name-ceq$n},$false));if($d.Count-ne1){throw 'Reviewed validation function changed'};. ([scriptblock]::Create($d[0].Extent.Text))
}
$d=@($ast.FindAll({param($x)$x-is[Management.Automation.Language.FunctionDefinitionAst]-and$x.Name-ceq'CompletedGate'},$false))
$original=$d[0].Extent.Text
$diagnostic=$original.Replace('function CompletedGate(','function OriginalDiagnosticGate(').Replace('$c.status-ceq''passed''','$c.status-ceq''diagnostic_passed_not_release_qualified''-and$c.error_inventory_only-eq$true-and$c.current_ui_passed-eq$false-and$c.source_final-eq$false-and$c.release_qualified-eq$false')
$diagnostic=$diagnostic.Replace('$finalStatus=if($Name-ceq''queue_copy''){''passed_focused_queue_copy_only''}else{''passed''}','$finalStatus=''diagnostic_passed_not_release_qualified''')
Require ($diagnostic-cne$original-and$diagnostic.Contains('function OriginalDiagnosticGate(')-and$diagnostic.Contains('$finalStatus=''diagnostic_passed_not_release_qualified''')) 'Diagnostic validation adaptation missing'
. ([scriptblock]::Create($diagnostic))
$inputPath=Join-Path $workspace 'evidence/post-ui-admission-inputs-20261109.json'
Verify $inputPath '18e5efea6f21815370b4e86c5aa93a503a61d2fa8861eb0d6d967e5ec610c355'
$input=ReadMap $inputPath
Require ($input.status-ceq'prepared_only_no_new_gate_admitted'-and$input.records_published-eq$false) 'Wrong prepared admission inputs'
Verify $input.template_master $input.template_master_sha256;$master=ReadMap $input.template_master
Require ($master.source_freeze_sha256-ceq'ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703'-and$master.helper_count-eq38) 'Current source generation differs'
Verify $master.source_freeze $master.source_freeze_sha256;$source=ReadMap $master.source_freeze
$bundle=Join-Path (Split-Path $master.source_freeze -Parent) 'bundle'
$appFiles=@($source.files.Keys|Where-Object{$_-clike'devbrain/*'});Require ($appFiles.Count-eq198) 'App198 inventory changed'
foreach($rel in $appFiles){Verify (RelativeFile $bundle $rel) $source.files[$rel]}
Verify $master.app_prepare_receipt $master.app_prepare_receipt_sha256
$guardEntry=$input.refs.guard;$g=ProofContext $guardEntry 'current604'
Require ($g.actual_test_count-eq604-and$g.app_freeze_sha256-ceq$master.source_freeze_sha256) 'Wrong current604'
Require ($g.source_root-ceq$master.source_root-and$g.python_launcher-ceq$master.python_launcher) 'Guard source/launcher differs'
$guard=ReadMap (Join-Path $g.artifact_root 'receipt.json');Verify (Join-Path $g.artifact_root 'receipt.json') $guardEntry.receipt_sha256;CleanReceipt $guard $g.run_id;Artifacts $guard.artifact_sha256 $g.artifact_root
SameMap $g.helper_sha256 $master.helper_sha256
foreach($name in $master.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $name) $master.helper_sha256[$name]}
$backendEntry=$input.refs.backend;$backend=ProofContext $backendEntry 'full1561'
Require ($backend.actual_test_count-eq1561-and$backend.app_freeze_sha256-ceq$master.source_freeze_sha256-and$backend.guard_receipt_sha256-ceq$guardEntry.receipt_sha256) 'Wrong current1561'
Require ($backend.source_root-ceq$master.source_root-and$backend.python_launcher-ceq$master.python_launcher) 'Backend source/launcher differs'
Verify $backend.receipt $backendEntry.receipt_sha256;Verify $backend.final_report $backendEntry.final_report_sha256
$receipt=ReadMap $backend.receipt;CleanReceipt $receipt $backend.run_id;Artifacts $receipt.artifact_sha256 $backend.artifact_root
$standaloneEntry=$input.refs.standalone;$envelope=ProofContext $standaloneEntry 'standalone1561'
Verify $standaloneEntry.final_report $standaloneEntry.final_report_sha256;$priorStandalone=ReadMap $standaloneEntry.final_report
Require ($priorStandalone.status-ceq'passed'-and$priorStandalone.actual_windows_exec_session-eq45868-and$priorStandalone.actual_windows_exit_code-eq0-and$priorStandalone.cleanup_complete-eq$true-and$envelope.backend_run_id-ceq$backend.run_id) 'Standalone actual exit incomplete'
$attestationPath=Join-Path $backend.artifact_root 'final-full-suite.json';$observationPath=Join-Path $envelope.artifact_root 'attestation-observation.json'
Verify $attestationPath $standaloneEntry.attestation_sha256;Verify $observationPath $standaloneEntry.observation_sha256
$suite=ReadMap $attestationPath;$observation=ReadMap $observationPath
Require ($suite.final_full_suite_pass-eq$true-and$suite.run_id-ceq$backend.run_id-and$suite.external_receipt_sha256-ceq$backendEntry.receipt_sha256) 'Wrong fullsuite identity'
Counts $suite.counts 1561;Artifacts $suite.artifact_sha256 $backend.artifact_root;SameMap $suite.runtime $master.runtime
$frozen=ReadMap (Join-Path $backend.artifact_root 'frozen-source.json');SameMap $suite.source_hashes $frozen.source_hashes
Require ($envelope.source_freeze_sha256-ceq$master.source_freeze_sha256-and$suite.isolated_package.origin-ceq($master.source_root+'/src/devbrain/__init__.py')) 'Canonical source origin differs'
Require ($observation.passed-eq$true-and$observation.cleanup_complete-eq$true-and$observation.actual_proxy_exit-eq0-and$observation.actual_exit_verified-eq$true-and$observation.stdio_complete-eq$true-and$observation.attestation_validated-eq$true-and$observation.post_exit_observed_seconds-ge30-and$observation.sleep_inhibition.restored-eq$true-and$observation.registered_controller-eq$false-and$observation.manual_pid_birth_cleanup_admission_required-eq$false-and@($observation.errors).Count-eq0) 'Standalone late observation incomplete'
Require ($observation.initial_boot_id-ceq$observation.final_boot_id-and$observation.output_sha256['final-full-suite.json']-ceq$standaloneEntry.attestation_sha256) 'Standalone boot/output differs'
$candidate=$master.candidate_binding;Verify $candidate.context $candidate.context_sha256;$build=ReadMap $candidate.context;Artifacts $build.output_sha256 $build.windows_root
$master.candidate_updater_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0.py'];$master.candidate_zip_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-0.8.0.zip'];$master.candidate_manifest_sha256=$build.output_sha256['releases/candidates/0.8.0/devbrain-update-0.8.0-manifest.json']
if($FinalizeStandalone){
 $out=Join-Path $workspace 'evidence/post-ui-admission-standalone-compatible-20261109.json'
 $v=[ordered]@{schema_version=1;scope='devbrain_standalone_consumer_compatibility_attestation';status='passed';record_kind='new_alias_attestation_of_immutable_completed_process';passed=$true;full_suite_attestation_passed=$true;actual_root_session=$envelope.actual_windows_exec_session;actual_exit_code=0;cleanup_complete=$true;context_sha256=$standaloneEntry.context_sha256;backend_context_sha256=$backendEntry.context_sha256;backend_receipt_sha256=$backendEntry.receipt_sha256;source_freeze_sha256=$master.source_freeze_sha256;canonical=$attestationPath;canonical_sha256=$standaloneEntry.attestation_sha256;observation_sha256=$standaloneEntry.observation_sha256;original_final_report=$standaloneEntry.final_report;original_final_report_sha256=$standaloneEntry.final_report_sha256;counts=$suite.counts;original_reports_or_contexts_modified=$false;new_process_or_model_request=$false;full_release_qualified=$false;eight_hour_started=$false;created_utc=[DateTime]::UtcNow.ToString('o')}
 NewJson $out $v;@{status='standalone_compatibility_attestation_published';path=$out;sha256=(HashFile $out);models_requested=0;eight_hour_started=$false}|ConvertTo-Json;return
}
# Every final publication below requires actual LATER formal UI and all current-source prerequisites.
Verify $UiContext $UiContextSha256;$uiContext=ReadMap $UiContext
Require ($uiContext.actual_windows_exec_session-eq$UiRootActualExecSession-and$UiRootActualExecSession-gt0-and$uiContext.actual_windows_exit_code-eq0-and$uiContext.status-ceq'passed') 'Root has not confirmed actual current UI exit'
$uiEntry=@{context=$UiContext;context_sha256=$UiContextSha256;receipt_sha256=$UiReceiptSha256;final_report_sha256=$UiFinalReportSha256;run_id=$uiContext.run_id}
$expected=@{helper_count=38;scope='devbrain_targeted_regressions';status='regressions_completed_pending_external_watch'}
$gates=[ordered]@{}
$gates.ux=CompletedGate 'ux' $input.refs.ux $expected
$gates.queue_copy=CompletedGate 'queue_copy' $input.refs.queue_copy @{helper_count=38;scope='devbrain_historical_queue_copy_replay';status='queue_copy_completed_pending_external_watch'}
$gates.interactive=CompletedGate 'interactive' $uiEntry @{helper_count=38;scope='devbrain_interactive_ux';status='interactive_ux_completed_pending_external_watch'}
$ux=BoundResult $gates.ux 'regressions-results.json';Counts $ux.counts 381
Require ($ux.modules.Count-eq28-and$ux.individual_test_selectors.Count-eq0-and$ux.normal_conftest-eq$true) 'Whole381/28 required'
$ui=BoundResult $gates.interactive 'interactive-results.json'
Require ($ui.agent_acceptance_passed-eq$true-and$ui.human_acceptance_passed-eq$false-and$ui.baseline_only-eq$false-and$ui.observations.Count-eq8-and$ui.oauth_cache_sync.passed-eq$true-and$ui.oauth_cache_release.passed-eq$true) 'Actual UI/OAuth missing'
foreach($key in @('task:start','task:switch','task:source','task:connection','task:reconnect','geometry:80x24','geometry:120x36','geometry:180x55')){Require ($ui.observations.Contains($key)-and$ui.observations[$key].status-ceq'passed') 'UI observation missing'}
Require ($gates.interactive.final.Contains('visual_acceptance_passed')-and$gates.interactive.final.visual_acceptance_passed-is[bool]-and$gates.interactive.final.visual_acceptance_passed-eq$true-and$gates.interactive.final.photos.Count-eq3) 'Literal formal visual acceptance missing'
foreach($photo in $gates.interactive.final.photos){Require ($photo.window_only-eq$true-and$photo.actual_windows_terminal-eq$true-and$photo.root_personally_visually_reviewed-eq$true-and$photo.readonly_observer_exit_verified-eq$true) 'OS photo proof missing';Verify $photo.png $photo.png_sha256}
$queue=$gates.queue_copy.controller
Require ($queue.all_six_replayed-eq$true-and$queue.jobs.Count-eq6-and@($queue.jobs.id|Sort-Object -Unique).Count-eq6-and$queue.production_modified-eq$false-and$queue.unrelated_jobs_unchanged-eq$true-and$queue.engine_actual_exit_verified-eq$true) 'Exact6copy missing'
SameMap $queue.duplicate_counts_before $queue.duplicate_counts_after
Require (@($queue.jobs|Where-Object{$_.kind-ceq'import'}).Count-eq3-and@($queue.jobs|Where-Object{$_.kind-ceq'extract'}).Count-eq3) 'Queue job set changed'
foreach($job in $queue.jobs){Require ($job.state-ceq'completed'-and$job.attempts-eq($job.previous_attempts+1)) 'Queue completion/attempt mismatch'}
$expectedDiag=@{frontend=$expected;recall=$expected;copilot=@{helper_count=38;scope='devbrain_copilot_account_validation';status='copilot_account_completed_pending_attestation'};upgrade_smoke=@{helper_count=38;scope='devbrain_upgrade_smoke_controller';status='upgrade_smoke_completed_pending_attestation'}}
foreach($name in @('frontend','recall','copilot','upgrade_smoke')){
 $gates[$name]=OriginalDiagnosticGate $name $input.refs[$name] $expectedDiag[$name]
 $execution=$gates[$name].context
 Verify $execution.specification $execution.specification_sha256
 Verify $execution.input_freeze $execution.input_freeze_sha256
 $executionFreeze=ReadMap $execution.input_freeze;Artifacts $executionFreeze.files $execution.windows_root
 Require ($execution.diagnostic_result_must_not_be_substituted_for_formal_release_gate-eq$true) 'Original diagnostic-only provenance was changed'
}
$copilot=BoundResult $gates.copilot 'copilot-results.json'
Require ($copilot.status-ceq'passed'-and$copilot.helper_returncode-eq0-and$copilot.api_key_provided-eq$false) 'Copilot account mode failed'
foreach($key in @('actual_model_ack_verified','file_read_verified','protocol_order_verified','project_unchanged','response_contains_marker','only_owned_database_removed','oauth_store_reused')){Require ($copilot[$key]-eq$true) 'Copilot real protocol check missing'}
$recall=BoundResult $gates.recall 'recall-results.json';$progress=BoundResult $gates.recall 'recall/checkpoint.json'
Require ($recall.status-ceq'passed'-and$recall.golden_count-eq20-and$recall.attempted-eq20-and$recall.scenarios.Count-eq20-and$recall.required_accuracy-eq0.9-and$recall.factual_accuracy-ge0.9-and$recall.critical_facts_passed-eq$true) 'Original20-case threshold failed'
Require ($progress.completed_cases-eq20-and$progress.monitoring.stopped-eq$true-and$progress.monitoring.samples-gt0-and@($progress.monitoring.errors).Count-eq0) 'Recall monitoring incomplete'
Require ($gates.recall.receipt.artifact_sha256.Contains('recall/cases.jsonl')-and$gates.recall.receipt.artifact_sha256.Contains('recall/resources.jsonl')) 'Recall checkpoints unbound'
$cases=@(Get-Content -LiteralPath (Join-Path $gates.recall.context.artifact_root 'recall/cases.jsonl')|ForEach-Object{$_|ConvertFrom-Json -AsHashtable -DateKind String})
Require ($cases.Count-eq20-and@($cases.id|Sort-Object -Unique).Count-eq20-and@((Compare-Object @($cases.id|Sort-Object) @($recall.scenarios.id|Sort-Object))).Count-eq0) 'Recall case identity differs'
foreach($row in $recall.scenarios){Require ($row.status-cin@('passed','failed')-and$row.answer.status-cin@('complete','partial')) 'Unavailable recall answer';if($row.critical){Require ($row.status-ceq'passed') 'Critical recall failed'}}
foreach($row in $cases){Require ($row.status-cin@('passed','failed')-and$row.answer_status-cin@('complete','partial')-and$row.checkpoint_source-ceq'original_score_answer') 'Recall scoring changed'}
Require ($recall.deterministic_checks.Count-gt0) 'Missing deterministic checks';foreach($v in $recall.deterministic_checks.Values){Require ($v-eq$true) 'Deterministic recall failed'}
$front=BoundResult $gates.frontend 'regressions-results.json';$frontExpected=[ordered]@{}
foreach($rel in $source.files.Keys){if($rel-cmatch'^devbrain/frontend/(.+)$'){$frontExpected[$Matches[1]]=$source.files[$rel]}}
Require ($frontExpected.Count-gt0-and$front.status-ceq'passed'-and$front.synthetic_browser_mocks-eq$true-and$front.frozen_web_static_modified-eq$false-and$front.filters.Count-eq0) 'Wholefrontend phase incomplete'
SameMap $gates.frontend.controller.frontend_source_hashes $frontExpected;SameMap $front.source_hashes $frontExpected
foreach($part in @('unit','browser')){Require ($front[$part].passed-eq$(if($part-ceq'unit'){10}else{8})) 'Frontend case count differs';foreach($key in @('failures','errors','skipped')){Require ($front[$part][$key]-eq0) 'Frontend failed case'}}
foreach($step in @('install','unit','build','browser','audit_all','audit_runtime')){Require ($front.steps[$step].returncode-eq0) 'Frontend step failed'}
Require ($front.steps.server_shutdown.actual_exit_verified-eq$true) 'Frontend server exit missing'
$smoke=$gates.upgrade_smoke.controller
Require ($smoke.from_version-ceq'0.7.2'-and$smoke.to_version-ceq'0.8.0'-and$smoke.updater_sha256-ceq$master.candidate_updater_sha256-and$smoke.release_zip_sha256-ceq$master.candidate_zip_sha256-and$smoke.manifest_sha256-ceq$master.candidate_manifest_sha256) 'Candidate smoke changed'
foreach($key in @('all_sources_match_candidate_zip','database_backup_exact_private_and_excludes_credentials','backup_uses_independent_072_wheel_on_qualified_base','real_072_backup_restore_and_080_readback','only_controller_owned_engine_was_used','owned_process_cleanup_complete','only_owned_database_removed','restored_database_removed')){Require ($smoke.checks[$key]-eq$true) 'Smoke acceptance missing'}
Require ($smoke.checks.profiles_keys_auth_config_models_permissions_preserved-gt0-and$smoke.checks.reapply_preserves_bytes_modes_mtimes_inodes-gt0-and$smoke.engine.actual_exit_verified-eq$true-and$smoke.engine.forced_cleanup-eq$false) 'Smoke preservation/engine exit incomplete'
# Publication begins only after ALL actual later UI/current-source/raw functional predicates passed.
$outRoot=Join-Path $workspace 'evidence/post-ui-admission-final-20261109'
Require (-not(Test-Path -LiteralPath $outRoot)) 'Never overwrite a prior or partial admission publication'
NoReparse $outRoot $workspace;[void][IO.Directory]::CreateDirectory($outRoot);$published=[ordered]@{}
$prerequisites=@{interactive=$uiEntry;backend=$backendEntry;standalone=$standaloneEntry;ux=$input.refs.ux;queue_copy=$input.refs.queue_copy;guard=$guardEntry}
foreach($name in @('frontend','recall','copilot','upgrade_smoke')){
 $old=$gates[$name];$e=$input.refs[$name];$reportPath=Join-Path $outRoot ($name+'-admission-report.json')
 $report=[ordered]@{schema_version=1;scope='devbrain_post_UI_same_source_functional_admission';status='passed';record_kind='post_execution_admission_review_not_a_test_rerun';run_id=$old.context.run_id;actual_windows_exec_session=$old.context.actual_windows_exec_session;actual_windows_exit_code=0;cleanup_complete=$true;receipt_sha256=$e.receipt_sha256;source_freeze_sha256=$master.source_freeze_sha256;original_execution_context=$e.context;original_execution_context_sha256=$e.context_sha256;original_diagnostic_final_report=$e.final_report;original_diagnostic_final_report_sha256=$e.final_report_sha256;current_ui_passed_at_execution=$false;error_inventory_only_at_execution=$true;later_same_source_formal_UI_passed_at_admission=$true;prerequisite_proofs=$prerequisites;source_and_helpers_unchanged=$true;real_checks_revalidated=$true;original_diag_flags_and_files_modified=$false;new_model_requests=0;full_release_qualified=$false;eight_hours_started=$false;created_utc=[DateTime]::UtcNow.ToString('o')}
 NewJson $reportPath $report
 $new=[ordered]@{schema_version=1;scope='devbrain_post_UI_same_source_functional_admission_context';status='passed';name=$name;phase=$old.context.phase;run_id=$old.context.run_id;actual_windows_exec_session=$old.context.actual_windows_exec_session;actual_windows_exit_code=0;cleanup_complete=$true;artifact_root=$old.context.artifact_root;linux_artifact_root=$old.context.linux_artifact_root;source_root=$old.context.source_root;python_launcher=$old.context.python_launcher;source_freeze_sha256=$master.source_freeze_sha256;helper_sha256=$master.helper_sha256;reviewed_helper_sha256=$master.helper_sha256;windows_tools=$old.context.windows_tools;linux_tools=$old.context.linux_tools;guard_receipt_sha256=$guardEntry.receipt_sha256;receipt=$old.receipt_path;receipt_sha256=$e.receipt_sha256;specification=$old.context.specification;specification_sha256=$old.context.specification_sha256;execution_input_freeze=$old.context.input_freeze;execution_input_freeze_sha256=$old.context.input_freeze_sha256;final_report=$reportPath;final_report_sha256=(HashFile $reportPath);record_kind='post_execution_admission_review_not_a_test_rerun';original_execution_context=$e.context;original_execution_context_sha256=$e.context_sha256;original_diagnostic_final_report=$e.final_report;original_diagnostic_final_report_sha256=$e.final_report_sha256;current_ui_passed_at_execution=$false;error_inventory_only_at_execution=$true;later_same_source_formal_UI_passed_at_admission=$true;prerequisite_proofs=$prerequisites;application_qualified=$false;release_qualified=$false;production_modified=$false;new_model_requests=0}
 $newPath=Join-Path $outRoot ($name+'-admission-context.json');NewJson $newPath $new
 $published[$name]=@{context=$newPath;context_sha256=(HashFile $newPath);receipt_sha256=$e.receipt_sha256;final_report=$reportPath;final_report_sha256=$new.final_report_sha256;run_id=$new.run_id}
 Verify $e.context $e.context_sha256;Verify $e.final_report $e.final_report_sha256
}
$manifest=Join-Path $outRoot 'admission-manifest.json';NewJson $manifest @{schema_version=1;scope='devbrain_completed_post_UI_admission_records';status='passed';source_freeze_sha256=$master.source_freeze_sha256;records=$published;prerequisites=$prerequisites;original_diagnostic_records_unchanged=$true;new_model_requests=0;release_qualified=$false;eight_hour_started=$false}
@{status='post_UI_admission_records_published';manifest=$manifest;sha256=(HashFile $manifest);records=$published;new_model_requests=0;eight_hour_started=$false}|ConvertTo-Json -Depth 8

