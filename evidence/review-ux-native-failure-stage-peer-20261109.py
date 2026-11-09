import fnmatch
import hashlib
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
read = lambda path: json.loads(Path(path).read_text(encoding="utf-8-sig"))
path = root / "evidence/080-ux-native-failure-diagnostic-context-20261109.json"
assert sha(path) == "1133f98d4c2a8fd97daa3fa8164e90148b5542f140d5006fb0b8a0d83c4286ad"
c = read(path)
assert c["status"] == "prepared_diagnostic_not_run_pending_root_GO" and c["diagnostic_only"] is True
assert all(c[key] is False for key in ("application_qualified", "release_qualified", "source_final", "full_suite_pass", "current_backend_passed", "current_ui_passed", "acceptance_passed", "linux_workload_started", "eight_hour_started"))
assert c["expected_test_count"] is None and c["expected_nodeid_count"] is None
assert c["normal_conftest"] is True and c["deselection_allowed"] is False and c["skip_allowance"] == 0
assert c["actual_collection_authoritative"] is True and c["pytest_maxfail"] == 0
for field in ("specification", "input_freeze", "app_context", "app_prepare_receipt", "app_prepare_final_report", "app_freeze", "toolbundle_freeze"):
    assert sha(c[field]) == c[field + "_sha256"]
assert c["app_context_sha256"] == "387f9f0075a89195e52164c1e83a15261afc7847508ec3462f5f094d9404fd92"
assert c["app_prepare_receipt_sha256"] == "fc63c2782c515d63e8c6e45b1c130d8a16b43904a8b6a050163b4034552db0bd"
assert c["app_prepare_final_report_sha256"] == "b3882183d0921fa8f305de86f27ce3af3fc42b9d9a7211d9ee68b5208e543bed"
app = read(c["app_context"])
assert app["actual_windows_exec_session"] == 43687 and app["actual_windows_exit_code"] == 0 and app["cleanup_complete"] is True
assert c["source_root"] == app["source_root"] and c["python_launcher"] == app["python_launcher"]
f = read(c["input_freeze"])
assert len(f["files"]) == c["frozen_input_count"] == 50
for name, digest in f["files"].items():
    assert sha(Path(c["windows_root"]) / name) == digest
g = read(c["guard_context"])
for name, digest in c["baseline_helper_sha256"].items():
    assert sha(Path(g["windows_tools"]) / name) == digest
old = (Path(g["windows_tools"]) / "run-regressions-080.py").read_bytes()
new = (Path(c["windows_tools"]) / "run-regressions-080.py").read_bytes()
assert old.count(b"--maxfail=1") == 1 and new == old.replace(b"--maxfail=1", b"--maxfail=0")
assert len(old) == len(new) and sum(a != b for a, b in zip(old, new)) == 1
assert sum(c["helper_sha256"][key] == value for key, value in c["baseline_helper_sha256"].items()) == 37
names = [item.name for item in (Path(app["bundle_root"]) / "devbrain/tests").iterdir() if item.is_file()]
patterns = ("test_terminal*.py", "test_workspace*.py", "test_cockpit*.py", "test_graph*.py", "test_tui*.py", "test_*tui*.py")
modules = {"tests/" + name for name in names if any(fnmatch.fnmatchcase(name, pat) for pat in patterns)}
modules.update("tests/" + name for name in ("test_api_workspace_e2e.py", "test_api_worker.py", "test_api_panels.py", "test_client_runtime.py", "test_runtime_pane.py"))
assert modules == set(c["modules"]) and len(modules) == len(c["modules"]) == 28
s = read(c["specification"])
assert s["argv"] == ["--execute", "--phase", "ux", "--run-id", c["run_id"], "--artifact-root", c["linux_artifact_root"], "--source-root", c["source_root"], "--private-root", "/home/piotr/.cache/devbrain-regressions-080", "--arcade-dist", "/home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1"]
out = root / "evidence/080-ux-native-failure-diagnostic-independent-peer-20261109.json"
assert not out.exists()
value = {"status": "passed_for_diagnostic_run_pending_root_GO", "context_sha256": sha(path), "frozen_inputs_verified": 50,
         "whole_canonical_module_discovery": 28, "argv_count": 13, "helper_count": 38, "unchanged_helpers": 37,
         "only_private_one_ASCII_maxfail_1_to_0": True, "fresh_actual_App43687_binding_verified": True,
         "count_not_assumed_or_formal_acceptance_inferred": True, "Linux_models_auth_started": False}
out.write_text(json.dumps(value, indent=2), encoding="utf-8")
print(json.dumps({"peer": str(out), "sha256": sha(out), "status": "passed"}))
