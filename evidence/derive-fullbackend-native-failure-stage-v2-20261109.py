"""Correct raw prepare timestamp interpretation; strengthen final receipt binding."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
old = root / "stage-fullbackend-native-failure-diagnostic-20261109.ps1"
new = root / "stage-fullbackend-native-failure-diagnostic-v2-20261109.ps1"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(old) == "c6ea855592cfbbc67f0f24a8a553d46d0caaa43ed24a7697be3ac1867a447167"
assert not new.exists()
text = old.read_bytes().decode("utf-8")
before = "$freshPrepare.cleanup_confirmed_elapsed_seconds-ge30"
after = "$freshPrepare.cleanup_confirmed_elapsed_seconds-ge0"
assert text.count(before) == 1
text = text.replace(before, after)
anchor = "'Actual final preparation observation missing'"
addition = r'''
Require ($appFinal.passed-eq$true-and$appFinal.preparation_passed-eq$true-and$appFinal.scope_empty_verified-eq$true-and$appFinal.cleanup_grace_seconds-ge30-and$appFinal.forced_cleanup-eq$false-and$appFinal.native_failure-eq$false-and$appFinal.actual_controller_exit_verified-eq$true-and$appFinal.actual_worker_returncode-eq0) 'Final preparation ownership or quiet observation incomplete'
Require ($appFinal.run_id-ceq$app.run_id-and$appFinal.receipt_sha256-ceq$AppPrepareReceiptSha256-and$appFinal.receipt-ceq$app.setup_receipt-and$appFinal.setup_workload_sha256-ceq$freshPrepare.workload_report_sha256-and$app.setup_workload_sha256-ceq$freshPrepare.workload_report_sha256) 'Final preparation raw proof binding differs'
ArtifactHashes $appFinal.raw_artifact_sha256 $app.artifact_root
'''
assert text.count(anchor) == 1
text = text.replace(anchor, anchor + addition)
new.write_bytes(text.encode("utf-8"))
report = {"schema_version": 1, "scope": "fullbackend_diagnostic_stager_actual_prepare_schema_refinement",
          "status": "prepared_not_staged", "prior_stager": str(old), "prior_sha256": sha(old),
          "new_stager": str(new), "new_sha256": sha(new), "timestamp_check": {"before": before, "after": after,
              "reason": "Raw47f cleanup_confirmed_elapsed_seconds is emptyAt timestamp; cleanup_grace_seconds is the >=30 second duration."},
          "new_final_checks": addition, "original_guard_functions_unchanged": True,
          "real_30_second_checks_retained": True, "Stage_or_Linux_invoked": False}
out = root / "fullbackend-native-failure-stage-v2-derivation-20261109.json"
assert not out.exists()
out.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"stager": str(new), "sha256": sha(new), "derivation_sha256": sha(out)}))
