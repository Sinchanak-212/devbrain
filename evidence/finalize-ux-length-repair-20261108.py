"""Windows-only evidence review; never runs an application or Linux command."""
import argparse
import fnmatch
import math
import hashlib
import json
import os
from pathlib import Path
import uuid
import xml.etree.ElementTree as ET
from datetime import datetime, timezone


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def document(path):
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    require(isinstance(value, dict), "Expected JSON object")
    return value


def verify(path, expected):
    require(isinstance(expected, str) and len(expected) == 64, "Missing digest")
    require(digest(path) == expected, "Digest differs: " + str(path))


def relative(root, name):
    require(isinstance(name, str) and name and not name.startswith("/")
            and "\\" not in name and ":" not in name and ".." not in name.split("/"),
            "Unsafe relative artifact")
    result = Path(root).joinpath(*name.split("/"))
    require(result.resolve().is_relative_to(Path(root).resolve()), "Artifact escaped root")
    return result


def verify_map(root, values):
    require(bool(values), "Empty digest map")
    for name, expected in values.items():
        verify(relative(root, name), expected)


def fresh_json(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    return digest(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--finalize", action="store_true")
    parser.add_argument("--root-session", type=int)
    parser.add_argument("--root-actual-exit", type=int)
    args = parser.parse_args()
    if not args.finalize:
        print("NOT_RUN: requires actual root41294 exit0 and completed external receipt.")
        return
    require(os.name == "nt", "Windows-only evidence review")
    require(args.root_session == 41294 and args.root_actual_exit == 0, "Actual root exit0 required")
    evidence = Path(__file__).resolve().parent
    context_path = evidence / "080-ux-length-repair-active-context-20261108.json"
    before_sha = digest(context_path)
    context = document(context_path)
    require(context["run_id"] == "ux-length-repair080-20261108T204650Z-5bc27ae5", "Wrong UX run")
    require(context["status"] in {"finished_pending_evidence_review", "completed_pending_evidence_review"}
            and context["actual_windows_exit_code"] == 0, "Root has not recorded actual completed exit0")
    root, artifacts = Path(context["windows_root"]), Path(context["artifact_root"])
    verify(context["specification"], "0831d6c12c851c36e3edd6e6858e182b010c35b2f909e6d79f99b0257c30d169")
    spec = document(context["specification"])
    require(spec["argv"] == ["--execute", "--phase", "ux", "--run-id", context["run_id"],
            "--artifact-root", context["linux_artifact_root"], "--source-root", context["source_root"],
            "--private-root", "/home/piotr/.cache/devbrain-regressions-080",
            "--arcade-dist", "/home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1"],
            "Whole UX argv differs")
    require(spec["env"] == {"LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}, "Qualified environment differs")
    require(spec["python_launcher"] == context["python_launcher"], "Spec interpreter differs")
    required_artifacts = {"gate.json", "regression-source.json", "regressions-results.json",
                          "controller-report.json", "supervisor-report.json", "ux-collection.json", "ux.xml"}
    require(set(spec["required_artifacts"]) == required_artifacts
            and len(spec["required_artifacts"]) == 7, "Required UX artifacts differ")
    verify(context["input_freeze"], "9655dcfa2a2342fc4b2c3c077cce4c881de2b27371fad599d8b4dc8b53ccfd82")
    inputs = document(context["input_freeze"])
    require(len(inputs["files"]) == 16, "Wrong input count")
    verify_map(root, inputs["files"])
    helpers = context["helper_sha256"]
    require(len(helpers) == 38 and helpers == context["reviewed_helper_sha256"], "Wrong helper map")
    verify_map(context["windows_tools"], helpers)
    rows = {name: document(artifacts / name) for name in (
        "receipt.json", "supervisor-report.json", "controller-report.json",
        "ux-collection.json", "regression-source.json", "regressions-results.json", "gate.json")}
    receipt, supervisor, controller = [rows[name] for name in (
        "receipt.json", "supervisor-report.json", "controller-report.json")]
    collection, frozen, gate = [rows[name] for name in ("ux-collection.json", "regression-source.json", "gate.json")]
    for name, row in rows.items():
        if name != "gate.json":
            require(row["run_id"] == context["run_id"], "Report belongs to another run")
    for row in (receipt, supervisor):
        require(row["passed"] is True and row["child_returncode"] == 0
                and row["controller_exit_verified"] is True, "Actual controller success missing")
        require(row["cleanup_complete"] is True and row["forced_cleanup"] is False
                and row["native_failure"] is False, "Cleanup/native failure")
        for name in ("errors", "new_wsl_dumps", "new_kernel_fatals"):
            require(row[name] == [], "External fatal/error evidence")
        require(row["initial_boot_id"] == row["final_boot_id"] == receipt["initial_boot_id"], "Boot changed")
        require(row["runtime"] == gate["runtime"] and row["python_launcher"] == context["python_launcher"], "Runtime differs")
        require(row["helper_sha256_start"] == row["helper_sha256_end"], "Helper changed during run")
        for name, value in row["helper_sha256_start"].items():
            require(helpers[name] == value, "Unqualified helper used")
    require(receipt["supervisor_returncode"] == receipt["windows_proxy_returncode"] == 0
            and receipt["supervisor_exit_verified"] is True, "Supervisor/proxy exit missing")
    require(receipt["scope_empty_verified"] is True and receipt["scope_membership_verified"] is True
            and receipt["scope_cleanup_grace_seconds"] >= 30 and receipt["cleanup_grace_seconds"] >= 30,
            "Scope/external quiet window incomplete")
    require(receipt["scope_cgroup_identity"] == supervisor["scope_cgroup_identity"]
            and receipt["control_group"] == supervisor["control_group"], "Scope identity differs")
    require(supervisor["remaining_scope_processes"] == supervisor["remaining_tagged_processes"] == []
            and supervisor["scope_descendants_stopped"] is True, "Owned processes remain")
    require(receipt["input_sha256_start"] == receipt["input_sha256_end"], "Observer input changed")
    require(receipt["input_sha256_start"]["arguments"] == context["specification_sha256"], "Wrong observed argv")
    verify(artifacts / "gate.json", context["gate_sha256"])
    verify(artifacts / "controller-report.json", supervisor["controller_report_sha256"])
    verify_map(artifacts, receipt["artifact_sha256"])
    require(required_artifacts | {"power-samples.jsonl"} <= set(receipt["artifact_sha256"]),
            "Required evidence is not bound by the receipt")
    require(receipt["sleep_inhibition"]["restored"] is True and receipt["power_monitor"]["changed"] is False, "Power restoration failed")
    require(receipt["power_profile_start"] == receipt["power_profile_end"] == gate["power_profile"], "Power profile changed")
    power = [json.loads(line) for line in (artifacts / "power-samples.jsonl").read_text().splitlines() if line.strip()]
    require(len(power) == receipt["power_monitor"]["sample_count"] and len(power) >= 2, "Power samples incomplete")
    require(all(sample["state"] == gate["power_profile"] for sample in power), "Power sample changed")
    require(all(0 <= b["elapsed_seconds"] - a["elapsed_seconds"] <= receipt["power_monitor"]["maximum_gap_seconds"]
                for a, b in zip(power, power[1:])), "Power observation gap")
    require(power[-1]["elapsed_seconds"] >= max(receipt["power_monitor"]["supervisor_exit_elapsed_seconds"],
                receipt["power_monitor"]["scope_empty_elapsed_seconds"]) + 30, "Final power observation too early")
    results = rows["regressions-results.json"]
    require(controller["scope"] == "devbrain_targeted_regressions"
            and controller["phase"] == "ux"
            and controller["status"] == "regressions_completed_pending_external_watch"
            and controller["cleanup_complete"] is True and controller["workload_criteria_passed"] is True
            and controller["forced_cleanup"] is False and controller["errors"] == [],
            "UX controller did not complete")
    require(controller["full_suite_pass"] is False and controller["eight_hour_qualification"] is False
            and controller["controller_exit_verified"] is False, "Raw pending flags changed")
    require(controller["python_launcher"] == context["python_launcher"], "Controller launcher differs")
    engine = controller["engine"]
    require(all(engine[key] is True for key in ("started", "ready", "actual_exit_verified",
            "graceful_shutdown_requested", "cleanup_complete"))
            and engine["forced_cleanup"] is False and engine["unexpected_exit_before_shutdown"] is False
            and engine["returncode"] in (0, 143, -15) and controller["cleanup_grace_seconds"] >= 30,
            "Owned JVM cleanup incomplete")
    require(results["phase"] == frozen["phase"] == "ux" and results["status"] == "passed"
            and results["individual_test_selectors"] == [] and results["normal_conftest"] is True
            and results["skips_permitted"] == 0 and results["human_ux_tested"] is False,
            "UX collection contract differs")
    require(set(results["processes"]) == {"collect", "test"}, "Worker evidence missing")
    for process in results["processes"].values():
        require(process["returncode"] == 0 and process["actual_exit_verified"] is True, "Worker exit missing")
    counts = results["counts"]
    require(counts["collected"] == counts["passed"] == 377, "Incomplete377 UX suite")
    for name in ("failures", "errors", "skipped", "unexpected_skips", "duplicates", "missing"):
        require(counts[name] == 0, "Nonpassing test result")
    require(counts["expected_skips"] == counts["observed_skips"] == {}, "Skip allowance present")
    require(collection["scope"] == "devbrain_complete_ux_module_collection"
            and collection["collection_errors"] == collection["deselected"] == [], "Filtered/incomplete collection")
    require(len(collection["nodeids"]) == len(set(collection["nodeids"])) == 377, "Collection not unique377")
    require(collection["modules"] == results["modules"] and len(results["modules"]) == 28,
            "Whole28 module collection differs")
    xml = ET.parse(artifacts / "ux.xml").getroot()
    cases, suites = xml.findall(".//testcase"), xml.findall(".//testsuite")
    require(len(cases) == sum(int(s.attrib["tests"]) for s in suites) == 377, "JUnit count differs")
    require(not xml.findall(".//failure") and not xml.findall(".//error") and not xml.findall(".//skipped"), "JUnit has nonpassing cases")
    nodeids = []
    for case in cases:
        values = [p.attrib["value"] for p in case.findall("./properties/property") if p.attrib.get("name") == "nodeid"]
        require(len(values) == 1, "JUnit nodeid missing/ambiguous")
        nodeids.append(values[0])
    require(len(set(nodeids)) == 377 and set(nodeids) == set(collection["nodeids"]), "JUnit collection mismatch")
    latency, frames = [], []
    frame_pairs = set()
    for case in cases:
        property_items = case.findall("./properties/property")
        require(len({p.attrib["name"] for p in property_items}) == len(property_items), "Duplicate JUnit property")
        properties = {p.attrib["name"]: p.attrib["value"] for p in property_items}
        nodeid = properties["nodeid"]
        if "test_terminal_latency080.py::" in nodeid:
            require(int(properties["keyboard_samples"]) == 50
                    and float(properties["controlled_backend_delay_seconds"]) == 3, "Latency sample contract differs")
            p95 = float(properties["keyboard_to_refresh_p95_ms"])
            loop = float(properties["maximum_ui_loop_interval_ms"])
            require(math.isfinite(p95) and math.isfinite(loop) and 0 <= p95 <= 150 and 0 <= loop <= 500,
                    "Measured latency exceeds original limits")
            latency.append(properties)
        if "resume_notice_render" in properties:
            require(nodeid.startswith("tests/test_terminal_ux080.py::test_keyboard_resume_returns_to_actual_native_pid_and_never_launches_after_exit["),
                    "Notice property belongs to wrong case")
            require(len(properties["resume_notice_render"]) <= 12000, "Oversized synthetic notice")
            frame = json.loads(properties["resume_notice_render"])
            language, stage = frame["language"], frame["exit_stage"]
            require(language in {"en", "pl"} and stage in {"fresh_state", "reconcile", "final_state"}
                    and (language, stage) not in frame_pairs and frame["size"] == [80, 24]
                    and frame["rendered_truncated"] is False, "Notice frame contract differs")
            require(nodeid.endswith("[" + stage + "-" + language + "]"), "Notice case identity differs")
            expected = {"en": "Session ended or changed. Review the project before choosing Start work.",
                        "pl": "Sesja zakończyła się lub zmieniła. Sprawdź projekt przed wybraniem Rozpocznij pracę."}[language]
            require(frame["expected"] == expected and isinstance(frame["rendered_lines"], list)
                    and len(frame["rendered_lines"]) == 24
                    and all(isinstance(line, str) and len(line) <= 160 for line in frame["rendered_lines"]),
                    "Synthetic screen incomplete")
            require(" ".join(expected.split()) in " ".join("\n".join(frame["rendered_lines"]).split()),
                    "Complete localized notice is not visible")
            frame_pairs.add((language, stage))
            frames.append(frame)
    require(len(latency) == 2 and {row["nodeid"] for row in latency} == {
            "tests/test_terminal_latency080.py::test_local_input_remains_responsive_during_three_second_backend_delay[size0]",
            "tests/test_terminal_latency080.py::test_local_input_remains_responsive_during_three_second_backend_delay[size1]"}
            and latency == results["latency_properties"], "Both latency properties must match raw results")
    require(frame_pairs == {(language, stage) for language in ("en", "pl")
                            for stage in ("fresh_state", "reconcile", "final_state")}, "Six EN/PL frames required")
    require(controller["source_hashes"] == frozen["source_hashes"] and len(frozen["source_hashes"]) == 153, "Backend source map differs")
    require(controller["runtime"] == frozen["runtime"] == gate["runtime"]
            and controller["runtime_gate_sha256"] == context["gate_sha256"], "Controller runtime/gate differs")
    app = document(evidence / "080-app-ux-snapshot-active-context.json")
    require(app["run_id"] == "app080-20261108T202627Z" and app["status"] == "prepared_passed"
            and app["actual_windows_exit_code"] == 0 and app["qualified_package_pin_count"] == 59
            and app["pins_unchanged"] is True and app["linux_source_matches_freeze"] is True, "Prepared app/pins differ")
    verify(context["app_freeze"], "1f35dae9f2b3f894bb67535a215e29cba3c1235120ff30daa387bd5450f03e14")
    verify(context["app_prepare_receipt"], "4e18e967ea94bbe43c807e86c65c9d46a2d7205241a9713a7b6406dc8a97526e")
    app_freeze = document(context["app_freeze"])
    require(app_freeze["app_files"] == 198 and len(app_freeze["files"]) == 209, "App inventory differs")
    verify_map(app["bundle_root"], app_freeze["files"])
    expected_source = {name.removeprefix("devbrain/"): value for name, value in app_freeze["files"].items()
                       if name in {"devbrain/pyproject.toml", "devbrain/uv.lock"}
                       or name.startswith(("devbrain/src/", "devbrain/tests/", "devbrain/data/"))}
    require(frozen["source_hashes"] == expected_source, "Backend source is not complete frozen src/tests/data/config")
    require(spec["argv"][spec["argv"].index("--source-root") + 1] == app["source_root"] == context["source_root"],
            "Original source root differs")
    patterns = ("test_terminal*.py", "test_workspace*.py", "test_cockpit*.py", "test_graph*.py", "test_tui*.py", "test_*tui*.py")
    required = {"tests/" + name for name in ("test_api_workspace_e2e.py", "test_api_worker.py", "test_api_panels.py",
                                          "test_client_runtime.py", "test_runtime_pane.py")}
    expected_modules = sorted(required | {name for name in expected_source
        if name.startswith("tests/") and any(fnmatch.fnmatchcase(Path(name).name, pattern) for pattern in patterns)})
    require(results["modules"] == expected_modules and len(expected_modules) == 28, "Module inventory differs from frozen source")
    require({nodeid.split("::", 1)[0] for nodeid in nodeids} == set(expected_modules), "A required module was not tested")
    prep = document(context["app_prepare_receipt"])
    prep_workload = Path(context["app_prepare_receipt"]).parent / "workload-report.json"
    verify(prep_workload, prep["workload_report_sha256"])
    identity = document(prep_workload)["installed_identity"]
    require(len(identity["packages"]) == 59 and identity["prefix"] + "/bin/python" == context["python_launcher"], "Prepared installed59 pins differ")
    require(identity["origin"] == context["source_root"] + "/src/devbrain/__init__.py"
            and identity["base"] == gate["runtime"]["python_executable"], "Prepared package identity differs")
    require(prep["passed"] is True and prep["cleanup_complete"] is True, "Preparation was not complete")
    report = {"schema_version": 1, "scope": "devbrain_current_source_ux_regressions",
              "status": "passed", "recorded_utc": datetime.now(timezone.utc).isoformat(),
              "run_id": context["run_id"], "source_snapshot": app["run_id"], "source_freeze_sha256": context["source_freeze_sha256"],
              "tests": 377, "passed": 377, "failures": 0, "errors": 0, "skipped": 0, "missing": 0, "duplicates": 0,
              "unexpected_skips": 0, "full_collection": True, "junit_nodeids_equal_full_collection": True,
              "test_seconds": sum(float(s.attrib["time"]) for s in suites), "backend_source_files": 153,
              "candidate_source_files": 198, "total_frozen_source_files": 209, "prepared_installed_pins": 59,
              "helper_count": 38, "input_count": 16, "receipt": str(artifacts / "receipt.json"),
              "receipt_sha256": digest(artifacts / "receipt.json"), "junit_sha256": digest(artifacts / "ux.xml"),
              "collection_sha256": digest(artifacts / "ux-collection.json"), "actual_windows_exec_session": 41294,
              "actual_windows_exit_code": 0, "cleanup_complete": True, "forced_cleanup": False, "scope_empty_verified": True,
              "scope_quiet_seconds": receipt["scope_cleanup_grace_seconds"], "external_post_exit_seconds": receipt["cleanup_grace_seconds"],
              "initial_boot_id": receipt["initial_boot_id"], "final_boot_id": receipt["final_boot_id"], "native_failure": False,
              "power_changed": False, "sleep_inhibition_restored": True, "previous_partial_results_pooled": False,
              "human_acceptance_claimed": False, "full_release_qualified": False, "continuous_eight_hours_qualified": False,
              "production_modified": False, "raw_pending_controller_flags_preserved": True, "context_before_review_sha256": before_sha}
    report.update(counts=counts, modules=results["modules"], module_count=28,
                  latency_properties=latency, resume_render_frames=frames,
                  all_six_complete_notice_frames=True, artifact_hashes_verified=True,
                  new_assistant_scope_and_language_regressions_executed=True,
                  frames_are_headless_textual_renders=True, os_screenshots_claimed=False,
                  latency_geometries=[[80, 24], [180, 55]])
    report_path = evidence / "080-ux-length-repair-final-20261108.json"
    report_sha = fresh_json(report_path, report)
    context.update(status="passed", actual_windows_exit_code=0, actual_windows_exec_session=41294,
                   actual_test_count=377, receipt=report["receipt"], receipt_sha256=report["receipt_sha256"],
                   final_report=str(report_path), final_report_sha256=report_sha, cleanup_complete=True,
                   forced_cleanup=False, native_failure=False, scope_empty_verified=True,
                   current_ux_passed=True, evidence_review_finished_utc=report["recorded_utc"])
    pending = context_path.with_name(context_path.name + "." + uuid.uuid4().hex + ".verified")
    context_sha = fresh_json(pending, context)
    require(digest(context_path) == before_sha, "Context changed during review")
    os.replace(pending, context_path)
    require(digest(context_path) == context_sha, "Published context differs")
    print(json.dumps({"context": str(context_path), "context_sha256": context_sha,
                      "report": str(report_path), "report_sha256": report_sha,
                      "receipt_sha256": report["receipt_sha256"], "tests": 377,
                      "status": "passed"}, indent=2))


if __name__ == "__main__":
    main()
