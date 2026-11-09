"""Mechanical derivative of reviewed V8 staging, never builds or launches Linux."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
old = root / "evidence/stage-candidate-build-v8-20261108.ps1"
new = root / "evidence/stage-candidate-build-v9-20261109.ps1"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(old) == "21eb822af641c9ab2b95407f908e51e25da19907d8da49b29789dee3d90a5f2a"
assert not new.exists()
text = old.read_bytes().decode("utf-8")
changes = []
def replace(before, after, count=1):
    global text
    assert text.count(before) == count, before
    text = text.replace(before, after)
    changes.append({"before": before, "after": after, "count": count})

replace("candidate v8;", "candidate v9;")
replace("ready-context-v7-20261108.json", "ready-context-v8-20261108.json")
replace("080-app-ux-snapshot-active-context.json", "080-app-native-failure-diagnostic-prepared-context-20261109.json")
replace("cdd27ef8e5326c85ab4f85af562b2826c20f3b63cfd07c454441cb3fbf7766d6", "6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b", 2)
replace("$app.run_id-ceq'app080-20261108T222731Z'-and$app.status-ceq'prepared_passed'", "$app.run_id-ceq'app-uxfailure080-20261109T120522Z-f12a3079'-and$app.status-ceq'prepared_passed_diagnostic_only'-and$app.actual_windows_exec_session-eq43687-and$app.runtime_prepared-eq$true")
replace("ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703", "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9")
replace("Require ($old.launcher_sha256-ceq'2c994a44699c2db5313fc1fb01074e99f960d921d3622c19c6f4a8cb543b9946') 'Approved v7 launcher differs'", "Require ($old.launcher_sha256-ceq'd82c1a3d06f51187d9d005d94e887e8a8022fa0a3cefa1eabca47ee3c9bdd45f') 'Approved v8 launcher differs'")
before = "$expectedChanged=@('devbrain/src/devbrain/terminal_panels.py','devbrain/tests/test_terminal_panels.py')\nRequire (($changed -join '|')-ceq($expectedChanged -join '|')) 'Unexpected app delta from v7'"
after = "$expectedChanged=@('devbrain/src/devbrain/native_worker.py','devbrain/src/devbrain/terminal_bridge.py','devbrain/src/devbrain/terminal_i18n.py','devbrain/src/devbrain/terminal_panels.py','devbrain/src/devbrain/workspace.py','devbrain/tests/test_terminal_bridge.py','devbrain/tests/test_terminal_ux080.py','devbrain/tests/test_workspace_ux080.py')\nRequire ($changed.Count-eq8-and@(Compare-Object @($changed|Sort-Object) @($expectedChanged|Sort-Object)).Count-eq0) 'Unexpected App delta from immutable V8'"
replace(before, after)
old_extra_start = text.index("$extra=@(")
old_extra_end = text.index("foreach($row in $extra)", old_extra_start)
old_extra = text[old_extra_start:old_extra_end]
new_extra = r'''$guardPath=Join-Path $workspace 'evidence/080-guards-queue-budget-active-context-20261108.json'
Verify $guardPath '9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6';$g=ReadMap $guardPath
Require ($g.status-ceq'passed'-and$g.actual_windows_exit_code-eq0-and$g.actual_test_count-eq604-and$g.helper_sha256.Count-eq38) 'Current unchanged instrumentation is unavailable'
Verify $g.receipt '9dca1fd31a494fd015d3ba198af5a7ea453211f93c484bdf5b0d931f33865f84'
foreach($name in $g.helper_sha256.Keys){Verify (Join-Path $g.windows_tools $name) $g.helper_sha256[$name]}
Verify $app.final_report 'b3882183d0921fa8f305de86f27ce3af3fc42b9d9a7211d9ee68b5208e543bed';$actualApp=ReadMap $app.final_report
Require ($actualApp.passed-eq$true-and$actualApp.preparation_passed-eq$true-and$actualApp.actual_windows_exec_session-eq43687-and$actualApp.actual_windows_exit_code-eq0-and$actualApp.cleanup_complete-eq$true-and$actualApp.cleanup_grace_seconds-ge30-and$actualApp.scope_empty_verified-eq$true-and$actualApp.native_failure-eq$false-and$actualApp.power_unchanged-eq$true-and$actualApp.sleep_inhibition_restored-eq$true-and$actualApp.receipt_sha256-ceq$app.setup_receipt_sha256) 'Fresh actual App prepare closure differs'
Require ($app.source_final-eq$false-and$app.application_qualified-eq$false-and$app.release_qualified-eq$false) 'Mechanical candidate cannot qualify this diagnostic source'
$extra=@(
 @('inputs/app-context.json',$appContextPath,$AppContextSha256),
 @('inputs/source-freeze.json',$app.freeze_manifest,$app.freeze_sha256),
 @('inputs/app-prepare-receipt.json',$app.setup_receipt,$app.setup_receipt_sha256),
 @('inputs/app-prepare-final.json',$app.final_report,$app.final_report_sha256),
 @('inputs/combined-proposal.json',(Join-Path $workspace 'evidence/080-native-failure-combined-proposal-20261109.json'),'a1ae09656010cadbfc50719f2d6da22004e22a9222247f603c4178e0d4610606'),
 @('inputs/UX-peer.json',(Join-Path $workspace 'evidence/native-failure-ux-independent-peer-20261109.json'),'e789ec8a8f17ec05d941d251cdb3915486c1420c60d9a625a1cb7330a11e863b'),
 @('inputs/TERM-peer.json',(Join-Path $workspace 'evidence/080-native-worker-term-consistency-peer-20261109.json'),'486e7dcebe4bfd304883f7bddd0baefe4207128aa54a2990fc98cf5ef97e98d5'),
 @('inputs/previous-build-context-v8.json',$oldContextPath,'6d6ce8780c9c4fa9d04d3bfbfca3f2fe1852c1390122605dc5513a82eb2a118b'),
 @('inputs/gate.json',(Join-Path $g.artifact_root 'gate.json'),$g.gate_sha256),
 @('inputs/guard-context.json',$guardPath,'9e9d865acea676f9fab11225c54e49095610e44feb37d9a0b0cd6e882633e6d6'),
 @('inputs/guard-receipt.json',$g.receipt,$g.receipt_sha256),
 @('inputs/toolbundle-freeze.json',$g.freeze_manifest,$g.freeze_sha256)
)
'''
replace(old_extra, new_extra)
replace("$copyOld=@('release-tools/build-devbrain-update-080.py','release-tools/devbrain-update080-template.py','releases/devbrain-0.7.2.zip','inputs/gate.json','inputs/guard-context.json','inputs/guard-receipt.json','inputs/toolbundle-freeze.json')", "$copyOld=@('release-tools/build-devbrain-update-080.py','release-tools/devbrain-update080-template.py','releases/devbrain-0.7.2.zip')")
replace("$runId='final-candidate-sidebar080-'", "$runId='final-candidate-native-failure080-'")
replace("$plan.launch_waits_for=@('Root review and explicit serial handoff; no other Linux workload','Source222731 actual prepare passed; mechanical output remains unqualified and has no current-source UI/application gate claim')", "$plan.launch_waits_for=@('Root review and explicit GO before Linux build; isolated parallel scopes only when Root authorizes','Source9e5168 actual43687 prepare passed; mechanical output remains unqualified, no current-source UI/application claim or8h')")
# Transform the generated observer from immutable V8, including its metadata
# pointers to current604. The eight imported function definitions are checked
# byte-identical below before the historical wrapper pin is retargeted.
start = text.index("$original=[IO.File]::ReadAllText($old.launcher)")
end = text.index("$launcherPath=", start)
old_launcher_transform = text[start:end]
new_launcher_transform = r'''$original=[IO.File]::ReadAllText($old.launcher)
$oldTools=$old.windows_tools
$oldWrapper=Join-Path $oldTools 'run-supervised-080.ps1';$currentWrapper=Join-Path $g.windows_tools 'run-supervised-080.ps1'
Verify $oldWrapper '4cab90d8ee3b0febb6aaf10bc424b76b9b0b7f14a39a5a2df97b978492ba3a74';Verify $currentWrapper $g.helper_sha256['run-supervised-080.ps1']
$ot=$null;$oe=$null;$oa=[Management.Automation.Language.Parser]::ParseFile($oldWrapper,[ref]$ot,[ref]$oe);Require ($oe.Count-eq0) 'Old observer parse differs'
$nt=$null;$ne=$null;$na=[Management.Automation.Language.Parser]::ParseFile($currentWrapper,[ref]$nt,[ref]$ne);Require ($ne.Count-eq0) 'Current observer parse differs'
foreach($name in @('Assert-PlainPath','Convert-LinuxPath','Read-Json','Write-AtomicJson','Get-Sha','Get-CrashMetadata','Start-StreamProcess','Close-StreamProcess')){
 $on=@($oa.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$true));$nn=@($na.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-ceq$name},$true))
 Require ($on.Count-eq1-and$nn.Count-eq1-and$on[0].Extent.Text-ceq$nn[0].Extent.Text) 'Observer function implementation changed'
}
$launcherText=$original.Replace($old.windows_root,$newRoot).Replace('build-input-freeze-v8.json','build-input-freeze-v9.json').Replace('launcher-freeze-v8.json','launcher-freeze-v9.json').Replace('launch-plan-v8.json','launch-plan-v9.json').Replace($oldTools,$g.windows_tools).Replace('4cab90d8ee3b0febb6aaf10bc424b76b9b0b7f14a39a5a2df97b978492ba3a74',$g.helper_sha256['run-supervised-080.ps1'])
Require ($launcherText-cne$original) 'Launcher root transformation missing'
Require ($launcherText.Replace($newRoot,$old.windows_root).Replace('build-input-freeze-v9.json','build-input-freeze-v8.json').Replace('launcher-freeze-v9.json','launcher-freeze-v8.json').Replace('launch-plan-v9.json','launch-plan-v8.json').Replace($g.windows_tools,$oldTools).Replace($g.helper_sha256['run-supervised-080.ps1'],'4cab90d8ee3b0febb6aaf10bc424b76b9b0b7f14a39a5a2df97b978492ba3a74')-ceq$original) 'Unexpected observer semantic change'
'''
replace(old_launcher_transform, new_launcher_transform)
# All remaining v8 metadata names refer to the new output envelope; the
# immutable old-context path above must keep its v8 name.
for before, after in [("launch-plan-v8.json", "launch-plan-v9.json"), ("build-input-freeze-v8.json", "build-input-freeze-v9.json"), ("launcher-freeze-v8.json", "launcher-freeze-v9.json"), ("run-candidate-build-v8.ps1", "run-candidate-build-v9.ps1")]:
    # Do not alter the just-created reversible observer transformation block.
    head, rest = text.split(new_launcher_transform, 1)
    count = head.count(before) + rest.count(before)
    head, rest = head.replace(before, after), rest.replace(before, after)
    text = head + new_launcher_transform + rest
    changes.append({"before": before, "after": after, "outside_transform_count": count})
text = text.replace("scope='devbrain_candidate_build_preparation'", "scope='devbrain_diagnostic_candidate_v9_build_preparation'")
text = text.replace("toolbundle_freeze_sha256=$old.toolbundle_freeze_sha256;guard_receipt_sha256=$old.guard_receipt_sha256;runtime_gate_sha256=$old.runtime_gate_sha256", "toolbundle_freeze_sha256=$g.freeze_sha256;guard_receipt_sha256=$g.receipt_sha256;runtime_gate_sha256=$g.gate_sha256")
text = text.replace("toolbundle_freeze_sha256=$old.toolbundle_freeze_sha256;guard_receipt_sha256=$old.guard_receipt_sha256;guard_count=403", "toolbundle_freeze_sha256=$g.freeze_sha256;guard_receipt_sha256=$g.receipt_sha256;guard_count=604;guard_purpose='unchanged_helpers_only_old_ad77_not_new_App_qualification'")
text = text.replace("runtime_gate_sha256=$old.runtime_gate_sha256;base_python=$old.base_python", "runtime_gate_sha256=$g.gate_sha256;base_python=$g.base_python")
text = text.replace("windows_tools=$old.windows_tools", "windows_tools=$g.windows_tools")
text = text.replace("source_final_qualification=$false;new_guard604_status='not_run'", "source_final_qualification=$false;new_guard604_status='not_run_for_new_source';historical604_helper_instrumentation_only=$true")
text = text.replace("approved_v7_launcher_sha256=$old.launcher_sha256", "approved_v8_launcher_sha256=$old.launcher_sha256")
text = text.replace("'three v7 metadata file names changed to v8'", "'three v8 metadata file names changed to v9','helper pointer and wrapper pin retargeted after eight exact function equality proofs'")
text = text.replace("observer_functions_from_approved_403_bundle=$true", "observer_functions_exact_equal_403_to_current604=$true;canonical_helpers=$g.helper_sha256")
text = text.replace("new_source_diff_only_reviewed_sidebar_resize_files=$changed", "new_source_diff_only_reviewed_UX_TERM_files=$changed")
text = text.replace("sidebar_resize_peer_review_sha256='69fae0b54f8db62cd52e948e06ba2aa4a305a6d774b31a7612a1fcc65ccc817c'", "combined_proposal_sha256='a1ae09656010cadbfc50719f2d6da22004e22a9222247f603c4178e0d4610606'")
text = text.replace("new_guard604_status='not_run';current_source_application_gates_status='not_run';expected_backend_cases=1561;expected_ux_cases=381", "new_guard604_status='not_run_for_new_source';current_source_application_gates_status='pending_not_reused';expected_backend_cases=$null;expected_ux_cases=$null;source_final=$false;release_qualified=$false;eight_hour_started=$false")
replace("ready-context-v8-20261108.json'\nNewJson $contextPath", "ready-context-v9-20261109.json'\nNewJson $contextPath")
new.write_bytes(text.encode("utf-8"))
out = root / "evidence/candidate-v9-stage-derivation-20261109.json"
assert not out.exists()
value = {"schema_version": 1, "scope": "candidate_V9_windows_staging_derivation_only", "status": "prepared_not_staged",
         "baseline_stager_sha256": sha(old), "new_stager_sha256": sha(new), "explicit_replacements": changes,
         "builder_unchanged": "b3783bbd0a193d92e9ff9b24c2abd4926ffbb7aaf10a8edeaa1ebf3485c0d5e9",
         "approved_changed_source_files": 8, "new_source": "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9",
         "current604_used_only_as_unchanged_helper_instrumentation": True, "source_or_global_context_or_prior_V8_modified": False,
         "Stage_build_or_Linux_invoked": False}
out.write_text(json.dumps(value, indent=2), encoding="utf-8")
print(json.dumps({"stager": str(new), "sha256": sha(new), "derivation_sha256": sha(out)}))
