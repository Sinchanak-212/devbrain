"""Windows read-only proof of isolated diagnostic App staging, no helper bodies."""
import ast
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
evidence = root / "evidence"
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
read = lambda path: json.loads(Path(path).read_text(encoding="utf-8-sig"))
context_path = evidence / "080-app-native-failure-diagnostic-prepared-context-20261109.json"
assert sha(context_path) == "8a88e1389dcb53ca87fdd688af7682ae1265f70dc72689f95a7793d190bf9908"
c = read(context_path)
assert c["scope"] == "isolated_diagnostic_app_prepare_only"
assert c["status"] == "prepared_not_run_pending_root_Linux_GO"
assert c["launch_requires_explicit_root_GO"] is True
assert all(c[key] is False for key in ("source_final", "application_qualified", "release_qualified",
    "production_modified", "private_database_started", "models_or_auth_started", "global_app_context_modified",
    "historical_snapshots_modified", "eight_hour_started", "Linux_workload_started", "runtime_prepared"))
for field, digest in [("freeze_manifest", "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9"),
                       ("input_freeze", "073aba9e264c65d598dff07ad614674663c917c9ec6665cda919aec42bb7f343"),
                       ("combined_proposal", "a1ae09656010cadbfc50719f2d6da22004e22a9222247f603c4178e0d4610606")]:
    assert sha(c[field]) == digest
old_context = read(c["previous_app_context"])
assert sha(c["previous_app_context"]) == "d0a5b7e2682cd3f540fcce87446517fb8a11b6712f689aeb6df6dfbf562c771c"
old = read(old_context["freeze_manifest"])
assert sha(old_context["freeze_manifest"]) == "ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703"
new, inputs, proposal = read(c["freeze_manifest"]), read(c["input_freeze"]), read(c["combined_proposal"])
assert len(new["files"]) == len(old["files"]) == 209
changed = {name for name in new["files"] if new["files"][name] != old["files"][name]}
assert changed == set(proposal["files"]) == set(new["approved_changes"])
assert len(changed) == 8 and c["logical_patch_components"] == 9
for name, digest in new["files"].items():
    assert sha(Path(c["bundle_root"]) / name) == digest
for name, digest in old["files"].items():
    assert sha(Path(old_context["bundle_root"]) / name) == digest
    if name.startswith("devbrain/"):
        assert sha(root / name) == digest
assert len(inputs["files"]) == c["frozen_input_count"] == 12
for name, digest in inputs["files"].items():
    assert sha(Path(c["windows_root"]) / name) == digest
assert len(c["canonical_regression_helper_sha256"]) == 38
for name, digest in c["canonical_regression_helper_sha256"].items():
    assert sha(Path(c["canonical_regression_windows_tools"]) / name) == digest
for name in changed:
    assert sha(proposal["files"][name]["proposal_path"]) == new["files"][name]
    ast.parse((Path(c["bundle_root"]) / name).read_text(encoding="utf-8"))

def functions(path):
    tree = ast.parse(Path(path).read_text(encoding="utf-8"))
    return {item.name: ast.dump(item, include_attributes=False) for item in tree.body
            if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))}

combined_test = Path(c["bundle_root"]) / "devbrain/tests/test_terminal_bridge.py"
combined_defs = functions(combined_test)
UX_defs = functions(evidence / "native-failure-ux-proposal-20261109/tests/test_terminal_bridge.py")
TERM_defs = functions(evidence / "native-worker-term-proposal-20261109/tests/test_terminal_bridge.py")
target = "test_native_worker_rebinds_actual_inner_tmux_identity"
assert set(combined_defs) == set(UX_defs)
for name, definition in UX_defs.items():
    assert combined_defs[name] == (TERM_defs[name] if name == target else definition)
assert sha(Path(c["bundle_root"]) / "devbrain/src/devbrain/native_worker.py") == sha(
    evidence / "native-worker-term-proposal-20261109/src/devbrain/native_worker.py")
for name in changed - {"devbrain/src/devbrain/native_worker.py", "devbrain/tests/test_terminal_bridge.py"}:
    assert sha(Path(c["bundle_root"]) / name) == sha(evidence / "native-failure-ux-proposal-20261109" / name.removeprefix("devbrain/"))
assert c["prepare_launcher_sha256"] == "47f20a48b95ef3f2f1e6f16651b3f5dd189e62070a8cddee883bee1d36b5281f"
assert c["prepare_controller_sha256"] == "e9968e2df0489a3f2fe29882b49464e36787507f7354724b22978878c700e197"
assert c["prepare_historical_supervision_helper_sha256"] == "117f482d1d9c14ec9168da69e974cec90a9d0578c1980182c94cd032cba40241"
assert c["requirements_sha256"] == old["files"]["requirements.txt"]
assert c["expected_qualified_package_pin_count"] == 59
params = c["launch_parameters_without_Execute"]
assert params == {"BundleRoot": c["bundle_root"], "ArtifactRoot": c["artifact_root"],
                  "RunId": c["run_id"], "Phase": "prepare", "TimeoutSeconds": 1800}
assert c["actual_collection_required"] is True and c["test_count_assumed"] is False
report = {"schema_version": 1, "scope": "isolated_native_failure_App_stage_independent_readonly_peer",
          "status": "passed_for_fresh_prepare_only_pending_root_GO", "context_sha256": sha(context_path),
          "new_bundle_hashes_verified": 209, "old_bundle_hashes_unchanged": 209,
          "working_App_files_unchanged": 198, "canonical_regression_helpers_unchanged": 38,
          "new_source_freeze_sha256": c["freeze_sha256"], "unique_changed_files": sorted(changed),
          "logical_components": 9, "input_bindings_verified": 12,
          "UX_TERM_test_merge_exact_AST_and_other_test_names_preserved": True,
          "old_prepare_only_pipeline_and_59_pins_unchanged": True,
          "new_root_and_phase_prepare_only_launch_parameters_verified": True,
          "no_runtime_or_application_acceptance_inferred": True,
          "helper_bodies_or_Linux_or_model_or_auth_or_database_started": False,
          "all_runtime_regressions_still_required_on_new_source": True}
out = evidence / "080-app-native-failure-diagnostic-independent-peer-20261109.json"
assert not out.exists()
out.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"status": "passed", "peer": str(out), "sha256": sha(out)}))
