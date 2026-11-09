"""One owned engine for the full native/evaluation regression and final upgrade smoke."""
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
report_path = workspace / "evidence/native-evaluation-post-update-20261107.json"
run_root = Path.home() / ".cache/devbrain-native-regression-20261107" / uuid4().hex[:8]
run_root.mkdir(parents=True, mode=0o700)
for name in list(os.environ):
    if name.startswith("DEVBRAIN_"):
        del os.environ[name]
os.environ["PYTHONPATH"] = str(workspace / "devbrain/src")
os.environ["PATH"] = "/home/piotr/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
os.environ["JAVA_TOOL_OPTIONS"] = "-Xmx1g"
sys.path.insert(0, str(workspace / "devbrain/src"))
from devbrain.config import Settings
from devbrain.engine import install_engine, start_engine, stop_engine

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def phase(name, command):
    print(json.dumps({"phase": name}), flush=True)
    with (run_root / (name + ".log")).open("w") as log:
        result = subprocess.run(command, env=os.environ.copy(), cwd=workspace / "devbrain",
                                stdout=log, stderr=subprocess.STDOUT, check=False)
    print(json.dumps({"phase": name, "returncode": result.returncode}), flush=True)
    report["phases"][name] = {"returncode": result.returncode, "log": str(log.name)}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    assert result.returncode == 0, name

expected_updater = "bf1bd27200108e8e0da5bbbe42d44e7b3eb2736ae74e2886508c8cc5bb097e67"
expected_zip = "6b65e7315895b8c44b84bafc9146dfcdae732c3890f959d0e5e58cbf4fd9aa2c"
assert digest(workspace / "releases/devbrain-update-0.7.2.py") == expected_updater
assert digest(workspace / "releases/devbrain-0.7.2.zip") == expected_zip
settings = Settings.load(run_root / "engine", create=True)
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    settings.arcade_url = "http://127.0.0.1:" + str(listener.getsockname()[1])
settings.save()
report = {"status": "running", "started_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          "kernel": platform.release(), "boot_id": Path("/proc/sys/kernel/random/boot_id").read_text().strip(),
          "run_root": str(run_root), "model_inference": False, "gpu_workload": False,
          "updater_sha256": expected_updater, "zip_sha256": expected_zip, "phases": {},
          "source_sha256": {name: digest(workspace / "devbrain" / name) for name in (
              "src/devbrain/evaluation.py", "tests/test_evaluation.py", "tests/test_native_evaluation.py")}}
report_path.write_text(json.dumps(report, indent=2) + "\n")
try:
    install_engine(settings, Path("/home/piotr/.cache/devbrain-validation-20261107/tooling/arcadedb-26.11.1"))
    start_engine(settings)
    os.environ["DEVBRAIN_TEST_ARCADE_HOME"] = str(settings.data_dir)
    phase("full-evaluation-native", [sys.executable, "-m", "pytest", "-q", "tests/test_evaluation.py",
          "tests/test_native_evaluation.py", "--basetemp", str(run_root / "pytest"),
          "--junitxml", str(workspace / "evidence/native-evaluation-post-update-20261107.xml")])
    phase("final-upgrade-smoke", [sys.executable,
          str(workspace / "release-tools/test_devbrain_update072_smoke.py"), "--root",
          "/home/piotr/.cache/devbrain-upgrade-validation-20261107", "--shared-engine", str(settings.data_dir)])
    phase("ruff-native-test", [sys.executable, "-m", "ruff", "check", "tests/test_native_evaluation.py"])
    assert digest(workspace / "releases/devbrain-update-0.7.2.py") == expected_updater
    assert digest(workspace / "releases/devbrain-0.7.2.zip") == expected_zip
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
