"""Windows-only evidence review; never runs an application or Linux command."""
import argparse
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
        print("NOT_RUN: requires actual root56737 exit0 and completed external receipt.")
        return
    require(os.name == "nt", "Windows-only evidence review")
    require(args.root_session == 56737 and args.root_actual_exit == 0, "Actual root exit0 required")
    evidence = Path(__file__).resolve().parent
    context_path = evidence / "080-fullbackend-sidebar-resize-active-context-20261108.json"
    before_sha = digest(context_path)
    context = document(context_path)
    require(context["run_id"] == "fullbackend-sidebar-resize080-20261109T101110Z-c681f212", "Wrong backend run")
    require(context["status"] in {"finished_pending_evidence_review", "completed_pending_evidence_review"}
            and context["actual_windows_exit_code"] == 0, "Root has not recorded actual completed exit0")
    root, artifacts = Path(context["windows_root"]), Path(context["artifact_root"])
    verify(context["specification"], "8e5576f970d67b78cf13e778674bddfe1f862f41a22efd54d98ff86d8c91defd")
    spec = document(context["specification"])
    require(len(spec["argv"]) == 15 and spec["argv"][0] == "--execute"
            and "--expected-skips" not in spec["argv"] and "--phase" not in spec["argv"], "Whole-suite argv differs")
    require(spec["env"] == {"TMPDIR": "/tmp", "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}, "Qualified environment differs")
    verify(context["input_freeze"], "4e622feac4d2e41e90c21a9a6371251f9b64458fef402fbef67c540fa588ebdc")
    inputs = document(context["input_freeze"])
    require(len(inputs["files"]) == 14, "Wrong input count")
    verify_map(root, inputs["files"])
    helpers = context["helper_sha256"]
    require(len(helpers) == 38 and helpers == context["reviewed_helper_sha256"], "Wrong helper map")
    verify_map(context["windows_tools"], helpers)
    rows = {name: document(artifacts / name) for name in (
        "receipt.json", "supervisor-report.json", "controller-report.json",
        "collection.json", "frozen-source.json", "gate.json")}
    receipt, supervisor, controller = [rows[name] for name in (
        "receipt.json", "supervisor-report.json", "controller-report.json")]
    collection, frozen, gate = [rows[name] for name in ("collection.json", "frozen-source.json", "gate.json")]
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
    require(receipt["sleep_inhibition"]["restored"] is True and receipt["power_monitor"]["changed"] is False, "Power restoration failed")
    require(receipt["power_profile_start"] == receipt["power_profile_end"] == gate["power_profile"], "Power profile changed")
    power = [json.loads(line) for line in (artifacts / "power-samples.jsonl").read_text().splitlines() if line.strip()]
    require(len(power) == receipt["power_monitor"]["sample_count"] and len(power) >= 2, "Power samples incomplete")
    require(all(sample["state"] == gate["power_profile"] for sample in power), "Power sample changed")
    require(all(0 <= b["elapsed_seconds"] - a["elapsed_seconds"] <= receipt["power_monitor"]["maximum_gap_seconds"]
                for a, b in zip(power, power[1:])), "Power observation gap")
    require(power[-1]["elapsed_seconds"] >= max(receipt["power_monitor"]["supervisor_exit_elapsed_seconds"],
                receipt["power_monitor"]["scope_empty_elapsed_seconds"]) + 30, "Final power observation too early")
    require(controller["scope"] == "devbrain_final_full_suite_run"
            and controller["status"] == "full_suite_completed_pending_attestation"
            and controller["cleanup_complete"] is True and controller["source_unchanged"] is True,
            "Whole-suite controller did not complete")
    require(controller["final_full_suite_pass"] is False and controller["controller_exit_verified"] is False,
            "Raw pending-attestation flags changed")
    require(controller["pytest_returncode"] == controller["collection_returncode"] == 0, "Pytest did not exit0")
    counts = controller["counts"]
    require(counts["collected"] == counts["passed"] == 1561, "Incomplete1561 suite")
    for name in ("failures", "errors", "skipped", "unexpected_skips", "duplicates", "missing"):
        require(counts[name] == 0, "Nonpassing test result")
    require(counts["expected_skips"] == counts["observed_skips"] == frozen["expected_skips"] == {}, "Skip allowance present")
    require(collection["full_test_directory"] == "tests"
            and collection["collection_errors"] == collection["deselected"] == [], "Filtered/incomplete collection")
    require(len(collection["nodeids"]) == len(set(collection["nodeids"])) == 1561, "Collection not unique1561")
    xml = ET.parse(artifacts / "pytest.xml").getroot()
    cases, suites = xml.findall(".//testcase"), xml.findall(".//testsuite")
    require(len(cases) == sum(int(s.attrib["tests"]) for s in suites) == 1561, "JUnit count differs")
    require(not xml.findall(".//failure") and not xml.findall(".//error") and not xml.findall(".//skipped"), "JUnit has nonpassing cases")
    nodeids = []
    for case in cases:
        values = [p.attrib["value"] for p in case.findall("./properties/property") if p.attrib.get("name") == "nodeid"]
        require(len(values) == 1, "JUnit nodeid missing/ambiguous")
        nodeids.append(values[0])
    require(len(set(nodeids)) == 1561 and set(nodeids) == set(collection["nodeids"]), "JUnit collection mismatch")
    verify(artifacts / "pytest.xml", controller["junit_sha256"])
    verify(artifacts / "collection.json", controller["collection_sha256"])
    verify(artifacts / "frozen-source.json", controller["frozen_manifest_sha256"])
    require(controller["source_hashes"] == frozen["source_hashes"] and len(frozen["source_hashes"]) == 153, "Backend source map differs")
    require(controller["runtime"] == frozen["runtime"] == gate["runtime"]
            and controller["runtime_gate_sha256"] == frozen["runtime_gate_sha256"] == context["gate_sha256"], "Controller runtime/gate differs")
    app = document(evidence / "080-app-ux-snapshot-active-context.json")
    require(app["run_id"] == "app080-20261108T222731Z" and app["status"] == "prepared_passed"
            and app["actual_windows_exit_code"] == 0 and app["qualified_package_pin_count"] == 59
            and app["pins_unchanged"] is True and app["linux_source_matches_freeze"] is True, "Prepared app/pins differ")
    verify(context["app_freeze"], "ad77e00450537294fd26200d0713915689d82ff5a90e65f6c8fb1285fcbb4703")
    verify(context["app_prepare_receipt"], "4cba08753a5d44463687271f5e695ccddac4d2284ca348b66630f480facde918")
    app_freeze = document(context["app_freeze"])
    require(app_freeze["app_files"] == 198 and len(app_freeze["files"]) == 209, "App inventory differs")
    verify_map(app["bundle_root"], app_freeze["files"])
    expected_source = {name.removeprefix("devbrain/"): value for name, value in app_freeze["files"].items()
                       if name in {"devbrain/pyproject.toml", "devbrain/uv.lock"}
                       or name.startswith(("devbrain/src/", "devbrain/tests/", "devbrain/data/"))}
    require(frozen["source_hashes"] == expected_source, "Backend source is not complete frozen src/tests/data/config")
    package = controller["isolated_package"]
    require(controller["source_root"] == app["source_root"] == context["source_root"], "Original source root differs")
    require(package["origin"] == context["source_root"] + "/src/devbrain/__init__.py"
            and package["sha256"] == expected_source["src/devbrain/__init__.py"]
            and package["python_executable"] == gate["runtime"]["python_executable"]
            and package["python_prefix"] + "/bin/python" == context["python_launcher"], "Isolated package identity differs")
    prep = document(context["app_prepare_receipt"])
    prep_workload = Path(context["app_prepare_receipt"]).parent / "workload-report.json"
    verify(prep_workload, prep["workload_report_sha256"])
    identity = document(prep_workload)["installed_identity"]
    require(len(identity["packages"]) == 59 and identity["prefix"] == package["python_prefix"], "Prepared installed59 pins differ")
    require(prep["passed"] is True and prep["cleanup_complete"] is True, "Preparation was not complete")
    report = {"schema_version": 1, "scope": "devbrain_complete_final_backend_run",
              "status": "passed_pending_standalone_attestation", "recorded_utc": datetime.now(timezone.utc).isoformat(),
              "run_id": context["run_id"], "source_snapshot": app["run_id"], "source_freeze_sha256": context["source_freeze_sha256"],
              "tests": 1561, "passed": 1561, "failures": 0, "errors": 0, "skipped": 0, "missing": 0, "duplicates": 0,
              "unexpected_skips": 0, "full_collection": True, "junit_nodeids_equal_full_collection": True,
              "test_seconds": sum(float(s.attrib["time"]) for s in suites), "backend_source_files": 153,
              "candidate_source_files": 198, "total_frozen_source_files": 209, "prepared_installed_pins": 59,
              "helper_count": 38, "input_count": 14, "receipt": str(artifacts / "receipt.json"),
              "receipt_sha256": digest(artifacts / "receipt.json"), "junit_sha256": controller["junit_sha256"],
              "collection_sha256": controller["collection_sha256"], "actual_windows_exec_session": 56737,
              "actual_windows_exit_code": 0, "cleanup_complete": True, "forced_cleanup": False, "scope_empty_verified": True,
              "scope_quiet_seconds": receipt["scope_cleanup_grace_seconds"], "external_post_exit_seconds": receipt["cleanup_grace_seconds"],
              "initial_boot_id": receipt["initial_boot_id"], "final_boot_id": receipt["final_boot_id"], "native_failure": False,
              "power_changed": False, "sleep_inhibition_restored": True, "previous_partial_results_pooled": False,
              "standalone_attestation_passed": False, "full_release_qualified": False, "continuous_eight_hours_qualified": False,
              "production_modified": False, "raw_pending_controller_flags_preserved": True, "context_before_review_sha256": before_sha}
    report_path = evidence / "080-fullbackend-sidebar-resize-final-20261109.json"
    report_sha = fresh_json(report_path, report)
    context.update(status="passed", actual_windows_exit_code=0, actual_windows_exec_session=56737,
                   actual_test_count=1561, receipt=report["receipt"], receipt_sha256=report["receipt_sha256"],
                   final_report=str(report_path), final_report_sha256=report_sha, cleanup_complete=True,
                   forced_cleanup=False, native_failure=False, scope_empty_verified=True,
                   standalone_attestation_passed=False, evidence_review_finished_utc=report["recorded_utc"])
    pending = context_path.with_name(context_path.name + "." + uuid.uuid4().hex + ".verified")
    context_sha = fresh_json(pending, context)
    require(digest(context_path) == before_sha, "Context changed during review")
    os.replace(pending, context_path)
    require(digest(context_path) == context_sha, "Published context differs")
    print(json.dumps({"context": str(context_path), "context_sha256": context_sha,
                      "report": str(report_path), "report_sha256": report_sha,
                      "receipt_sha256": report["receipt_sha256"], "tests": 1561,
                      "status": "passed_pending_standalone_attestation"}, indent=2))


if __name__ == "__main__":
    main()
