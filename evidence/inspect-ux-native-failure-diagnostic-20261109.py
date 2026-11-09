"""Windows-only diagnostic evidence inventory; never starts Linux or an application."""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import xml.etree.ElementTree as ET


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def doc(path):
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError("json_object_required")
    return value


def create(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--actual-session", type=int, required=True)
    parser.add_argument("--actual-exit", type=int, required=True)
    args = parser.parse_args()
    if os.name != "nt" or args.actual_session != 69901:
        raise ValueError("exact_actual_windows_session_required")
    evidence = Path(__file__).resolve().parent
    context_path = evidence / "080-ux-native-failure-diagnostic-context-20261109.json"
    c = doc(context_path)
    if c["run_id"] != "ux-uxfailure080-20261109T121905Z-1e5eb045":
        raise ValueError("wrong_diagnostic_run")
    if c.get("actual_windows_exit_code") != args.actual_exit or c.get("status") not in {
        "finished_pending_diagnostic_evidence_review", "failed_pending_diagnostic_cleanup_review"
    }:
        raise ValueError("actual_completion_not_recorded")
    a, root = Path(c["artifact_root"]), Path(c["windows_root"])
    problems, verified = [], {}
    for path, expected in ((Path(c["input_freeze"]), c["input_freeze_sha256"]),
                           (Path(c["specification"]), c["specification_sha256"])):
        if sha(path) != expected:
            problems.append("metadata_digest_mismatch")
        verified[str(path)] = sha(path)
    frozen = doc(c["input_freeze"])
    for name, expected in frozen["files"].items():
        p = root.joinpath(*name.split("/"))
        if not p.is_file() or sha(p) != expected:
            problems.append("frozen_input_digest_mismatch")
        elif name not in {"artifacts/gate.json", "artifacts/spec.json"}:
            verified[str(p)] = expected
    for name, expected in c["helper_sha256"].items():
        if sha(Path(c["windows_tools"]) / name) != expected:
            problems.append("diagnostic_helper_digest_mismatch")
    rows = {}
    for name in ("receipt.json", "supervisor-report.json", "controller-report.json",
                 "regression-source.json", "regressions-results.json", "ux-collection.json"):
        p = a / name
        if p.is_file():
            rows[name] = doc(p)
            verified[str(p)] = sha(p)
        else:
            problems.append("missing_" + name.replace(".", "_"))
    r, s, d = (rows.get(name, {}) for name in
               ("receipt.json", "supervisor-report.json", "controller-report.json"))
    for name, row in rows.items():
        if row.get("run_id") != c["run_id"]:
            problems.append("artifact_run_identity_mismatch")
    counts = Counter()
    failures, latency, frames, nodeids = [], [], [], []
    xml_path = a / "ux.xml"
    if xml_path.is_file():
        verified[str(xml_path)] = sha(xml_path)
        xml = ET.parse(xml_path).getroot()
        for case in xml.iter("testcase"):
            properties = {p.get("name"): p.get("value") for p in case.findall("./properties/property")}
            nodeid = properties.get("nodeid")
            if not nodeid:
                problems.append("junit_nodeid_missing")
                nodeid = case.get("classname", "") + "::" + case.get("name", "")
            nodeids.append(nodeid)
            tags = [tag for tag in ("failure", "error", "skipped") if case.find(tag) is not None]
            outcome = "failed" if "failure" in tags else "error" if "error" in tags else "skipped" if tags else "passed"
            counts[outcome] += 1
            if outcome != "passed":
                failures.append({"nodeid": nodeid, "outcome": outcome,
                                 "raw_details_retained_in_private_junit": True})
            if "test_terminal_latency080.py::" in nodeid:
                allowed = ("keyboard_samples", "controlled_backend_delay_seconds",
                           "keyboard_to_refresh_p95_ms", "maximum_ui_loop_interval_ms")
                measured = {"nodeid": nodeid, "outcome": outcome}
                measured.update({k: properties[k] for k in allowed if k in properties})
                if "keyboard_to_refresh_p95_ms" in measured and "maximum_ui_loop_interval_ms" in measured:
                    p95, loop = (float(measured[k]) for k in ("keyboard_to_refresh_p95_ms", "maximum_ui_loop_interval_ms"))
                    measured["original_thresholds_passed"] = (math.isfinite(p95) and math.isfinite(loop)
                                                               and 0 <= p95 <= 150 and 0 <= loop <= 500)
                latency.append(measured)
            if "resume_notice_render" in properties:
                frame = json.loads(properties["resume_notice_render"])
                frames.append({"nodeid": nodeid, "language": frame.get("language"),
                               "exit_stage": frame.get("exit_stage"), "size": frame.get("size"),
                               "rendered_truncated": frame.get("rendered_truncated"),
                               "rendered_text_not_exported": True})
    else:
        problems.append("missing_ux_xml")
    collection = rows.get("ux-collection.json", {})
    expected = collection.get("nodeids", [])
    parity = len(expected) == len(set(expected)) == len(nodeids) == len(set(nodeids)) == 425 and set(expected) == set(nodeids)
    if not parity:
        problems.append("incomplete_collection_junit_parity")
    source = rows.get("regression-source.json", {}).get("source_hashes", {})
    appfreeze = doc(c["app_freeze"])
    wanted = {name.removeprefix("devbrain/"): value for name, value in appfreeze["files"].items()
              if name in {"devbrain/pyproject.toml", "devbrain/uv.lock"}
              or name.startswith(("devbrain/src/", "devbrain/tests/", "devbrain/data/"))}
    if source != wanted:
        problems.append("source_manifest_not_exact_current_snapshot")
    power_path = a / "power-samples.jsonl"
    power = []
    if power_path.is_file():
        verified[str(power_path)] = sha(power_path)
        power = [json.loads(line) for line in power_path.read_text().splitlines() if line.strip()]
    gate = doc(a / "gate.json")
    power_profile = gate.get("power_profile")
    power_monitor = r.get("power_monitor", {})
    tail_times = [power_monitor.get(key) for key in
                  ("supervisor_exit_elapsed_seconds", "scope_empty_elapsed_seconds")]
    tail_times_valid = all(isinstance(value, (int, float)) and not isinstance(value, bool)
                           and math.isfinite(value) for value in tail_times)
    power_valid = (bool(power_profile) and len(power) >= 2
                   and tail_times_valid
                   and len(power) == power_monitor.get("sample_count")
                   and r.get("power_profile_start") == r.get("power_profile_end") == power_profile
                   and all(row.get("state") == power_profile for row in power)
                   and all(0 <= b["elapsed_seconds"] - x["elapsed_seconds"] <= power_monitor.get("maximum_gap_seconds", 45)
                           for x, b in zip(power, power[1:]))
                   and power[-1]["elapsed_seconds"] >= max(tail_times) + 30)
    if not power_valid:
        problems.append("power_observation_not_complete_and_gate_equal")
    for name, expected_digest in r.get("artifact_sha256", {}).items():
        artifact = a.joinpath(*name.split("/"))
        if not artifact.is_file() or sha(artifact) != expected_digest:
            problems.append("receipt_bound_artifact_mismatch")
    latency_valid = (len(latency) == 2 and all(row.get("original_thresholds_passed") is True
                      and int(row.get("keyboard_samples", 0)) == 50
                      and float(row.get("controlled_backend_delay_seconds", 0)) == 3 for row in latency))
    frames_valid = ({(row.get("language"), row.get("exit_stage")) for row in frames}
                    == {(language, stage) for language in ("en", "pl")
                        for stage in ("fresh_state", "reconcile", "final_state")}
                    and len(frames) == 6 and all(row.get("size") == [80, 24]
                        and row.get("rendered_truncated") is False for row in frames))
    if not latency_valid:
        problems.append("latency_original_threshold_or_sample_contract_not_passed")
    if not frames_valid:
        problems.append("six_en_pl_headless_frames_not_complete")
    boot_stable = bool(r.get("initial_boot_id")) and r.get("initial_boot_id") == r.get("final_boot_id") == s.get("initial_boot_id") == s.get("final_boot_id")
    native_clean = all(row.get("native_failure") is False and row.get("new_wsl_dumps") == [] and row.get("new_kernel_fatals") == [] for row in (r, s))
    engine = d.get("engine", {})
    engine_stopped = (engine.get("actual_exit_verified") is True and engine.get("cleanup_complete") is True
                      and engine.get("graceful_shutdown_requested") is True
                      and engine.get("forced_cleanup") is False and engine.get("returncode") in (0, 143, -15))
    exact_scope = (bool(r.get("scope_unit")) and r.get("scope_unit") == s.get("scope_unit")
                   and r.get("control_group") == s.get("control_group")
                   and r.get("scope_cgroup_identity") == s.get("scope_cgroup_identity"))
    cleanup_observed = (
        exact_scope and r.get("supervisor_exit_verified") is True
        and r.get("scope_empty_verified") is True and r.get("scope_cleanup_grace_seconds", 0) >= 30
        and r.get("cleanup_grace_seconds", 0) >= 30 and r.get("sleep_inhibition", {}).get("restored") is True
        and s.get("controller_exit_verified") is True and s.get("cleanup_complete") is True
        and s.get("scope_descendants_stopped") is True and s.get("remaining_scope_processes") == []
        and s.get("remaining_tagged_processes") == [] and s.get("cleanup_grace_seconds", 0) >= 30
        and d.get("cleanup_complete") is True and d.get("cleanup_grace_seconds", 0) >= 30
        and engine_stopped and boot_stable and native_clean
        and r.get("power_monitor", {}).get("changed") is False and power_valid
    )
    safe_next = cleanup_observed and r.get("forced_cleanup") is False and s.get("forced_cleanup") is False
    result = {
        "schema_version": 1, "scope": "fresh_prototype_complete_UX_diagnostic_inventory_not_release_qualification",
        "saved_utc": datetime.now(timezone.utc).isoformat(), "run_id": c["run_id"],
        "actual_windows_exec_session": args.actual_session, "actual_windows_exit_code": args.actual_exit,
        "diagnostic_only": True, "release_qualified": False, "application_qualified": False,
        "formal_helper_map_qualified": False, "pytest_maxfail": 0, "expected_cases": 425,
        "observed_cases": len(nodeids), "counts": dict(counts), "failed_or_skipped_cases": failures,
        "collection_junit_exact_parity": parity, "whole_modules": len(collection.get("modules", [])),
        "latency": latency, "headless_frames_not_os_photos": frames,
        "raw_receipt_passed": r.get("passed"), "raw_supervisor_passed": s.get("passed"),
        "controller_status": d.get("status"), "owned_cleanup_observed": cleanup_observed,
        "safe_next_owned_workload_only": safe_next, "manual_cleanup_admission_required": not safe_next,
        "native_clean": native_clean, "boot_stable": boot_stable, "exact_scope_identity": exact_scope,
        "scope_unit": r.get("scope_unit"), "scope_identity": r.get("scope_cgroup_identity"),
        "scope_quiet_seconds": r.get("scope_cleanup_grace_seconds"),
        "outer_quiet_seconds": r.get("cleanup_grace_seconds"),
        "sleep_restored": r.get("sleep_inhibition", {}).get("restored"),
        "forced_cleanup_recorded_by_external_wrapper": r.get("forced_cleanup"),
        "power_samples": len(power), "power_changed": r.get("power_monitor", {}).get("changed"),
        "power_observations_verified": power_valid, "latency_contract_passed": latency_valid,
        "six_en_pl_headless_frames_complete": frames_valid,
        "verification_findings": sorted(set(problems)), "artifact_sha256": verified,
        "raw_test_failure_messages_and_private_terminal_output_exported": False,
        "canonical_guard_context_unchanged": sha(c["guard_context"]) == c["guard_context_sha256"],
    }
    result["status"] = ("diagnostic_pass_not_release_qualified" if args.actual_exit == 0 and parity
                        and not failures and not problems and safe_next
                        else "diagnostic_findings_not_release_qualified")
    out = evidence / "080-ux-native-failure-diagnostic-final-inventory-20261109.json"
    create(out, result)
    print(json.dumps({"report": str(out), "sha256": sha(out), "status": result["status"],
                      "counts": dict(counts), "safe_next_owned_workload_only": safe_next,
                      "verification_findings": result["verification_findings"]}))


if __name__ == "__main__":
    main()

