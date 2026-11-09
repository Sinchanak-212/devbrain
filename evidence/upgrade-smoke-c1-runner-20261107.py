"""Single packaging smoke with an isolated C1-only Java engine; no retry."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import socket
import subprocess
import sys
import time
from uuid import uuid4

workspace = Path(__file__).resolve().parents[1]
run_root = Path.home() / ".cache/devbrain-upgrade-validation-20261107" / ("c1-engine-" + uuid4().hex[:8])
run_root.mkdir(parents=True, mode=0o700)
for name in list(os.environ):
    if name.startswith("DEVBRAIN_"):
        del os.environ[name]
os.environ["JAVA_TOOL_OPTIONS"] = "-Xmx1g -XX:TieredStopAtLevel=1"
os.environ["PATH"] = "/home/piotr/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
sys.path.insert(0, str(workspace / "devbrain/src"))
from devbrain.config import Settings
from devbrain.engine import install_engine, start_engine, stop_engine

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

updater_hash = "bf1bd27200108e8e0da5bbbe42d44e7b3eb2736ae74e2886508c8cc5bb097e67"
zip_hash = "6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c"
assert digest(workspace / "releases/devbrain-update-0.7.2.py") == updater_hash
assert digest(workspace / "releases/devbrain-0.7.2.zip") == zip_hash
settings = Settings.load(run_root / "engine", create=True)
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    settings.arcade_url = "http://127.0.0.1:" + str(listener.getsockname()[1])
settings.save()
report_path = workspace / "evidence/devbrain-0.7.2-upgrade-smoke-c1.json"
report = {"status": "running", "started_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          "kernel": platform.release(), "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
          "run_root": str(run_root), "model_inference": False, "gpu_workload": False,
          "updater_sha256": updater_hash, "zip_sha256": zip_hash,
          "runtime_condition": "isolated Java engine; TieredStopAtLevel=1; max heap 1 GiB; no retry"}
report_path.write_text(json.dumps(report, indent=2) + "\n")
try:
    install_engine(settings, Path("/home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1"))
    start_engine(settings)
    pid = json.loads((settings.data_dir / "arcade/process.json").read_text())["pid"]
    engine_environment = Path(f"/proc/{pid}/environ").read_bytes().split(b"\0")
    expected_options = "JAVA_TOOL_OPTIONS=" + os.environ["JAVA_TOOL_OPTIONS"]
    assert expected_options.encode() in engine_environment
    accepted_options = "Picked up JAVA_TOOL_OPTIONS: " + os.environ["JAVA_TOOL_OPTIONS"]
    assert accepted_options in (settings.data_dir / "arcade/engine.log").read_text()
    report["engine_pid"] = pid
    report["accepted_jvm_options"] = accepted_options
    print(json.dumps({"phase": "final-upgrade-smoke", "engine_pid": pid, "tiered_stop_at_level": 1}), flush=True)
    with (run_root / "smoke.log").open("w") as log:
        result = subprocess.run([sys.executable, str(workspace / "release-tools/test_devbrain_update072_smoke.py"),
                                 "--root", "/home/piotr/.cache/devbrain-upgrade-validation-20261107",
                                 "--shared-engine", str(settings.data_dir)],
                                cwd=workspace, stdout=log, stderr=subprocess.STDOUT, check=False)
    report["smoke_returncode"] = result.returncode
    report["smoke_log"] = str(log.name)
    assert result.returncode == 0
    smoke_path = workspace / "evidence/devbrain-0.7.2-upgrade-smoke.json"
    smoke = json.loads(smoke_path.read_text())
    assert smoke["status"] == "passed" and smoke["updater_sha256"] == updater_hash
    assert smoke["release_zip_sha256"] == zip_hash
    assert json.loads((settings.data_dir / "arcade/process.json").read_text())["pid"] == pid
    smoke["runtime_condition"] = report["runtime_condition"]
    smoke["runtime_evidence"] = report_path.name
    smoke_path.write_text(json.dumps(smoke, indent=2) + "\n")
    report["smoke_report"] = str(smoke_path)
    report["status"] = "passed"
except BaseException as error:
    report["status"] = "failed"
    report["error_type"] = type(error).__name__
    raise
finally:
    stop_engine(settings)
    report["owned_engine_stopped"] = True
    report["finished_at_utc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "report": str(report_path)}), flush=True)
