"""Diagnostic real-terminal attach-only viewer. Never starts services, clients or models.

This is a distinct, truthfully registered viewer, not the canonical --attach
entrypoint. The unchanged interactive controller admits its actual qualified
Python identity and its tmux client through pidfds. Only the harness menu is
omitted; product input, control leases and security dialogs remain unchanged.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import os
from pathlib import Path
import pwd
import re
import sys
import time
from uuid import uuid4


def require(condition, code):
    if not condition:
        raise ValueError(code)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--canonical-controller", type=Path, required=True)
    parser.add_argument("--canonical-controller-sha256", required=True)
    parser.add_argument("--viewer-sha256", required=True)
    parser.add_argument("--size", choices=("80x24", "120x36", "180x55"), default="120x36")
    args = parser.parse_args()
    for expected in (args.canonical_controller_sha256, args.viewer_sha256):
        require(re.fullmatch(r"[0-9a-f]{64}", expected), "expected_digest_required")
    own = Path(__file__).resolve(strict=True)
    require(digest(own) == args.viewer_sha256, "viewer_source_digest_mismatch")
    entry = args.canonical_controller
    require(entry.is_absolute() and entry.resolve(strict=True) == entry
            and entry.name == "run-interactive-ux080.py", "canonical_controller_path_required")
    require(digest(entry) == args.canonical_controller_sha256, "canonical_controller_digest_mismatch")
    module_spec = importlib.util.spec_from_file_location("devbrain_real_wt_canonical_attach_support", entry)
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    common, supervision = module.load("validate-native-account080"), module.load("supervise-080")
    manifest = args.manifest
    require(manifest.is_absolute() and manifest.resolve(strict=True) == manifest,
            "canonical_private_manifest_required")
    state = module.private_json(manifest, common)
    require(state.get("scope") == "devbrain_interactive_ux_private" and state.get("status") == "running"
            and state.get("operator") == "agent" and state.get("baseline_only") is False
            and time.time() < state["expires_unix_time"], "fresh_owned_agent_ui_required")
    require(state["helper_sha256"] == state["entrypoint_sha256"] == args.canonical_controller_sha256,
            "actual_owned_controller_entrypoint_mismatch")
    # Do not compare this viewer to the canonical entrypoint and do not rewrite
    # sys.argv[0]; our different actual entrypoint/hash is registered below.
    require(supervision.same_process(state["controller_identity"]), "owned_controller_not_alive")
    runtime = supervision.qualified_runtime(supervision.read_json(Path(state["gate_path"])))
    require(runtime == state["runtime"], "owned_runtime_changed")
    module.installed(Path(state["source_root"]), common)
    work = common.private_directory(Path(state["work_root"]))
    cache = Path(pwd.getpwuid(os.getuid()).pw_dir) / ".cache"
    require(manifest.parent == work and work.is_relative_to(cache)
            and Path(state["data_dir"]) == work / "engine-home", "private_work_scope_mismatch")
    common.private_directory(Path(state["tmp_root"]))
    require(sys.stdin.isatty() and sys.stdout.isatty()
            and os.ttyname(0) == os.ttyname(1), "one_real_interactive_terminal_required")
    expected_size = tuple(map(int, args.size.split("x")))
    require(tuple(os.get_terminal_size(sys.stdout.fileno())) == expected_size,
            "actual_terminal_geometry_mismatch")
    environment = common.clean_environment(work, runtime, state["run_id"], state["native_binaries"])
    os.environ.clear()
    os.environ.update(environment)
    os.environ.update(module.attach_auth_environment(state, common))
    os.environ.update(TERM="xterm-256color", TMPDIR=state["tmp_root"])
    import tempfile
    tempfile.tempdir = None
    from devbrain.config import Settings
    from devbrain.workspace import WorkspaceManager
    manager = WorkspaceManager(Settings.load(Path(state["data_dir"])), tmux_binary=runtime["tmux_executable"])
    try:
        require(str(manager.socket) == state["socket"] and manager.exists(), "existing_owned_workspace_required")
        require(not any(not row["readonly"] for row in manager.clients()),
                "detach_previous_writable_primary_first")
        identity = supervision.identity(os.getpid())
        require(identity and identity["executable"] == runtime["python_executable"]
                and identity["uid"] == os.getuid(), "qualified_actual_viewer_identity_required")
        registration = work / "viewers" / (uuid4().hex + ".json")
        supervision.atomic_json(registration, {
            "identity": identity, "nonce": state["nonce"], "size": args.size, "status": "awaiting_admission",
            "viewer_kind": "real_windows_terminal_attach_only_diagnostic",
            "actual_viewer_entrypoint": str(own), "actual_viewer_sha256": args.viewer_sha256,
            "canonical_controller_entrypoint": str(entry),
            "canonical_controller_sha256": args.canonical_controller_sha256,
            "startup_services_or_models": False, "automatic_product_input": False,
            "canonical_entrypoint_spoofed": False,
        })
        os.chmod(registration, 0o600)
        deadline = time.monotonic() + 10
        while not registration.with_suffix(".admitted").exists():
            require(time.monotonic() < deadline, "viewer_pidfd_admission_timeout")
            require(supervision.same_process(state["controller_identity"])
                    and time.time() < state["expires_unix_time"], "owned_controller_unavailable")
            time.sleep(.1)
        # Existing API enforces identity, attach.lock and UI control lease. It
        # never starts a model; root must verify the actual writer PID/TTY before
        # issuing one explicit Start work through that normal client's keyboard.
        return manager.attach()
    finally:
        manager.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print("real_terminal_attach_failed:" + type(error).__name__, file=sys.stderr)
        raise SystemExit(1)

