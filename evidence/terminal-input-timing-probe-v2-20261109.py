"""Bounded attached-versus-delayed synthetic terminal-query comparison.

Both arms use an actual Windows Terminal outer renderer before native spawn.
The real NativeRuntime/_Channel and RawTerminalBridge are unchanged; only the
in-process broker transport and its explicit subscribe barrier are synthetic.
No model, auth, HTTP, database, or exact Crossterm-parser claim.
Run only inside the separately reviewed qualification scope and observer.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
from copy import deepcopy
from contextlib import asynccontextmanager
import fcntl
import hashlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import pwd
import re
import secrets
import select
import signal
import stat
import struct
import subprocess
import sys
import tempfile
import termios
import time
import tty
from uuid import uuid4

QUERY = b"\x1b[?u\x1b[c\x1b[6n\x1b]10;?\x1b\\\x1b]11;?\x1b\\"
SCOPE = "devbrain_terminal_input_timing_probe_private"


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), Path(__file__).with_name(name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require(value, reason):
    if not value:
        raise ValueError(reason)


def atomic(path, value):
    fd, temporary = tempfile.mkstemp(prefix=".probe-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, separators=(",", ":"))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def private_json(path):
    require(path.is_absolute() and path.resolve(strict=True) == path, "canonical_private_manifest_required")
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd) as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
                and stat.S_IMODE(info.st_mode) == 0o600 and info.st_size < 1024 * 1024,
                "private_manifest_required")
        return json.load(stream)


def dimensions(fd=0):
    rows, columns, _, _ = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
    return [columns, rows]


class ControlClassifier:
    """Bounded framing summary. Never retains/export printable input in a report."""
    def __init__(self):
        self.pending = bytearray()
        self.counts = {}
        self.events = []
        self.printable_bytes = 0
        self.other_control_bytes = 0
        self.bytes = 0

    def event(self, kind, elapsed, length):
        self.counts[kind] = self.counts.get(kind, 0) + 1
        require(len(self.events) < 512, "control_event_budget_exceeded")
        self.events.append({"class": kind, "time_ms": round(elapsed * 1000, 3), "byte_count": length})

    def feed(self, data, elapsed):
        self.bytes += len(data)
        require(self.bytes <= 65536, "terminal_reply_byte_budget_exceeded")
        self.pending.extend(data)
        while self.pending:
            if self.pending[0] != 27:
                value = self.pending.pop(0)
                if 32 <= value <= 126 or value >= 128:
                    self.printable_bytes += 1
                else:
                    self.other_control_bytes += 1
                continue
            if len(self.pending) < 2:
                return
            kind, end = None, None
            if self.pending[1] == ord("["):
                for index in range(2, len(self.pending)):
                    if 0x40 <= self.pending[index] <= 0x7e:
                        end = index + 1
                        break
                if end is None:
                    return
                sequence = bytes(self.pending[:end])
                kind = ("CSI_CURSOR_POSITION" if re.fullmatch(rb"\x1b\[[0-9]+;[0-9]+R", sequence)
                        else "CSI_PRIMARY_DA" if re.fullmatch(rb"\x1b\[\?[0-9;]*c", sequence)
                        else "CSI_SECONDARY_DA" if re.fullmatch(rb"\x1b\[>[0-9;]*c", sequence)
                        else "CSI_KITTY_FLAGS" if re.fullmatch(rb"\x1b\[\?[0-9;]*u", sequence)
                        else "CSI_FOCUS" if sequence in (b"\x1b[I", b"\x1b[O")
                        else "CSI_PASTE_START" if sequence == b"\x1b[200~"
                        else "CSI_PASTE_END" if sequence == b"\x1b[201~"
                        else "CSI_OTHER")
            elif self.pending[1] == ord("]"):
                for index in range(2, len(self.pending)):
                    if self.pending[index] == 7:
                        end = index + 1
                        break
                    if self.pending[index:index + 2] == b"\x1b\\":
                        end = index + 2
                        break
                if end is None:
                    return
                sequence = bytes(self.pending[:end])
                kind = ("OSC10_REPLY" if sequence.startswith(b"\x1b]10;")
                        else "OSC11_REPLY" if sequence.startswith(b"\x1b]11;") else "OSC_OTHER")
            else:
                end, kind = 2, "ESC_OTHER"
            self.event(kind, elapsed, end)
            del self.pending[:end]

    def summary(self):
        prefix = bytes(self.pending[:2])
        tail = ("CSI" if prefix == b"\x1b[" else "OSC" if prefix == b"\x1b]"
                else "ESC" if self.pending else "none")
        return {"control_classes": self.counts, "control_events": self.events,
                "total_input_bytes": self.bytes, "printable_input_byte_count": self.printable_bytes,
                "other_control_byte_count": self.other_control_bytes,
                "incomplete_tail_class": tail, "incomplete_tail_byte_count": len(self.pending),
                "raw_input_exported": False, "exact_crossterm_parser": False}


def child(manifest):
    state = private_json(manifest)
    require(state["scope"] == SCOPE and state["status"] == "running", "child_manifest_invalid")
    work = Path(state["arm_work"])
    attributes = termios.tcgetattr(0)
    flags = fcntl.fcntl(0, fcntl.F_GETFL)
    classifier = ControlClassifier()
    report = {"status": "running", "arm": state["arm"], "capture_limit_seconds": 3,
              "query_names": ["CSI_KITTY_QUERY", "CSI_DA1_QUERY", "CSI_CPR_QUERY", "OSC10_QUERY", "OSC11_QUERY"],
              "query_sha256": hashlib.sha256(QUERY).hexdigest(), "query_emissions": 0,
              "dimensions": [], "snapshots": [], "errors": [], "no_model": True, "no_auth": True,
              "effective_TERM": os.environ.get("TERM") if os.environ.get("TERM") in
                  {"xterm-256color", "tmux-256color"} else "unset_or_other"}
    try:
        tty.setraw(0, termios.TCSANOW)
        os.set_blocking(0, False)
        atomic(work / "child-ready.json", {"status": "ready", "nonce": state["nonce"]})
        deadline = time.monotonic() + max(0, state["expires_unix_time"] - time.time())
        while not (work / "query-go.json").exists():
            require(time.monotonic() < deadline, "renderer_query_barrier_timeout")
            time.sleep(.02)
        go = private_json(work / "query-go.json")
        require(go["nonce"] == state["nonce"], "query_barrier_nonce_mismatch")
        # No keyboard or terminal-response bytes are injected by this program.
        # These are output-only standard queries to the already attached renderer.
        start = time.monotonic()
        report["dimensions"].append({"time_ms": 0, "size": dimensions()})
        view = memoryview(QUERY)
        while view:
            count = os.write(1, view)
            require(count > 0, "query_output_closed")
            view = view[count:]
        report["query_emissions"] = 1
        atomic(work / "query-started.json", {"nonce": state["nonce"], "monotonic": start})
        snapshot_targets = [.250, 1.250]
        while time.monotonic() - start < 3:
            elapsed = time.monotonic() - start
            if snapshot_targets and elapsed >= snapshot_targets[0]:
                target = snapshot_targets.pop(0)
                report["snapshots"].append({"target_ms": round(target * 1000),
                    "actual_ms": round(elapsed * 1000, 3), "framing": deepcopy(classifier.summary())})
            size = dimensions()
            if size != report["dimensions"][-1]["size"]:
                report["dimensions"].append({"time_ms": round((time.monotonic() - start) * 1000, 3), "size": size})
            if select.select([0], [], [], .01)[0]:
                try:
                    data = os.read(0, 4096)
                except BlockingIOError:
                    continue
                require(bool(data), "terminal_input_closed")
                classifier.feed(data, time.monotonic() - start)
        report["snapshots"].append({"target_ms": 3000, "actual_ms": round((time.monotonic() - start) * 1000, 3),
                                    "framing": deepcopy(classifier.summary())})
        report.update(classifier.summary(), elapsed_seconds=time.monotonic() - start, status="captured")
    except Exception as exc:
        report.update(status="failed", errors=[type(exc).__name__])
    finally:
        fcntl.fcntl(0, fcntl.F_SETFL, flags)
        termios.tcsetattr(0, termios.TCSANOW, attributes)
        atomic(work / "child-result.json", report)
    return 0 if report["status"] == "captured" else 1


def verified_state(manifest):
    common, supervision = load("validate-native-account080"), load("supervise-080")
    state = private_json(manifest)
    require(state["scope"] == SCOPE and state["status"] == "running"
            and time.time() < state["expires_unix_time"], "probe_manifest_unavailable")
    require(common.sha(Path(__file__)) == state["helper_sha256"], "probe_helper_changed")
    require(supervision.same_process(state["controller_identity"]), "probe_controller_not_alive")
    require(supervision.qualified_runtime(supervision.read_json(Path(state["gate_path"]))) == state["runtime"],
            "probe_runtime_changed")
    require(Path(state["arm_work"]) == manifest.parent
            and Path(state["arm_work"]).is_relative_to(Path(state["work_root"])), "probe_private_scope_mismatch")
    common.private_directory(Path(state["arm_work"]))
    environment = common.clean_environment(Path(state["work_root"]), state["runtime"], state["run_id"])
    environment.update(TERM="xterm-256color", TMPDIR=state["tmp_root"])
    os.environ.clear()
    os.environ.update(environment)
    tempfile.tempdir = state["tmp_root"]
    return state, common, supervision


def attach(manifest):
    state, common, supervision = verified_state(manifest)
    require(sys.stdin.isatty() and sys.stdout.isatty(), "real_interactive_terminal_required")
    require(dimensions() == [120, 40], "renderer_initial_geometry_mismatch")
    work = Path(state["arm_work"])
    registration = work / "viewers" / (uuid4().hex + ".json")
    atomic(registration, {"identity": supervision.identity(os.getpid()), "nonce": state["nonce"],
                          "status": "awaiting_admission", "arm": state["arm"]})
    deadline = time.monotonic() + 10
    while not registration.with_suffix(".admitted").exists():
        require(time.monotonic() < deadline and supervision.same_process(state["controller_identity"]),
                "renderer_viewer_admission_timeout")
        time.sleep(.025)
    # Exec preserves this admitted PID/birth. Never send a key or synthesize a reply.
    environment = dict(os.environ)
    environment.pop("TMUX", None)
    environment.pop("TMUX_PANE", None)
    binary = state["runtime"]["tmux_executable"]
    os.execve(binary, [binary, "-S", state["socket"], "attach-session", "-t", state["session"]], environment)


async def bridge_async(manifest):
    state, _, supervision = verified_state(manifest)
    work = Path(state["arm_work"])
    # The outer real WT is admitted while this bootstrap waits. There is no
    # native runtime, GET, reconnect or subscribe before the native-created gate.
    while not (work / "native-created.json").exists():
        require(time.time() < state["expires_unix_time"]
                and supervision.same_process(state["controller_identity"]), "native_creation_barrier_timeout")
        await asyncio.sleep(.01)
    created = private_json(work / "native-created.json")
    require(created["nonce"] == state["nonce"], "native_creation_nonce_mismatch")
    state = private_json(manifest)
    require(state["native_run_id"] == created["native_run_id"], "native_created_manifest_mismatch")
    from devbrain.client_runtime import NativeRuntime
    from devbrain.config import Settings
    from devbrain.terminal_bridge import RawTerminalBridge
    runtime = NativeRuntime(Settings.load(Path(state["data_dir"]), create=False),
                            tmux_binary=state["runtime"]["tmux_executable"])
    counts = {"inner_channel_creations": 0, "inner_subscribe_attempts": 0, "inner_refresh_client_commands": 0,
              "resize_frames": [], "input_frames": 0, "input_bytes": 0,
              "broker_transport": "in_process_protocol_test_double", "actual_HTTP_tested": False}
    original_tmux = runtime._tmux
    def counted_tmux(*args, **kwargs):
        if args and args[0] == "refresh-client":
            counts["inner_refresh_client_commands"] += 1
        return original_tmux(*args, **kwargs)
    runtime._tmux = counted_tmux
    class ProtocolSocket:
        def __init__(self, attachment):
            self.attachment = attachment
            self.first = True
        def __aiter__(self):
            return self
        async def __anext__(self):
            if self.first:
                self.first = False
                return json.dumps({"type": "control", "controller": self.attachment.controller})
            event = await self.attachment.queue.get()
            if event.get("type") == "output":
                return json.dumps({"type": "output", "encoding": "base64",
                                   "data": base64.b64encode(event["data"]).decode()})
            if event.get("type") == "control":
                return json.dumps({"type": "control", "controller": self.attachment.controller})
            return json.dumps(event)
        async def send(self, text):
            value = json.loads(text)
            if value["type"] == "resize":
                counts["resize_frames"].append([value["cols"], value["rows"]])
                self.attachment.resize(value["cols"], value["rows"])
            elif value["type"] == "input":
                data = base64.b64decode(value["data"], validate=True)
                counts["input_frames"] += 1
                counts["input_bytes"] += len(data)
                await self.attachment.write(data)
            elif value["type"] == "takeover":
                self.attachment.take_control()
            else:
                raise ValueError("unexpected_testdouble_frame")
    class Client:
        def reconnect(self):
            return None
        def request(self, method, path, **kwargs):
            require(method == "GET" and path == "/api/client-runs/" + state["native_run_id"],
                    "testdouble_status_only")
            return runtime.get_run(state["native_run_id"])
        @asynccontextmanager
        async def terminal(self, run_id, generation):
            atomic(work / "subscribe-waiting.json", {"nonce": state["nonce"], "monotonic": time.monotonic()})
            while not (work / "subscribe-go.json").exists():
                require(time.time() < state["expires_unix_time"]
                        and supervision.same_process(state["controller_identity"]), "subscribe_barrier_timeout")
                await asyncio.sleep(.005)
            go = private_json(work / "subscribe-go.json")
            require(go["nonce"] == state["nonce"], "subscribe_nonce_mismatch")
            counts["subscribe_call_monotonic"] = time.monotonic()
            counts["inner_subscribe_attempts"] += 1
            attachment = await runtime.subscribe(run_id, generation, "synthetic-probe-controller")
            counts["subscribe_return_monotonic"] = time.monotonic()
            counts["inner_channel_creations"] += 1
            try:
                yield ProtocolSocket(attachment)
            finally:
                await attachment.close()
    code, bridge_created = 1, False
    try:
        terminal = RawTerminalBridge(Client(), state["native_run_id"], 1)
        bridge_created = True
        code = await terminal.run()
    finally:
        await runtime.aclose()
        atomic(Path(state["arm_work"]) / "bridge-result.json",
               {"exit_code": code, "counts": counts, "raw_frames_exported": False,
                "effective_TERM": os.environ.get("TERM") if os.environ.get("TERM") in
                    {"xterm-256color", "tmux-256color"} else "unset_or_other",
                "actual_NativeRuntime_Channel": (counts["inner_channel_creations"] > 0
                    and "subscribe_return_monotonic" in counts), "actual_RawTerminalBridge": bridge_created})
    return code


def main_controller(args):
    common, supervision, guard = (load("validate-native-account080"), load("supervise-080"),
                                   load("attest-full-suite-080"))
    require(args.run_id and args.artifact_root and args.source_root and args.private_root
            and 30 <= args.duration <= 120, "explicit_bounded_probe_inputs_required")
    root = args.artifact_root.resolve(strict=True)
    require(root == args.artifact_root and root.is_relative_to(Path("/mnt/c"))
            and not (root / "controller-report.json").exists(), "fresh_external_artifact_root_required")
    runtime = supervision.qualified_runtime(supervision.read_json(root / "gate.json"))
    proof = supervision.read_json(root / "mapping-proof.json")
    scope = supervision.ScopeOwnership(proof.get("scope_unit"))
    parent = supervision.identity(os.getppid())
    require(proof.get("run_id") == args.run_id and os.environ.get("DEVBRAIN_QUALIFICATION_RUN_ID") == args.run_id
            and parent and scope.owns(parent), "owned_supervisor_required")
    origin = importlib.util.find_spec("devbrain")
    require(sys.flags.isolated == 1 and sys.prefix != sys.base_prefix and origin
            and Path(origin.origin).resolve() == args.source_root / "src/devbrain/__init__.py"
            and importlib.metadata.version("devbrain") == "0.8.0", "qualified_isolated_install_required")
    source_hashes = guard.source_manifest(args.source_root)
    report = {"schema_version": 1, "scope": "devbrain_terminal_input_timing_probe", "run_id": args.run_id,
              "runtime": runtime, "python_launcher": sys.executable, "source_hashes": source_hashes,
              "runtime_gate_sha256": common.sha(root / "gate.json"), "status": "starting",
              "cleanup_complete": False, "forced_cleanup": False, "errors": [], "arms": {},
              "local_model_inference": False, "account_requests": 0, "database_started": False,
              "actual_Codex_process_started": False, "security_boundary_bypassed": False,
              "exact_crossterm_parser": False, "production_modified": False,
              "terminal_input_stability_qualified": False, "causal_conclusion": "not_established",
              "comparison_kind": "diagnostic_attach_timing_control_reply_inventory",
              "query_trial_definition": "one_five_query_burst_then_three_seconds_capture_per_arm"}
    old_env, old_umask, old_tempdir = dict(os.environ), os.umask(0o077), tempfile.tempdir
    viewers, owned_handles, child_handles, servers, states = {}, [], [], [], []
    workload_deadline = time.monotonic() + args.duration
    def publish():
        supervision.atomic_json(root / "controller-report.json", report)
        supervision.atomic_json(root / "terminal-timing-results.json", {"run_id": args.run_id, **report})
    def check():
        require(supervision.same_process(parent) and scope.owns(parent) and os.getppid() == parent["pid"],
                "controller_parent_changed")
        require(supervision.qualified_runtime(supervision.read_json(root / "gate.json")) == runtime
                and common.sha(root / "gate.json") == report["runtime_gate_sha256"], "probe_runtime_or_gate_changed")
    def admit(identity):
        require(identity and identity["uid"] == os.getuid()
                and identity["executable"] in (runtime["python_executable"], runtime["tmux_executable"])
                and supervision.same_process(identity), "viewer_identity_not_verified")
        handle = os.pidfd_open(identity["pid"])
        require(supervision.same_process(identity), "viewer_identity_changed")
        return handle
    try:
        publish()
        cache = Path(pwd.getpwuid(os.getuid()).pw_dir) / ".cache"
        common.private_directory(args.private_root)
        require(args.private_root.is_absolute() and args.private_root.resolve() == args.private_root
                and args.private_root.is_relative_to(cache), "private_cache_required")
        work = common.private_directory(args.private_root / ("terminal-probe-" + uuid4().hex), create=True)
        for name in ("home", "codex-auth", "claude-auth", "tmp", "bin", "engine-home"):
            common.private_directory(work / name, create=True)
        short_tmp = common.private_directory(Path("/tmp") / ("dbtp-" + uuid4().hex[:12]), create=True)
        environment = common.clean_environment(work, runtime, args.run_id)
        environment["TMPDIR"] = str(short_tmp)
        environment["TERM"] = "xterm-256color"
        os.environ.clear()
        os.environ.update(environment)
        tempfile.tempdir = str(short_tmp)
        from devbrain.client_runtime import NativeRuntime
        from devbrain.config import Settings
        global_expiry = time.time() + max(0, workload_deadline - time.monotonic())
        for arm in ("attached", "delayed"):
            check()
            arm_work = common.private_directory(work / arm, create=True)
            common.private_directory(arm_work / "viewers", create=True)
            data = common.private_directory(arm_work / "data", create=True)
            settings = Settings(data_dir=data, tmux_executable=runtime["tmux_executable"])
            settings.save()
            native = NativeRuntime(settings, tmux_binary=runtime["tmux_executable"])
            native._initialize()
            run_id = "probe_" + uuid4().hex
            manifest = arm_work / "manifest.json"
            socket, session = str(short_tmp / (arm + "-outer.sock")), "timing-probe"
            state = {"scope": SCOPE, "run_id": args.run_id, "arm": arm, "status": "running",
                     "nonce": secrets.token_hex(32), "runtime": runtime, "gate_path": str(root / "gate.json"),
                     "controller_identity": supervision.identity(os.getpid()), "work_root": str(work),
                     "arm_work": str(arm_work), "tmp_root": str(short_tmp), "data_dir": str(data),
                     "source_root": str(args.source_root), "helper_sha256": common.sha(Path(__file__)),
                     "native_run_id": None, "expires_unix_time": global_expiry,
                     "socket": socket, "session": session}
            atomic(manifest, state)
            states.append((manifest, state))
            # Only the OUTER fixture is created before real WT admission. Its
            # bootstrap cannot touch the absent native run until native-created.
            config = arm_work / "outer.conf"
            config.write_text("set -g status off\nset -g default-terminal tmux-256color\nset -g mouse off\nset -g remain-on-exit on\nset -g exit-empty off\nset -s set-clipboard off\nset -g allow-passthrough off\n")
            def tmux(*values, check=True):
                return subprocess.run([runtime["tmux_executable"], "-S", socket, "-f", str(config), *values],
                                      capture_output=True, text=True, timeout=5, check=check)
            tmux("new-session", "-d", "-x", "120", "-y", "40", "-s", session, "--", sys.executable,
                 "-I", str(Path(__file__)), "--bridge", "--manifest", str(manifest))
            outer_server = supervision.identity(int(tmux("display-message", "-p", "#{pid}").stdout.strip()))
            require(outer_server and scope.owns(outer_server), "outer_tmux_not_owned")
            owned_handles.append((outer_server, os.pidfd_open(outer_server["pid"])))
            servers.append((tmux, outer_server))
            tmux("set-option", "-w", "-t", session, "window-size", "manual")
            bridge_identity = supervision.identity(int(tmux("display-message", "-p", "-t", session, "#{pane_pid}").stdout.strip()))
            require(bridge_identity and scope.owns(bridge_identity)
                    and bridge_identity["executable"] == runtime["python_executable"], "actual_bridge_child_not_owned")
            bridge_handle = (bridge_identity, os.pidfd_open(bridge_identity["pid"]))
            child_handles.append(bridge_handle)
            arm_child_handles = [bridge_handle]
            deadline = min(time.monotonic() + 40, workload_deadline - 10)
            report.update(phase="awaiting_windows_renderer", current_arm=arm,
                          phase_deadline_unix_time=time.time() + max(0, deadline - time.monotonic()))
            publish()
            supervision.atomic_json(root / "ready.json", {"run_id": args.run_id, "arm": arm,
                "status": "awaiting_windows_renderer", "manifest": str(manifest), "nonce": state["nonce"],
                "columns": 120, "rows": 40, "python_launcher": sys.executable,
                "controller": str(Path(__file__)), "expires_unix_time": state["expires_unix_time"],
                "phase_deadline_unix_time": report["phase_deadline_unix_time"], "native_spawned": False})
            while True:
                check()
                for registration in (arm_work / "viewers").glob("*.json"):
                    value = private_json(registration)
                    require(value["nonce"] == state["nonce"] and value["arm"] == arm, "viewer_registration_mismatch")
                    identity = value["identity"]
                    key = (identity["pid"], identity["birth"])
                    if key not in viewers:
                        viewers[key] = admit(identity)
                        registration.with_suffix(".admitted").touch(mode=0o600, exist_ok=False)
                        supervision.atomic_json(root / ("external-viewer-" + arm + ".json"),
                            {"run_id": args.run_id, "arm": arm, "nonce": state["nonce"],
                             "viewer_pid": identity["pid"], "viewer_birth": identity["birth"],
                             "status": "admitted_pending_actual_Windows_renderer_confirmation",
                             "actual_windows_terminal": False, "pidfd_admitted": True})
                confirmation = root / ("terminal-renderer-" + arm + ".json")
                if confirmation.exists():
                    value = supervision.read_json(confirmation)
                    require(value.get("actual_windows_terminal") is True and value.get("run_id") == args.run_id
                            and value.get("arm") == arm and value.get("nonce") == state["nonce"], "actual_Windows_renderer_proof_required")
                    clients = tmux("list-clients", "-F", "#{client_pid}\t#{client_tty}\t#{client_readonly}\t#{client_width}\t#{client_height}").stdout.splitlines()
                    require(len(clients) == 1, "exactly_one_renderer_client_required")
                    fields = clients[0].split("\t")
                    identity = supervision.identity(int(fields[0]))
                    require(len(fields) == 5 and fields[2:] == ["0", "120", "40"] and identity
                            and (identity["pid"], identity["birth"]) in viewers
                            and value.get("viewer_pid") == identity["pid"] and value.get("viewer_birth") == identity["birth"],
                            "actual_admitted_writable_renderer_mismatch")
                    break
                require(time.monotonic() < deadline, "actual_renderer_confirmation_timeout")
                time.sleep(.025)
            renderer_confirmed = time.monotonic()
            spawn_before = time.monotonic()
            # This is an explicit synthetic _spawn injection, without an auth
            # probe, integration installation, packet, model or coding client.
            with native._locked():
                row = native._spawn([], {"id": "terminal-probe", "root": str(arm_work)}, "synthetic-probe", arm,
                    {"command": [sys.executable, "-I", str(Path(__file__)), "--child", "--manifest", str(manifest)],
                     "cwd": str(arm_work), "env": dict(environment)}, 1, "synthetic-terminal-query", run_id=run_id)
            spawn_after = time.monotonic()
            child_identity = supervision.identity(row["pid"])
            require(child_identity and scope.owns(child_identity)
                    and child_identity["executable"] == runtime["python_executable"], "synthetic_child_not_owned")
            child_handle = (child_identity, os.pidfd_open(child_identity["pid"]))
            child_handles.append(child_handle)
            arm_child_handles.append(child_handle)
            inner_server = supervision.identity(int(native._tmux("display-message", "-p", "#{pid}").stdout.strip()))
            require(inner_server and scope.owns(inner_server), "inner_tmux_not_owned")
            owned_handles.append((inner_server, os.pidfd_open(inner_server["pid"])))
            servers.append((native._tmux, inner_server))
            # Never override the inner window sizing: production's unchanged
            # automatic/default policy must respond to the real _Channel client.
            tmux_metadata = {
                "inner_default_terminal": native._tmux("show-options", "-gv", "default-terminal").stdout.strip(),
                "outer_default_terminal": tmux("show-options", "-gv", "default-terminal").stdout.strip(),
                "inner_window_size": native._tmux("show-options", "-Awv", "-t", row["tmux_session"], "window-size").stdout.strip(),
                "launch_TERM": environment["TERM"], "inner_sizing_overridden": False, "outer_fixture_manual": True}
            for key in ("inner_default_terminal", "outer_default_terminal"):
                if tmux_metadata[key] not in {"tmux-256color", "xterm-256color", "screen-256color"}:
                    tmux_metadata[key] = "other"
            if tmux_metadata["inner_window_size"] not in {"latest", "largest", "smallest", "manual"}:
                tmux_metadata["inner_window_size"] = "other"
            state["native_run_id"] = run_id
            atomic(manifest, state)
            atomic(arm_work / "native-created.json", {"nonce": state["nonce"], "native_run_id": run_id})
            barrier_deadline = min(workload_deadline - 5, time.monotonic() + 10)
            while not ((arm_work / "child-ready.json").exists() and (arm_work / "subscribe-waiting.json").exists()):
                check()
                require(time.monotonic() < barrier_deadline, "common_native_subscribe_barrier_timeout")
                time.sleep(.01)
            require(private_json(arm_work / "child-ready.json")["nonce"] == state["nonce"]
                    and private_json(arm_work / "subscribe-waiting.json")["nonce"] == state["nonce"],
                    "common_barrier_nonce_mismatch")
            inner_client = None
            def observe_inner():
                before = time.monotonic()
                lines = native._tmux("list-clients", "-F", "#{client_pid}\t#{client_tty}\t#{client_readonly}").stdout.splitlines()
                after = time.monotonic()
                if not lines:
                    return None
                require(len(lines) == 1, "exactly_one_inner_channel_required")
                parts = lines[0].split("\t")
                require(len(parts) == 3 and parts[2] == "0", "inner_channel_must_be_writable")
                actual = supervision.identity(int(parts[0]))
                require(actual and scope.owns(actual) and actual["executable"] == runtime["tmux_executable"],
                        "inner_channel_identity_not_owned")
                retained = (actual, os.pidfd_open(actual["pid"]))
                require(supervision.same_process(actual) and scope.owns(actual), "inner_channel_identity_changed")
                child_handles.append(retained)
                arm_child_handles.append(retained)
                return {"pid": actual["pid"], "birth": actual["birth"], "tty": parts[1],
                        "sample_begin_monotonic": before, "sample_end_monotonic": after,
                        "timestamp_kind": "first_positive_client_observation_interval_not_exact_attach_syscall"}
            require(observe_inner() is None, "subscribe_barrier_already_has_inner_client")
            release_interval = None
            if arm == "attached":
                release_before = time.monotonic()
                atomic(arm_work / "subscribe-go.json", {"nonce": state["nonce"]})
                release_interval = [release_before, time.monotonic()]
                while inner_client is None:
                    require(time.monotonic() < barrier_deadline, "attached_inner_client_not_observed")
                    inner_client = observe_inner()
                    if inner_client is None:
                        time.sleep(.005)
            atomic(arm_work / "query-go.json", {"nonce": state["nonce"]})
            while not (arm_work / "query-started.json").exists():
                require(time.monotonic() < barrier_deadline, "query_start_not_observed")
                time.sleep(.005)
            started = private_json(arm_work / "query-started.json")["monotonic"]
            if arm == "delayed":
                while time.monotonic() < started + .500:
                    time.sleep(.002)
                release_before = time.monotonic()
                atomic(arm_work / "subscribe-go.json", {"nonce": state["nonce"]})
                release_interval = [release_before, time.monotonic()]
            resize_interval = None
            while not (arm_work / "child-result.json").exists():
                check()
                now = time.monotonic()
                require(now - started < 5, "synthetic_capture_timeout")
                if inner_client is None:
                    inner_client = observe_inner()
                if resize_interval is None and now >= started + 2:
                    before = time.monotonic()
                    tmux("resize-window", "-t", session, "-x", "120", "-y", "33")
                    resize_interval = [before, time.monotonic()]
                time.sleep(.01)
            result = private_json(arm_work / "child-result.json")
            require(result["status"] == "captured" and result["query_emissions"] == 1
                    and 3 <= result["elapsed_seconds"] <= 3.2, "bounded_query_capture_failed")
            stop = time.monotonic() + 5
            while not (arm_work / "bridge-result.json").exists():
                require(time.monotonic() < stop, "bridge_exit_not_observed")
                time.sleep(.025)
            result["bridge"] = private_json(arm_work / "bridge-result.json")
            require(result["bridge"]["exit_code"] == 0, "bridge_exit_failed")
            offset = lambda value: None if value is None else round((value - started) * 1000, 3)
            attach_interval = (None if inner_client is None else
                [offset(inner_client["sample_begin_monotonic"]), offset(inner_client["sample_end_monotonic"])])
            counts = result["bridge"]["counts"]
            ordering_valid = (inner_client is not None and
                (inner_client["sample_end_monotonic"] <= started if arm == "attached" else
                 (counts.get("subscribe_call_monotonic", 0) >= started + .500
                  and inner_client["sample_begin_monotonic"] >= started)))
            interpretable = ordering_valid and inner_client["sample_end_monotonic"] < started + 3
            result.update(actual_Windows_renderer_confirmed=True, actual_writable_client_count=1,
                          controlled_resize_count=int(resize_interval is not None), requested_viewport_sizes=[[120, 40], [120, 33]],
                          Windows_Terminal_client_size=[120, 40], no_keyboard_input_sent=True,
                          actual_child_resize_observed=(result["dimensions"][0]["size"] == [120, 40]
                              and result["dimensions"][-1]["size"] == [120, 33]),
                          input_framing_finding=(result["incomplete_tail_byte_count"] > 0
                              or result["printable_input_byte_count"] > 0))
            result.update(tmux_metadata=tmux_metadata, native_spawn_after_renderer_confirmed=(spawn_before >= renderer_confirmed),
                inner_client=inner_client, inner_client_first_observation_offset_interval_ms=attach_interval,
                comparison_ordering_valid=ordering_valid, comparison_interpretable=interpretable,
                timing={"renderer_confirmed_offset_ms": offset(renderer_confirmed),
                    "native_spawn_offset_interval_ms": [offset(spawn_before), offset(spawn_after)],
                    "subscribe_release_publication_offset_interval_ms": [offset(t) for t in release_interval],
                    "subscribe_release_lateness_interval_ms": (None if arm == "attached" else
                        [offset(t) - 500 for t in release_interval]),
                    "subscribe_call_offset_ms": offset(counts.get("subscribe_call_monotonic")),
                    "subscribe_return_offset_ms": offset(counts.get("subscribe_return_monotonic")),
                    "outer_resize_offset_interval_ms": (None if resize_interval is None else [offset(t) for t in resize_interval])},
                no_parser_correctness_or_application_fault_claim=True)
            for _, handle in arm_child_handles:
                require(bool(select.select([handle], [], [], 5)[0]), "synthetic_or_bridge_actual_exit_missing")
            result["synthetic_and_bridge_actual_exit_verified"] = True
            report["arms"][arm] = result
            publish()
            # Detach only the positively identified admitted client. Kill only owned servers.
            tmux("detach-client", "-t", fields[1])
            for command, identity in list(reversed(servers)):
                require(scope.owns(identity), "owned_tmux_identity_changed")
                command("kill-server")
                servers.remove((command, identity))
            for identity, handle in owned_handles:
                require(bool(select.select([handle], [], [], 5)[0]), "owned_tmux_actual_exit_missing")
            for handle in viewers.values():
                require(bool(select.select([handle], [], [], 5)[0]), "renderer_actual_exit_missing")
            state["status"] = "closed"
            atomic(manifest, state)
        report["workload_criteria_passed"] = True
    except Exception as exc:
        report["errors"].append(str(exc) if isinstance(exc, (ValueError, common.ValidationError)) else type(exc).__name__)
        # Fail closed BEFORE the observed cleanup interval: neither a late
        # Windows waiter nor an unadmitted viewer may join a stale ready arm.
        report.update(status="failed", phase="cleanup_after_failure")
        for manifest, state in states:
            state["status"] = "closed"
            try:
                atomic(manifest, state)
            except OSError:
                report["errors"].append("private_manifest_close_failed")
        publish()
    finally:
        try:
            for command, identity in reversed(servers):
                require(scope.owns(identity), "cleanup_tmux_identity_changed")
                command("kill-server", check=False)
            for _, handle in owned_handles:
                require(bool(select.select([handle], [], [], 5)[0]), "owned_tmux_actual_exit_missing")
            for _, handle in child_handles:
                require(bool(select.select([handle], [], [], 5)[0]), "synthetic_or_bridge_actual_exit_missing")
            for handle in viewers.values():
                require(bool(select.select([handle], [], [], 5)[0]), "renderer_actual_exit_missing")
            report["external_viewers_actual_exit_verified"] = True
            report["owned_servers_actual_exit_verified"] = True
            report["cleanup_grace_seconds"] = common.quiet_scope(scope, supervision, parent)
            report["cleanup_complete"] = True
            check()
            require(guard.source_manifest(args.source_root) == source_hashes, "application_source_changed")
        except Exception as exc:
            report["errors"].append(str(exc) if isinstance(exc, (ValueError, common.ValidationError)) else type(exc).__name__)
        for manifest, state in states:
            state["status"] = "closed"
            atomic(manifest, state)
        for _, handle in owned_handles:
            os.close(handle)
        for _, handle in child_handles:
            os.close(handle)
        for handle in viewers.values():
            os.close(handle)
        os.environ.clear()
        os.environ.update(old_env)
        tempfile.tempdir = old_tempdir
        os.umask(old_umask)
        report["status"] = ("terminal_timing_probe_completed_pending_external_watch"
                            if report.get("workload_criteria_passed") and report["cleanup_complete"]
                            and not report["errors"] else "failed")
        publish()
    return 0 if report["status"] == "terminal_timing_probe_completed_pending_external_watch" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--attach", action="store_true")
    parser.add_argument("--bridge", action="store_true")
    parser.add_argument("--child", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--run-id")
    for name in ("artifact-root", "source-root", "private-root"):
        parser.add_argument("--" + name, type=Path)
    parser.add_argument("--duration", type=int, default=120)
    args = parser.parse_args()
    require(sum((args.execute, args.attach, args.bridge, args.child)) <= 1, "one_explicit_probe_mode_required")
    if args.attach or args.bridge or args.child:
        require(args.manifest is not None, "explicit_private_manifest_required")
        if args.attach:
            return attach(args.manifest)
        if args.child:
            return child(args.manifest)
        return asyncio.run(bridge_async(args.manifest))
    if args.execute:
        return main_controller(args)
    print(json.dumps({"status": "not_run", "model_requests": 0, "account_requests": 0,
                      "arms": ["attached", "delayed"], "capture_seconds_each": 3,
                      "actual_Windows_Terminal_required": True, "eight_hour_started": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
