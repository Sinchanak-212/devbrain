"""Windows-only final proof audit, no Linux program or application import."""
import hashlib
import importlib.util
import json
from pathlib import Path

workspace = Path(__file__).resolve().parent.parent
context_path = workspace / "evidence/080-fullbackend-native-failure-diagnostic-active-context-20261109.json"
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
read = lambda path: json.loads(Path(path).read_text(encoding="utf-8-sig"))
c = read(context_path)
assert c["run_id"] == "fullbackend-native-failure080-20261109T122214Z-f4a5d91b"
assert c["actual_windows_exit_code"] == 0 and c["status"] == "diagnostic_completed_pending_evidence_review"
root = Path(c["artifact_root"])
r, sup, ctrl, collection, frozen = [read(root / name) for name in
    ("receipt.json", "supervisor-report.json", "controller-report.json", "collection.json", "frozen-source.json")]
assert all(row["run_id"] == c["run_id"] for row in (r, sup, ctrl, collection, frozen))
tools = Path(c["windows_tools"])
for name, digest in c["helper_sha256"].items():
    assert sha(tools / name) == digest
assert len(c["helper_sha256"]) == 38
for observed in (r, sup):
    assert observed["helper_sha256_start"] == observed["helper_sha256_end"]
    assert all(c["helper_sha256"].get(name) == digest for name, digest in observed["helper_sha256_start"].items())
assert r["input_sha256_start"] == r["input_sha256_end"]
for name, digest in r["artifact_sha256"].items():
    assert sha(root / name) == digest
assert r["artifact_sha256"]["supervisor-report.json"] == sha(root / "supervisor-report.json")
assert sup["controller_report_sha256"] == sha(root / "controller-report.json")
for key in ("passed", "cleanup_complete", "controller_exit_verified", "supervisor_exit_verified", "scope_empty_verified"):
    assert r[key] is True
assert all(type(r[key]) is int and r[key] == 0 for key in ("child_returncode", "supervisor_returncode", "windows_proxy_returncode"))
assert r["native_failure"] is False and r["forced_cleanup"] is False
assert r["cleanup_grace_seconds"] >= 30 and r["scope_cleanup_grace_seconds"] >= 30
assert r["initial_boot_id"] == r["final_boot_id"] == sup["initial_boot_id"] == sup["final_boot_id"]
for key in ("errors", "new_wsl_dumps", "new_kernel_fatals"):
    assert r[key] == sup[key] == []
assert sup["passed"] is True and sup["cleanup_complete"] is True and sup["forced_cleanup"] is False
outside = sup["unobservable_external_processes"]
assert isinstance(outside, list)
assert all(row["reason"] == "inaccessible_same_uid_outside_owned_scope"
           and row["control_group"] != sup["control_group"]
           and type(row["pid"]) is int for row in outside)
verifier = tools / "attest-full-suite-080.py"
assert sha(verifier) == c["helper_sha256"]["attest-full-suite-080.py"]
spec = importlib.util.spec_from_file_location("readonly_fullsuite_verifier", verifier)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
# These canonical functions inspect only documents, local files and numbers.
guard.verify_owned_scope(r, sup)
guard.verify_power_observation(root, r)
guard.verify_gate(read(root / "gate.json"), ctrl["runtime"])
guard.verify_helper_files(r, "run-full-suite-080.py", windows=True)
guard.verify_helper_files(sup, "run-full-suite-080.py", windows=False)
counts = guard.junit_results(root / "pytest.xml", collection["nodeids"], {})
assert counts == ctrl["counts"] and counts["collected"] == counts["passed"] == 1605
assert collection["deselected"] == collection["collection_errors"] == [] and collection["full_test_directory"] == "tests"
assert ctrl["status"] == "full_suite_completed_pending_attestation" and ctrl["cleanup_complete"] is True
assert ctrl["source_unchanged"] is True and ctrl["collection_returncode"] == ctrl["pytest_returncode"] == 0
for key, filename in (("runtime_gate_sha256", "gate.json"), ("frozen_manifest_sha256", "frozen-source.json"),
                       ("collection_sha256", "collection.json"), ("junit_sha256", "pytest.xml")):
    assert ctrl[key] == sha(root / filename)
