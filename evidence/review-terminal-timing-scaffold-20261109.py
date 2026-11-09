"""Literal scaffold retarget review. Does not execute PowerShell helper bodies."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
replacements = [
    ("probe-native-terminal-input080.py", "probe-native-terminal-timing080.py"),
    ("terminal-input-probe-20261109.py", "terminal-input-timing-probe-v2-20261109.py"),
    ("terminal-input-probe080", "terminal-input-timing-probe080"),
    ("terminal-probe080-", "terminal-timing-probe080-"),
    ("terminal_probe_completed_pending_external_watch", "terminal_timing_probe_completed_pending_external_watch"),
    ("terminal-input-results.json", "terminal-timing-results.json"),
    ("devbrain_no_model_terminal_probe", "devbrain_no_model_terminal_timing_probe"),
    ("080-terminal-input-probe-prepared-context-", "080-terminal-input-timing-probe-prepared-context-"),
    ("DevBrain terminal probe ", "DevBrain terminal timing "),
    ("devbrain_terminal_probe_windows_renderer_launch", "devbrain_terminal_timing_probe_windows_renderer_launch"),
    ("@('direct','bridge')", "@('attached','delayed')"),
]
pairs = [
    ("stage-terminal-input-probe080-20261109.ps1", "stage-terminal-input-timing-probe080-20261109.ps1", "c601a0fb182e46cff8d66f31bd624c2c9d9ff1820c5a17426f4ea11e183b5b5b"),
    ("launch-terminal-input-probe080-20261109.ps1", "launch-terminal-input-timing-probe080-20261109.ps1", "6ef1a268e87314a71f2e6c9d0da6846f1bf2a05bfb67ddc55375245b57d9f05b"),
    ("open-terminal-input-probe080-20261109.ps1", "open-terminal-input-timing-probe080-20261109.ps1", "e51cc386ea31bf55e79cc25e639135d1103797d475a8722826ad5a2dd54957bf"),
    ("observe-terminal-probe-renderers080-20261109.ps1", "observe-terminal-timing-renderers080-20261109.ps1", "111c74bcd51d935da5338d4d2341a7ad20b2c5a4f3fa6018d665e1f2d2926ed1"),
]
rows = []
for old_name, new_name, expected in pairs:
    old, new = root / old_name, root / new_name
    assert sha(new) == expected
    source = old.read_bytes().decode("utf-8")
    changes = []
    for before, after in replacements:
        count = source.count(before)
        if count:
            changes.append({"from": before, "to": after, "count": count})
            source = source.replace(before, after)
    assert source.encode("utf-8") == new.read_bytes(), new_name
    rows.append({"original": old_name, "original_sha256": sha(old), "new": new_name,
                 "new_sha256": expected, "all_other_bytes_unchanged": True, "literal_retargets": changes})
report = {"schema_version": 1, "scope": "readonly_terminal_timing_scaffold_literal_peer", "status": "passed",
          "scripts": rows, "observer_26_pure_negative_cases_passed_in_separate_peer": True,
          "Stage_Execute_or_observer_bodies_invoked": False, "Linux_UI_models_or_auth_started": False,
          "fresh_root_review_GO_required_before_Linux": True}
out = root / "terminal-timing-scaffold-independent-peer-20261109.json"
assert not out.exists()
out.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"status": "passed", "scripts": len(rows), "peer": str(out), "sha256": sha(out)}))
