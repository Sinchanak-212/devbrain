"""Windows stdlib AST-only review; never imports/executes a probe module body."""
import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

root = Path(__file__).parent
source = root / "terminal-input-timing-probe-v2-20261109.py"
expected = "8ddea268fa6da47fadb0fb7607b3ebe260777a3bae69817093320acda325c3d8"
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected
tree = ast.parse(source.read_text())
baseline = ast.parse((root / "terminal-input-probe-20261109.py").read_text())
checks = []

def check(name, value):
    assert value, name
    checks.append({"name": name, "passed": True})

def top(name, nodes=tree.body):
    return next(node for node in nodes if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name == name)

for name in ("load", "require", "atomic", "private_json", "dimensions", "ControlClassifier", "verified_state", "attach"):
    check("unchanged_ownership_or_framing_primitive_" + name,
          ast.dump(top(name), include_attributes=False) == ast.dump(top(name, baseline.body), include_attributes=False))

# Compile only the bounded pure classifier class, not a probe function/module body.
def require(value, reason):
    if not value:
        raise ValueError(reason)

environment = {"require": require, "re": re}
exec(compile(ast.Module(body=[top("ControlClassifier")], type_ignores=[]), str(source), "exec"), environment)
classifier = environment["ControlClassifier"]()
classifier.feed(b"\x1b[?1;2c", .01)
snapshot = deepcopy(classifier.summary())
classifier.feed(b"\x1b[1;1R", .02)
check("snapshot_is_not_mutated_by_later_control_reply", snapshot["control_classes"] == {"CSI_PRIMARY_DA": 1})
check("snapshot_events_are_copied", len(snapshot["control_events"]) == 1 and len(classifier.summary()["control_events"]) == 2)

bridge = top("bridge_async") if False else next(n for n in tree.body if isinstance(n, ast.AsyncFunctionDef) and n.name == "bridge_async")
channel_dict = next(n for n in ast.walk(bridge) if isinstance(n, ast.Dict)
                    and any(isinstance(k, ast.Constant) and k.value == "actual_NativeRuntime_Channel" for k in n.keys))
channel_expr = next(v for k, v in zip(channel_dict.keys, channel_dict.values)
                    if isinstance(k, ast.Constant) and k.value == "actual_NativeRuntime_Channel")
channel_code = compile(ast.Expression(channel_expr), str(source), "eval")
for name, counts, wanted in (
    ("no_attempt_is_not_actual_Channel", {"inner_channel_creations": 0}, False),
    ("failed_subscribe_is_not_actual_Channel", {"inner_channel_creations": 0, "inner_subscribe_attempts": 1}, False),
    ("successful_subscribe_is_actual_Channel", {"inner_channel_creations": 1, "subscribe_return_monotonic": 100.6}, True),
):
    check(name, eval(channel_code, {}, {"counts": counts}) is wanted)

main = top("main_controller")
ordering = next(n.value for n in ast.walk(main) if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == "ordering_valid" for t in n.targets))
ordering_code = compile(ast.Expression(ordering), str(source), "eval")
def ordered(arm, begin, end, call):
    client = None if begin is None else {"sample_begin_monotonic": begin, "sample_end_monotonic": end}
    return eval(ordering_code, {}, {"arm": arm, "started": 100.0, "inner_client": client,
                                   "counts": {"subscribe_call_monotonic": call}})
check("attached_before_query_is_ordered", ordered("attached", 99.0, 99.1, 99.0) is True)
check("attached_after_query_is_not_ordered", ordered("attached", 100.1, 100.2, 99.0) is False)
check("delayed_release_and_client_after_query_is_ordered", ordered("delayed", 100.6, 100.7, 100.5) is True)
check("delayed_prequery_client_is_not_ordered", ordered("delayed", 99.9, 100.1, 100.5) is False)
check("delayed_early_subscribe_is_not_ordered", ordered("delayed", 100.6, 100.7, 100.4) is False)
check("absent_inner_client_is_not_ordered", ordered("delayed", None, None, 100.5) is False)
interpretable = next(n.value for n in ast.walk(main) if isinstance(n, ast.Assign)
                    and any(isinstance(t, ast.Name) and t.id == "interpretable" for t in n.targets))
interpretable_code = compile(ast.Expression(interpretable), str(source), "eval")
check("late_inner_client_is_uninterpretable_data", eval(interpretable_code, {},
      {"ordering_valid": True, "inner_client": {"sample_end_monotonic": 103.1}, "started": 100.0}) is False)
check("absent_client_short_circuits_without_fabricated_identity", eval(interpretable_code, {},
      {"ordering_valid": False, "inner_client": None, "started": 100.0}) is False)
native_calls = [n for n in ast.walk(main) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
                and isinstance(n.func.value, ast.Name) and n.func.value.id == "native" and n.func.attr == "_tmux"]
check("no_inner_manual_resize_or_size_override", not any(
    n.args and isinstance(n.args[0], ast.Constant) and n.args[0].value in {"set-option", "resize-window"}
    for n in native_calls))
check("effective_inherited_inner_size_is_queried", any(
    any(isinstance(a, ast.Constant) and a.value == "-Awv" for a in n.args) for n in native_calls))
check("fixed_five_query_burst_unchanged", next(n.value.value for n in tree.body if isinstance(n, ast.Assign)
    and any(isinstance(t, ast.Name) and t.id == "QUERY" for t in n.targets)) ==
    next(n.value.value for n in baseline.body if isinstance(n, ast.Assign)
    and any(isinstance(t, ast.Name) and t.id == "QUERY" for t in n.targets)))

output = root / "terminal-input-timing-v2-final-independent-static-peer-20261109.json"
assert not output.exists()
record = {"schema_version": 1, "scope": "windows_stdlib_AST_only_terminal_timing_controller_peer",
          "status": "static_review_passed_not_runtime_qualification", "source": str(source), "source_sha256": expected,
          "checks": checks, "check_count": len(checks), "probe_module_body_executed": False,
          "child_bridge_controller_functions_executed": False, "Linux_started": False, "models_or_auth_requested": False,
          "App_files_changed": False, "eight_hour_started": False,
          "manual_review": ["Actual WT outer is independently bound and verified before synthetic native _spawn",
              "Bootstrap waits native-created before loading App runtime; shared subscribe-waiting barrier normalizes both arms",
              "Attached inner PID/birth/scope/pidfd is observed before query-go; delayed subscribe released at query+500ms",
              "Release and first-positive-attachment are observation intervals; actual jitter and invalid ordering stay data",
              "Late/absent channel never claims actual _Channel or application fault",
              "Original known scope/parent/native runtime checks, owned pidfds and quiet30 cleanup retained",
              "Canonical38 and App are not edited; actual execution still needs root reviewed staged-context GO"]}
output.write_text(json.dumps(record, indent=2), encoding="utf-8")
print(json.dumps({"path": str(output), "sha256": hashlib.sha256(output.read_bytes()).hexdigest(), "checks": len(checks)}))
