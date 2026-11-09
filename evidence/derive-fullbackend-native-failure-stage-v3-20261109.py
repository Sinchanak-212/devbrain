"""Bind actual legacy prepare power schema; leave canonical GoodReceipt unchanged."""
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parent
old = root / "stage-fullbackend-native-failure-diagnostic-v2-20261109.ps1"
new = root / "stage-fullbackend-native-failure-diagnostic-v3-20261109.ps1"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha(old) == "8866c78af214788e0fd062a34a6c43459c3d3d640d533d1f70e5db1bc0aab18e"
assert not new.exists()
text = old.read_bytes().decode("utf-8")
before = "$freshPrepare.runtime_verified_after_cleanup-eq$true-and$freshPrepare.sleep_inhibition.restored-eq$true-and$freshPrepare.power_monitor.changed-eq$false"
after = "$freshPrepare.runtime_verified_after_cleanup-eq$true-and$freshPrepare.sleep_inhibition.restored-eq$true-and$freshPrepare.power_monitor.sample_count-ge2-and$freshPrepare.power_monitor.maximum_observed_gap_seconds-gt0-and$freshPrepare.power_monitor.maximum_observed_gap_seconds-le15"
assert text.count(before) == 1
text = text.replace(before, after)
anchor = "'New raw prepare runtime/power/sleep failed'"
addition = r'''
Require ($freshPrepare.power_profile_start.active_guid-ceq'381b4222-f694-41f0-9685-ff5bb260df2e'-and$freshPrepare.power_profile_start.active_guid-ceq$freshPrepare.power_profile_end.active_guid-and$freshPrepare.power_profile_start.settings_sha256-ceq'6bac59f1660b69c8c9e8d83728cbb7cf2fd184458181fa05a351b72c4c2d9dc1'-and$freshPrepare.power_profile_start.settings_sha256-ceq$freshPrepare.power_profile_end.settings_sha256-and$freshPrepare.power_profile_start.setting_count-eq183-and$freshPrepare.power_profile_end.setting_count-eq183) 'New prepare qualified Balanced power differs'
'''
assert text.count(anchor) == 1
text = text.replace(anchor, anchor + addition)
assert text.count("$appFinal.preparation_passed-eq$true-and") == 1
text = text.replace("$appFinal.preparation_passed-eq$true-and", "$appFinal.preparation_passed-eq$true-and$appFinal.power_unchanged-eq$true-and")
new.write_bytes(text.encode("utf-8"))
out = root / "fullbackend-native-failure-stage-v3-derivation-20261109.json"
assert not out.exists()
value = {"schema_version": 1, "scope": "fullbackend_actual_legacy_prepare_power_schema_refinement",
         "status": "prepared_not_staged", "prior_sha256": sha(old), "new_sha256": sha(new),
         "old_power_expression": before, "new_power_expression": after, "qualified_Balanced_endpoint_guard": addition,
         "added_final_power_unchanged_required": True, "canonical_GoodReceipt_unchanged": True,
         "Stage_or_Linux_invoked": False}
out.write_text(json.dumps(value, indent=2), encoding="utf-8")
print(json.dumps({"stager": str(new), "sha256": sha(new), "derivation_sha256": sha(out)}))