assert collection["frozen_manifest_sha256"] == sha(root / "frozen-source.json")
assert frozen["source_hashes"] == ctrl["source_hashes"]
assert frozen["expected_skips"] == {}
assert sha(c["app_freeze"]) == "9e5168bece45cf3c06bd0abded7e1573b51cf55778570fdc49c8e0a8872e81b9"
app = read(c["app_freeze"])
for relative, digest in frozen["source_hashes"].items():
    assert digest == app["files"]["devbrain/" + relative]
linux_path = lambda path: Path("//wsl.localhost/Ubuntu" + path)
for relative, digest in frozen["source_hashes"].items():
    assert sha(linux_path(c["source_root"]) / relative) == digest
for name in ("python", "java", "tmux"):
    assert sha(linux_path(ctrl["runtime"][name + "_executable"])) == ctrl["runtime"][name + "_binary_sha256"]
assert ctrl["runtime"] == r["runtime"] == sup["runtime"] == frozen["runtime"]
assert ctrl["isolated_package"]["origin"] == c["source_root"] + "/src/devbrain/__init__.py"
inputs = read(c["input_freeze"])
for relative, digest in inputs["files"].items():
    assert sha(Path(c["windows_root"]) / relative) == digest
out = workspace / "evidence/080-fullbackend-native-failure-diagnostic-final-20261109.json"
assert not out.exists()
report = {"schema_version": 1, "scope": "complete_backend_same_source_diagnostic_evidence",
    "status": "diagnostic_passed_not_release_qualified", "run_id": c["run_id"],
    "actual_windows_exec_session": 74540, "actual_windows_exit_code": 0,
    "actual_final_chunk": "0d36a4", "counts": counts, "complete_backend_tests_passed": True,
    "full_test_directory": "tests", "collection_and_JUnit_exact_nodeids_match": True,
    "collection_sha256": sha(root / "collection.json"), "junit_sha256": sha(root / "pytest.xml"),
    "controller_report_sha256": sha(root / "controller-report.json"),
    "supervisor_report_sha256": sha(root / "supervisor-report.json"), "receipt_sha256": sha(root / "receipt.json"),
    "cleanup_complete": True, "scope_empty_verified": True, "scope_cleanup_grace_seconds": r["scope_cleanup_grace_seconds"],
    "external_cleanup_grace_seconds": r["cleanup_grace_seconds"], "native_failure": False, "forced_cleanup": False,
    "initial_boot_id": r["initial_boot_id"], "final_boot_id": r["final_boot_id"],
    "power_unchanged": True, "sleep_restored": True, "runtime": ctrl["runtime"],
    "canonical_readonly_power_scope_JUnit_helper_verifiers_used": True,
    "canonical_helpers_verified": 38, "Linux_source_hashes_verified_through_UNC": len(frozen["source_hashes"]),
    "frozen_inputs_verified": len(inputs["files"]), "source_freeze_sha256": c["source_freeze_sha256"],
    "source_and_runtime_binary_hashes_unchanged": True, "source_final": False, "error_inventory_only": True,
    "application_qualified": False, "release_qualified": False, "historical_results_retagged": False,
    "canonical_standalone_attestation_executed": False, "standalone_attestation_pending": True,
    "no_new_Linux_programs_started_by_this_audit": True, "production_models_accounts_or_8h_started": False,
    "raw_artifact_sha256": r["artifact_sha256"], "raw_receipt_preserved": True,
    "recovered_heartbeat_atomic_replace_retry_events_retained_in_tool_output": 2}
report["unobservable_same_uid_outside_owned_scope_observations"] = outside
report["unobservable_outside_scope_observations_are_not_owned_cleanup_failures"] = True
out.write_text(json.dumps(report, indent=2), encoding="utf-8")
c.update(status=report["status"], actual_windows_exec_session=74540, actual_windows_exit_code=0,
    cleanup_complete=True, actual_test_count=1605, counts=counts,
    receipt=str(root / "receipt.json"), receipt_sha256=report["receipt_sha256"],
    final_report=str(out), final_report_sha256=sha(out), native_failure=False,
    standalone_attestation_pending=True, source_final=False, application_qualified=False, release_qualified=False)
context_path.write_text(json.dumps(c, indent=2), encoding="utf-8")
print(json.dumps({"status": report["status"], "counts": counts, "report_sha256": sha(out),
                  "context_sha256": sha(context_path), "source_hashes": len(frozen["source_hashes"])}))
