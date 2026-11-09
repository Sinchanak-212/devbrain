"""Create a new Windows-only full-backend stager from the reviewed original."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = root / "evidence/stage-fullbackend-sidebar-resize-604-20261108.ps1"
target = root / "evidence/stage-fullbackend-native-failure-diagnostic-20261109.ps1"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(source) == "de36c4daac4b3589cad3dd9bfa95db7df0a1df34b3756cace6cecd0978e00635"
assert not target.exists()
text = source.read_bytes().decode("utf-8")
changes = []
def replace(before, after):
    global text
    assert text.count(before) == 1, before
    text = text.replace(before, after)
    changes.append({"before": before, "after": after})

replace("param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256)",
        "param([switch]$Stage,[string]$GuardContextSha256,[string]$GuardReceiptSha256,[string]$GuardFinalReportSha256,[string]$AppContextSha256,[string]$AppPrepareReceiptSha256,[string]$AppFinalReportSha256,[long]$AppRootActualExecSession)")
replace("NOT_RUN: actual604 guard context, receipt and final-report SHAs are required. New UI is pending, not presumed passed.",
        "NOT_RUN: actual604 instrumentation plus actual fresh diagnostic App prepare/context/report hashes and root exit are mandatory. No Linux is started.")
block = r'''
# New App preparation is independent of the retained old-source instrumentation
# proof above. Do not retag guard604 or any old backend result as new-source PASS.
$instrumentationSourceSHA=$sourceSHA
$sourceSHA='9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9'
$appPath=Join-Path $workspace 'evidence/080-app-native-failure-diagnostic-prepared-context-20261109.json'
Require ($AppRootActualExecSession-gt0) 'Explicit actual root preparation exit session required'
Verify $appPath $AppContextSha256;$app=ReadMap $appPath
Require ($app.status-ceq'prepared_passed_diagnostic_only'-and$app.actual_windows_exec_session-eq$AppRootActualExecSession-and$app.actual_windows_exit_code-eq0-and$app.cleanup_complete-eq$true-and$app.runtime_prepared-eq$true) 'New App preparation has not actually finished'
Require ($app.source_final-eq$false-and$app.application_qualified-eq$false-and$app.release_qualified-eq$false-and$app.production_modified-eq$false-and$app.eight_hour_started-eq$false) 'Diagnostic source scope must remain explicit'
Require ($app.freeze_sha256-ceq$sourceSHA-and$app.app_files-eq198-and$app.total_files-eq209-and$app.unique_changed_files-eq8-and$app.logical_patch_components-eq9) 'Wrong diagnostic App source'
Require ($app.qualified_package_pin_count-eq59-and$app.pins_unchanged-eq$true-and$app.linux_source_matches_freeze-eq$true) 'New qualified dependencies or Linux source not proven'
Verify $app.freeze_manifest $sourceSHA;$appFreeze=ReadMap $app.freeze_manifest;ArtifactHashes $appFreeze.files $app.bundle_root
Verify $app.input_freeze $app.input_freeze_sha256;ArtifactHashes (ReadMap $app.input_freeze).files $app.windows_root
Require ($app.setup_receipt_sha256-ceq$AppPrepareReceiptSha256-and$app.final_report_sha256-ceq$AppFinalReportSha256) 'New preparation proof binding differs'
Verify $app.setup_receipt $AppPrepareReceiptSha256;$prepareSHA=$AppPrepareReceiptSha256;$freshPrepare=ReadMap $app.setup_receipt
Require ($freshPrepare.scope-ceq'postbios_external_diagnostic_watch'-and$freshPrepare.phase-ceq'prepare'-and$freshPrepare.run_id-ceq$app.run_id-and$freshPrepare.passed-eq$true-and$freshPrepare.proxy_exit_code-eq0-and$freshPrepare.controller_exit_verified-eq$true-and$freshPrepare.cleanup_complete-eq$true) 'New raw prepare receipt is incomplete'
Require ($freshPrepare.forced_cleanup-eq$false-and@($freshPrepare.errors).Count-eq0-and@($freshPrepare.new_wsl_dumps).Count-eq0-and@($freshPrepare.new_kernel_fatals).Count-eq0-and$freshPrepare.initial_boot_id-ceq$freshPrepare.final_boot_id-and$freshPrepare.cleanup_grace_seconds-ge30-and$freshPrepare.cleanup_confirmed_elapsed_seconds-ge30) 'New raw prepare observation failed'
Require ($freshPrepare.runtime_verified_after_cleanup-eq$true-and$freshPrepare.sleep_inhibition.restored-eq$true-and$freshPrepare.power_monitor.changed-eq$false) 'New raw prepare runtime/power/sleep failed'
SameMap $freshPrepare.runtime $receipt.runtime
$freshPrepareDirectory=Split-Path $app.setup_receipt -Parent
$freshControllerPath=Join-Path $freshPrepareDirectory 'controller-report.json';$freshWorkloadPath=Join-Path $freshPrepareDirectory 'workload-report.json'
Verify $freshControllerPath $freshPrepare.controller_report_sha256;Verify $freshWorkloadPath $freshPrepare.workload_report_sha256
$freshController=ReadMap $freshControllerPath;$freshWorkload=ReadMap $freshWorkloadPath
Require ($freshController.run_id-ceq$app.run_id-and$freshController.phase-ceq'prepare'-and$freshController.status-ceq'controller_passed_pending_external_watch'-and$freshController.worker_returncode-eq0-and$freshController.workload_sha256-ceq$freshPrepare.workload_report_sha256-and@($freshController.errors).Count-eq0) 'New actual prepare controller failed'
Require ($freshWorkload.phase-ceq'prepare'-and$freshWorkload.status-ceq'workload_passed_pending_external_watch'-and$freshWorkload.installed_identity.origin-ceq($app.source_root+'/src/devbrain/__init__.py')) 'New actual isolated install differs'
$preparedSource=@{};foreach($key in $appFreeze.files.Keys){if($key.StartsWith('devbrain/')){$preparedSource[$key.Substring(9)]=$appFreeze.files[$key]}}
Require ($preparedSource.Count-eq198) 'New installed source inventory differs';SameMap $freshWorkload.source_manifest $preparedSource
Verify $app.final_report $AppFinalReportSha256;$appFinal=ReadMap $app.final_report
Require ($appFinal.actual_windows_exec_session-eq$AppRootActualExecSession-and$appFinal.actual_windows_exit_code-eq0-and$appFinal.cleanup_complete-eq$true) 'Actual final preparation observation missing'
'''
anchor = "# These unchanged process-supervision fixtures remain evidence only for their"
replace(anchor, block + "\n" + anchor)
replace("$oldBackendPath=Join-Path $workspace 'evidence/080-fullbackend-deploy-active-context-20261108.json'",
        "$oldBackendPath=Join-Path $workspace 'evidence/080-fullbackend-sidebar-resize-active-context-20261108.json'")
replace("Verify $oldBackendPath '7e4e1c2ac76bdce83075577763dbb5ed46ff172b9c1ddc1afadbe8266142bafb'",
        "Verify $oldBackendPath '54c47944a9d53fdbea1d546d56e470b6641403a1bdf07183247d7e4b10830782'")
replace("$contextPath=Join-Path $workspace 'evidence/080-fullbackend-sidebar-resize-active-context-20261108.json'",
        "$contextPath=Join-Path $workspace 'evidence/080-fullbackend-native-failure-diagnostic-active-context-20261109.json'")
replace("$runId='fullbackend-sidebar-resize080-'", "$runId='fullbackend-native-failure080-'")
replace("@($g.app_freeze,'app-source-freeze.json',$sourceSHA)", "@($app.freeze_manifest,'app-source-freeze.json',$sourceSHA)")
replace("@($g.app_prepare_receipt,'app-prepare-receipt.json',$prepareSHA)", "@($app.setup_receipt,'app-prepare-receipt.json',$prepareSHA)")
replace("@($appPath,'app-context.json',(HashFile $appPath)),", "@($appPath,'app-context.json',$AppContextSha256),\n @($app.final_report,'app-final-observation.json',$AppFinalReportSha256),\n @($freshControllerPath,'app-prepare-controller.json',$freshPrepare.controller_report_sha256),\n @($freshWorkloadPath,'app-prepare-workload.json',$freshPrepare.workload_report_sha256),")
replace("$spec.python_launcher=$g.python_launcher", "$spec.python_launcher=$app.python_launcher")
replace("elseif($value -ceq $old.source_root){$value=$g.source_root}", "elseif($value -ceq $old.source_root){$value=$app.source_root}")
replace("$spec.argv[6] -ceq $g.source_root", "$spec.argv[6] -ceq $app.source_root")
replace("python_launcher=$g.python_launcher;source_root=$g.source_root;runtime=$gate.runtime", "python_launcher=$app.python_launcher;source_root=$app.source_root;runtime=$gate.runtime")
replace("app_freeze=$g.app_freeze;app_freeze_sha256=$sourceSHA", "app_freeze=$app.freeze_manifest;app_freeze_sha256=$sourceSHA")
replace("app_prepare_receipt=$g.app_prepare_receipt;app_prepare_receipt_sha256=$prepareSHA", "app_prepare_receipt=$app.setup_receipt;app_prepare_receipt_sha256=$prepareSHA")
replace("expected_test_count=1561;collection_authoritative=$true", "expected_test_count=$null;test_count_assumed=$false;actual_collection_required=$true;collection_authoritative=$true")
replace("current_ui_passed=$false;current_ux_passed=$false;", "error_inventory_only=$true;diagnostic_only=$true;guard_qualifies_current_source=$false;guard_source_freeze_sha256=$instrumentationSourceSHA;guard_purpose='unchanged_instrumentation_provenance_only';candidate_binding_current_source=$false;current_ui_passed=$false;current_ux_passed=$false;")
replace("requires_root_serial_handoff=$true;launch_requires_explicit_serial_handoff=$true;", "requires_root_GO=$true;isolated_parallel_scopes_allowed=$true;launch_requires_explicit_root_GO=$true;")
replace("expected_cases=1561;source_final=$false", "expected_cases=$null;actual_collection_required=$true;source_final=$false")
target.write_bytes(text.encode("utf-8"))
proof = {"schema_version": 1, "scope": "diagnostic_fullbackend_stager_derivation_only", "status": "prepared_not_staged",
         "baseline": str(source), "baseline_sha256": sha(source), "new_stager": str(target),
         "new_stager_sha256": sha(target), "explicit_replacements": changes,
         "new_source_sha256": "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9",
         "actual_fresh_prepare_proofs_required_before_Stage": True, "old_guard_not_new_App_qualification": True,
         "old_fullbackend_results_not_retagged": True, "expected_test_count_assumed": False,
         "canonical38_or_App_files_modified": False, "Stage_or_Linux_invoked": False}
out = root / "evidence/fullbackend-native-failure-stage-derivation-20261109.json"
assert not out.exists()
out.write_text(json.dumps(proof, indent=2), encoding="utf-8")
print(json.dumps({"stager": str(target), "sha256": sha(target), "derivation": str(out), "derivation_sha256": sha(out)}))
